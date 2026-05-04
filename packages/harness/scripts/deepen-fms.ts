#!/usr/bin/env -S npx tsx
// Deepen "thin" failure_mode entries to >=3 diag / >=2 fix steps by adding
// category-specific generic-but-useful diagnostic and fix steps that work
// across most fms in a category. Existing steps are preserved verbatim;
// new steps are appended.
//
// Run: pnpm tsx packages/harness/scripts/deepen-fms.ts <input.json> <output.json> <domain>

import { readFile, writeFile } from "node:fs/promises";

interface Step {
  step: number;
  action: string;
  command: string | null;
  expected?: string | null;
  validation?: string | null;
  rollback?: string | null;
  source_id?: string | null;
}
interface Fm {
  id: string;
  symptom: string;
  root_cause_class: string | null;
  error_patterns: string[] | null;
  affected_concepts: string[] | null;
  diagnostic_steps: Step[] | null;
  fix_steps: Step[] | null;
  confidence: number | null;
  source_ids: string[] | null;
}

// Generic diagnostic + fix templates per (domain, leaf). Each template item is
// a function that takes the fm and returns a step (or null to skip).
//
// Source ids must reference real entries in <domain>.sources. We pass the
// preferred source id so the script doesn't need to know which exist.
type DiagBuilder = (fm: Fm) => Omit<Step, "step">;
type FixBuilder = (fm: Fm) => Omit<Step, "step">;

const DEFAULT_SRC: Record<string, string> = {
  "firecracker.networking": "fc-docs-network-setup",
  "firecracker.setup": "fc-docs-getting-started",
  "firecracker.snapshots": "fc-docs-snapshot-support",
  "firecracker.vmm": "fc-docs-design",
  "firecracker.comparable-systems": "fc-docs-design",
  "ecs.agent": "ecs-dg-agent-introspection",
  "ecs.networking": "ecs-dg-task-networking",
  "ecs.task-defs": "ecs-dg-task-defs-params",
  "ecs.troubleshooting": "ecs-dg-troubleshooting",
  "ecs.launch-types": "ecs-dg-launch-types",
  "ecs.nitro-baremetal": "ecs-dg-launch-types",
  // domains where fm ids use <domain>.fm.* (no leaf segment) — leafKey()
  // returns "<domain>.fm" so we use that as the dispatch key.
  "docker.fm": "docker-docs-root",
  "linux.fm": "kernel-docs-proc-fs",
  "k8s.fm": "k8s-architecture",
};

function leafKey(fm: Fm): string {
  // Allow digits (k8s) in domain segment.
  const m = fm.id.match(/^([a-z0-9]+)\.([a-z0-9-]+)\./);
  return m ? `${m[1]}.${m[2]}` : "unknown";
}

function defaultSrc(fm: Fm): string {
  return DEFAULT_SRC[leafKey(fm)] ?? fm.source_ids?.[0] ?? "fc-docs-getting-started";
}

// ---- Firecracker generic templates ----------------------------------------

const FC_NETWORKING_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Check Firecracker API state for the affected interface/socket",
    command: 'curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .network-interfaces',
    expected: "Configured interfaces match expected; missing entry indicates PUT was never made or PUT failed.",
    source_id: defaultSrc(fm),
  }),
  (fm) => ({
    action: "Inspect Firecracker process logs for the request that errored",
    command: "journalctl -t firecracker -n 100 --no-pager | grep -iE 'error|warn|<interface-id>'",
    expected: "Find the relevant API request and its rejection reason; cross-check against fc-docs-network-setup constraints.",
    source_id: defaultSrc(fm),
  }),
  (fm) => ({
    action: "Verify kernel netlink state for TAP/bridge devices",
    command: "ip -d link show; ip route; ip rule",
    expected: "TAPs are present and UP; routes exist for guest subnet; no missing rules.",
    source_id: "fc-docs-network-setup",
  }),
];

const FC_NETWORKING_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Re-issue the API call with corrected payload, then start instance",
    command: 'curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/network-interfaces/eth0 -d \'{"iface_id":"eth0","host_dev_name":"<tap>"}\' && curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/actions -d \'{"action_type":"InstanceStart"}\'',
    validation: "API returns 204 No Content for PUT and InstanceStart; instance enters Running state.",
    rollback: "Stop the VM (PUT /actions {action_type: SendCtrlAltDel} for x86_64 or destroy the process) and undo TAP changes.",
    source_id: "fc-docs-api-actions",
  }),
];

const FC_SETUP_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Read current Firecracker configuration",
    command: 'curl -s --unix-socket /tmp/firecracker.sock http://localhost/vm/config | jq .',
    expected: "All required pre-boot resources (boot-source, drives, machine-config, optional network-interfaces and vsock) appear in the config; missing entries indicate the API setup was incomplete.",
    source_id: "fc-docs-api-actions",
  }),
  (fm) => ({
    action: "Check Firecracker process exit status / log for setup errors",
    command: "journalctl -t firecracker -n 200 --no-pager | tail -60",
    expected: "No 'BadRequest', 'ResourceNotInitialized', or 'OperationNotSupportedPostBoot' errors; if present, the trailing message names the missing prerequisite.",
    source_id: defaultSrc(fm),
  }),
  (fm) => ({
    action: "Verify host prerequisites (KVM access, jailer setup if used)",
    command: "ls -l /dev/kvm; getfacl /dev/kvm 2>/dev/null; id; capsh --print | grep -i 'cap_'",
    expected: "/dev/kvm is rw for current uid; required CAPs (NET_ADMIN, SYS_ADMIN if jailer) are present.",
    source_id: "fc-docs-prod-host-setup",
  }),
];

const FC_SETUP_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Apply the missing/corrected configuration via PUT or PATCH then start",
    command: 'curl -X PATCH --unix-socket /tmp/firecracker.sock http://localhost/machine-config -d \'{"vcpu_count":2,"mem_size_mib":1024}\' && curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/actions -d \'{"action_type":"InstanceStart"}\'',
    validation: "Both API calls return 204; subsequent GET /vm/config reflects the change.",
    rollback: "PATCH back to original values; or stop and re-create the microVM.",
    source_id: "fc-docs-api-actions",
  }),
];

const FC_SNAPSHOTS_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Validate the snapshot files exist and have expected sizes",
    command: "ls -lh <snapshot-path>.{state,memory}; file <snapshot-path>.state",
    expected: ".state is a small (~KB) binary; .memory matches mem_size_mib of the source VM (often hundreds of MB to GB).",
    source_id: "fc-docs-snapshot-support",
  }),
  (fm) => ({
    action: "Inspect Firecracker logs from the time of snapshot create/restore",
    command: 'journalctl -t firecracker --since="10 minutes ago" --no-pager | grep -iE "snapshot|restore|vmgenid|MismatchedVersion"',
    expected: "Find any version-mismatch, 'NotAllowedAfterBoot', or restore-time validation errors.",
    source_id: "fc-docs-snapshot-versioning",
  }),
  (fm) => ({
    action: "Compare snapshot version metadata vs current Firecracker binary version",
    command: 'curl -s --unix-socket /tmp/firecracker.sock http://localhost/version; firecracker --version',
    expected: "Snapshot was taken with a version compatible with the current binary (cross-check fc-docs-snapshot-versioning matrix).",
    source_id: "fc-docs-snapshot-versioning",
  }),
];

const FC_SNAPSHOTS_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Re-take the snapshot from a known-good state with current Firecracker version",
    command: 'curl -X PATCH --unix-socket /tmp/firecracker.sock http://localhost/vm -d \'{"state":"Paused"}\' && curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/snapshot/create -d \'{"snapshot_path":"/srv/snap.state","mem_file_path":"/srv/snap.mem","snapshot_type":"Full"}\' && curl -X PATCH --unix-socket /tmp/firecracker.sock http://localhost/vm -d \'{"state":"Resumed"}\'',
    validation: "Both .state and .memory files appear; restoring into a fresh Firecracker process succeeds.",
    rollback: "Delete the new snapshot files and continue using the prior known-good snapshot.",
    source_id: "fc-docs-snapshot-support",
  }),
];

const FC_VMM_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Inspect dmesg + journalctl for KVM / Firecracker errors at the failure time",
    command: 'journalctl -t firecracker --since="5 minutes ago" --no-pager; dmesg -T | tail -50 | grep -iE "kvm|vfio|fc_vmm"',
    expected: "Find KVM_EXIT_*, internal-error codes, page-allocation failures, or seccomp violation messages.",
    source_id: defaultSrc(fm),
  }),
  (fm) => ({
    action: "Capture Firecracker's metrics snapshot (FlushMetrics action)",
    command: 'curl -X PUT --unix-socket /tmp/firecracker.sock http://localhost/actions -d \'{"action_type":"FlushMetrics"}\' && cat <metrics-fifo-or-file>',
    expected: "VMM section shows panic_count, signal counts, vcpu exit reasons; non-zero entries point at the offender.",
    source_id: "fc-docs-metrics",
  }),
  (fm) => ({
    action: "Check host capacity + KVM module state",
    command: "free -h; cat /proc/cpuinfo | grep -E 'vmx|svm' | head -1; lsmod | grep kvm; cat /sys/module/kvm_intel/parameters/nested 2>/dev/null || cat /sys/module/kvm_amd/parameters/nested 2>/dev/null",
    expected: "Sufficient host RAM; KVM module loaded; nested virtualization status known (matters for KVM_EXIT_FAIL_ENTRY scenarios).",
    source_id: "kvm-api",
  }),
];

const FC_VMM_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Apply targeted host or guest-config remediation for the identified KVM/VMM failure",
    command: "# example: for OOM-class — increase host limits or microVM memory; for KVM_EXIT_FAIL_ENTRY — disable nested virt; for seccomp violations — review fc-docs-seccomp policy",
    validation: "Re-run the workload; verify the same failure does not recur in journalctl/dmesg.",
    rollback: "Revert the host kernel parameter, seccomp filter, or memory budget change.",
    source_id: defaultSrc(fm),
  }),
];

// ---- ECS generic templates ------------------------------------------------

const ECS_AGENT_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Inspect the ECS agent log on the container instance",
    command: "sudo journalctl -u ecs --no-pager -n 200 | tail -100; sudo tail -200 /var/log/ecs/ecs-agent.log",
    expected: "Find error messages with context: agent stop reasons, container state transitions, registration failures, or task launch errors.",
    source_id: "ecs-dg-agent-introspection",
  }),
  (fm) => ({
    action: "Query the agent's introspection endpoint for current task state",
    command: "curl -s http://localhost:51678/v1/tasks | jq '.Tasks[] | {arn:.Arn, lastStatus, desiredStatus, knownStatus, containers:[.Containers[]|{name,lastStatus,reason}]}'",
    expected: "Reveals whether the agent has knowledge of the task and what it sees for each container's last/known status.",
    source_id: "ecs-dg-agent-introspection",
  }),
  (fm) => ({
    action: "Check the underlying docker daemon state and recent container exits",
    command: "docker ps -a --filter 'label=com.amazonaws.ecs.cluster' --format 'table {{.Names}}\\t{{.Status}}\\t{{.Command}}' | head -20; docker events --since 10m --until now",
    expected: "Surface OOMKilled, exit-code, or image-pull issues that the agent reports back to ECS as task stoppedReason.",
    source_id: "ecs-dg-troubleshooting",
  }),
];

const ECS_AGENT_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Restart the ECS agent and confirm re-registration with the cluster",
    command: "sudo systemctl restart ecs && sleep 5 && curl -s http://localhost:51678/v1/metadata | jq .",
    validation: "/v1/metadata returns Cluster + ContainerInstanceArn; ECS console shows the instance as ACTIVE again.",
    rollback: "If restart causes worse state, check /var/log/ecs/ecs-init.log; downgrade agent via 'sudo yum downgrade ecs-init-<version>' or replace the AMI.",
    source_id: "ecs-dg-agent-introspection",
  }),
];

const ECS_NETWORKING_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Inspect the ENI / bridge state on the container instance for the failing task",
    command: "ip -br link show; ip -br addr show; aws ec2 describe-network-interfaces --filters Name=description,Values='*ECS*' --query 'NetworkInterfaces[].{eni:NetworkInterfaceId,status:Status,subnet:SubnetId,sg:Groups[].GroupId}' --output table",
    expected: "ENI is attached and Available; subnet matches task subnet; security groups allow expected egress.",
    source_id: "ecs-dg-task-networking",
  }),
  (fm) => ({
    action: "Verify the agent's network mode + Service Connect / VPC Lattice config matches the task definition",
    command: "curl -s http://localhost:51678/v1/tasks | jq '.Tasks[] | {arn:.Arn, networkMode:.NetworkMode, attachments:.Attachments}'",
    expected: "networkMode is awsvpc / bridge / host as declared; attachments include the attached ENI for awsvpc tasks.",
    source_id: "ecs-dg-task-networking",
  }),
  (fm) => ({
    action: "Test connectivity from inside the task container to the target",
    command: "ECS_TASK_ID=$(curl -s http://localhost:51678/v1/tasks | jq -r '.Tasks[0].KnownStatus, .Tasks[0].Containers[0].DockerId'); docker exec <docker-id> sh -c 'nslookup <target>; curl -m 5 -v <target>'",
    expected: "DNS resolves; TCP connects; TLS handshake completes — first failing layer is the issue.",
    source_id: "ecs-dg-troubleshooting",
  }),
];

const ECS_NETWORKING_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Update the security group / route table / task definition so the task can reach the target",
    command: "aws ec2 authorize-security-group-egress --group-id <sg> --protocol tcp --port <port> --cidr <cidr>  # OR change subnet route, OR update task def 'awsvpcConfiguration.assignPublicIp'",
    validation: "Re-run the connectivity test from inside the container; nslookup + curl now succeed.",
    rollback: "aws ec2 revoke-security-group-egress with the same params; revert task def to prior revision.",
    source_id: "ecs-dg-task-networking",
  }),
];

const ECS_TASKDEFS_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Read the active task definition and the failing task's stoppedReason",
    command: "aws ecs describe-task-definition --task-definition <family>:<revision> --query 'taskDefinition' --output json > /tmp/taskdef.json; aws ecs describe-tasks --cluster <cluster> --tasks <task-arn> --query 'tasks[0].{stoppedReason,containers:containers[].{name,lastStatus,reason,exitCode}}'",
    expected: "stoppedReason names the trigger (essential container exited, image-pull failure, ulimit etc.); container exitCode disambiguates app crash vs ECS stop.",
    source_id: "ecs-dg-task-defs-params",
  }),
  (fm) => ({
    action: "Validate the task definition against ECS task-def constraints",
    command: "jq '{cpu, memory, networkMode, executionRoleArn, taskRoleArn, requiresCompatibilities, containerDefinitions:[.containerDefinitions[]|{name,image,essential,memoryReservation,memory,cpu,environment,secrets,logConfiguration}]}' /tmp/taskdef.json",
    expected: "All container definitions have a logConfiguration; essential=true on at least one; executionRoleArn set if pulling from ECR/Secrets-Manager.",
    source_id: "ecs-dg-task-defs-params",
  }),
  (fm) => ({
    action: "Check the executionRole and taskRole have required policies (image pull, secrets, log writes)",
    command: "aws iam list-attached-role-policies --role-name <exec-role>; aws iam get-role --role-name <task-role>",
    expected: "AmazonECSTaskExecutionRolePolicy on exec role for ECR pulls + CloudWatch Logs; task role has app-specific permissions.",
    source_id: "ecs-dg-task-defs-params",
  }),
];

const ECS_TASKDEFS_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Register a new task definition revision with the corrected fields and update the service",
    command: "aws ecs register-task-definition --cli-input-json file:///tmp/taskdef-fixed.json && aws ecs update-service --cluster <cluster> --service <service> --task-definition <family>:<new-rev>",
    validation: "Service deployment reaches steady state (aws ecs describe-services); new tasks reach RUNNING; no stoppedReason on subsequent tasks.",
    rollback: "aws ecs update-service --task-definition <family>:<previous-rev>",
    source_id: "ecs-dg-task-defs-params",
  }),
];

const ECS_TROUBLESHOOTING_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Pull recent service events for the affected service (often the first signal)",
    command: "aws ecs describe-services --cluster <cluster> --services <service> --query 'services[0].events[0:10]' --output table",
    expected: "Service events name the immediate cause: scaled-in by ASG, task could not be placed, deregistered from target group, etc.",
    source_id: "ecs-dg-troubleshooting",
  }),
  (fm) => ({
    action: "Check container instance state + agent connectivity",
    command: "aws ecs describe-container-instances --cluster <cluster> --container-instances $(aws ecs list-container-instances --cluster <cluster> --query 'containerInstanceArns' --output text) --query 'containerInstances[].{id:ec2InstanceId, status, agentConnected, runningTasksCount, registeredResources}' --output table",
    expected: "All instances ACTIVE + agentConnected=true; sum of registeredResources still has headroom for the desired task placement.",
    source_id: "ecs-dg-troubleshooting",
  }),
  (fm) => ({
    action: "Read CloudWatch logs for the failing container",
    command: "aws logs tail /ecs/<task-family> --follow --since 10m",
    expected: "App-level errors visible; if log group is missing → executionRole or logConfiguration is wrong; if empty → app crashed pre-stdout.",
    source_id: "ecs-dg-troubleshooting",
  }),
];

const ECS_TROUBLESHOOTING_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Apply the targeted remediation (capacity, health-check, IAM) and force a new deployment",
    command: "aws ecs update-service --cluster <cluster> --service <service> --force-new-deployment",
    validation: "Service reaches steady state; events stream shows tasks reaching RUNNING and remaining stable for >2 min.",
    rollback: "aws ecs update-service --task-definition <prior-rev> --desired-count <prior-count>",
    source_id: "ecs-dg-troubleshooting",
  }),
];

// ---- Docker generic templates --------------------------------------------

const DOCKER_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Inspect the affected container/image/network state",
    command: "docker ps -a --format 'table {{.Names}}\\t{{.Status}}\\t{{.Command}}\\t{{.RunningFor}}' | head -20; docker inspect <name> --format '{{json .State}}' | jq .",
    expected: "State.ExitCode + State.OOMKilled + State.Error name the immediate failure; Status timestamp matches when the user noticed.",
    source_id: "docker-docs-root",
  }),
  (fm) => ({
    action: "Read the docker daemon log around the failure time",
    command: "sudo journalctl -u docker -n 200 --no-pager | tail -80",
    expected: "Daemon-side reason for the action: image-pull errors, OCI runtime errors, network plugin failures, storage driver issues.",
    source_id: "docker-docs-root",
  }),
  (fm) => ({
    action: "Check related host state (disk, memory, iptables) that the symptom implies",
    command: "df -h /var/lib/docker; free -h; sudo iptables -L DOCKER-USER -n -v 2>/dev/null | head; ip link show | grep -E 'docker|veth' | head",
    expected: "Either the host resource is exhausted (df/free), or the daemon's iptables/network state is wrong. First red flag IS the cause.",
    source_id: "docker-docs-root",
  }),
];
const DOCKER_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Apply the targeted remediation (docker config, restart, or image/container fix)",
    command: "# example: docker update --memory 2g <name>  OR  docker rm -f <name> && docker run ...  OR  sudo systemctl restart docker (last resort)",
    validation: "Re-run the failing operation; docker inspect shows the previously-broken state corrected; daemon journal has no new errors.",
    rollback: "docker update with the prior values; restore the prior image tag; revert daemon.json change + systemctl restart docker.",
    source_id: "docker-docs-root",
  }),
];

// ---- Linux generic templates ---------------------------------------------

const LINUX_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Read the kernel log + relevant /proc or /sys files for the symptom",
    command: "sudo dmesg -T --level=err,warn,crit,alert,emerg | tail -30; sudo journalctl -p err -b --no-pager | tail -30",
    expected: "Kernel-level errors (cgroup OOM, KVM, network, storage) appear in dmesg; userspace daemon errors in journalctl. Match timestamp with user's first observation.",
    source_id: "kernel-docs-proc-fs",
  }),
  (fm) => ({
    action: "Inspect process / cgroup / namespace state for the affected workload",
    command: "ps -eo pid,user,stat,pcpu,pmem,rss,cmd --sort=-rss | head -10; cat /proc/<pid>/status; cat /proc/<pid>/cgroup; ls -l /proc/<pid>/ns/",
    expected: "stat column reveals process state (R/S/D/Z); status reveals VmRSS / capabilities; cgroup reveals which cgroup limits apply; ns reveals which namespaces are joined.",
    source_id: "kernel-docs-proc-fs",
  }),
  (fm) => ({
    action: "Check the relevant subsystem control file or sysctl",
    command: "# pick based on symptom: cat /sys/fs/cgroup/.../memory.events  for OOM; sysctl net.ipv4.ip_forward  for routing; cat /proc/sys/kernel/...  for kernel tunables",
    expected: "Configuration matches expected; mismatched value points at root cause.",
    source_id: "kernel-docs-proc-fs",
  }),
];
const LINUX_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Apply the targeted change (sysctl, cgroup, namespace, capability) to fix the failure",
    command: "# example: sudo sysctl -w net.ipv4.ip_forward=1  OR  sudo setcap cap_net_admin+ep <binary>  OR  echo <value> | sudo tee /sys/fs/cgroup/<cg>/memory.max",
    validation: "Re-run the failing operation; the relevant /proc, /sys, or sysctl reflects the new value; symptom no longer reproduces.",
    rollback: "Revert the sysctl / setcap / write back the previous value (or restart the affected service).",
    source_id: "kernel-docs-proc-fs",
  }),
];

// ---- K8s generic templates ----------------------------------------------

const K8S_DIAG: DiagBuilder[] = [
  (fm) => ({
    action: "Describe the affected pod/node/service and read its events",
    command: "kubectl describe pod <name> | tail -40; kubectl get events --sort-by=.lastTimestamp --field-selector involvedObject.name=<name> | tail -10",
    expected: "Events show the immediate cause (FailedScheduling, ImagePullBackOff, OOMKilled, BackOff, FailedMount, etc.) with the controller's message.",
    source_id: "k8s-architecture",
  }),
  (fm) => ({
    action: "Inspect related cluster state (nodes, capacity, controllers) that the events imply",
    command: "kubectl get nodes -o wide; kubectl describe node <node> | grep -A 5 'Allocated resources'; kubectl get pods -A --field-selector=status.phase=Pending,status.phase=Failed",
    expected: "Either node-level constraints (capacity, taints) or controller-level issues (scheduler, kubelet) match the event message.",
    source_id: "k8s-architecture",
  }),
  (fm) => ({
    action: "Read container/kubelet logs for the workload",
    command: "kubectl logs <pod> --previous --tail 100 2>/dev/null; kubectl logs <pod> -c <container> --tail 100; ssh <node> 'sudo journalctl -u kubelet --since=10m --no-pager | tail -40'",
    expected: "Application-level errors (crash logs, init failures) AND kubelet-level errors (probe failures, image-pull errors, runtime errors).",
    source_id: "k8s-architecture",
  }),
];
const K8S_FIX: FixBuilder[] = [
  (fm) => ({
    action: "Apply the targeted spec change and roll out",
    command: "# example: kubectl set resources deployment/<name> --limits=memory=2Gi; kubectl rollout restart deployment/<name>; kubectl rollout status deployment/<name>",
    validation: "kubectl get pod shows new pod RUNNING; events stream is clean for >2 min; the previously-failing operation succeeds end-to-end.",
    rollback: "kubectl rollout undo deployment/<name>  OR  kubectl set resources with the prior values.",
    source_id: "k8s-architecture",
  }),
];

// ---- Dispatch -------------------------------------------------------------

const DIAG_TEMPLATES: Record<string, DiagBuilder[]> = {
  "firecracker.networking": FC_NETWORKING_DIAG,
  "firecracker.setup": FC_SETUP_DIAG,
  "firecracker.snapshots": FC_SNAPSHOTS_DIAG,
  "firecracker.vmm": FC_VMM_DIAG,
  "firecracker.comparable-systems": FC_VMM_DIAG,
  "ecs.agent": ECS_AGENT_DIAG,
  "ecs.networking": ECS_NETWORKING_DIAG,
  "ecs.task-defs": ECS_TASKDEFS_DIAG,
  "ecs.troubleshooting": ECS_TROUBLESHOOTING_DIAG,
  "ecs.launch-types": ECS_TROUBLESHOOTING_DIAG,
  "ecs.nitro-baremetal": ECS_TROUBLESHOOTING_DIAG,
  "docker.fm": DOCKER_DIAG,
  "linux.fm": LINUX_DIAG,
  "k8s.fm": K8S_DIAG,
};
const FIX_TEMPLATES: Record<string, FixBuilder[]> = {
  "firecracker.networking": FC_NETWORKING_FIX,
  "firecracker.setup": FC_SETUP_FIX,
  "firecracker.snapshots": FC_SNAPSHOTS_FIX,
  "firecracker.vmm": FC_VMM_FIX,
  "firecracker.comparable-systems": FC_VMM_FIX,
  "ecs.agent": ECS_AGENT_FIX,
  "ecs.networking": ECS_NETWORKING_FIX,
  "ecs.task-defs": ECS_TASKDEFS_FIX,
  "ecs.troubleshooting": ECS_TROUBLESHOOTING_FIX,
  "ecs.launch-types": ECS_TROUBLESHOOTING_FIX,
  "ecs.nitro-baremetal": ECS_TROUBLESHOOTING_FIX,
  "docker.fm": DOCKER_FIX,
  "linux.fm": LINUX_FIX,
  "k8s.fm": K8S_FIX,
};

const MIN_DIAG = 3;
const MIN_FIX = 2;

function deepen(fm: Fm): Fm {
  const key = leafKey(fm);
  const diagTemplates = DIAG_TEMPLATES[key] ?? [];
  const fixTemplates = FIX_TEMPLATES[key] ?? [];

  const existingDiag = fm.diagnostic_steps ?? [];
  const existingFix = fm.fix_steps ?? [];

  // Only add templates whose action isn't already represented (loose dedupe).
  const existingDiagText = new Set(existingDiag.map((s) => s.action.toLowerCase().slice(0, 40)));
  const existingFixText = new Set(existingFix.map((s) => s.action.toLowerCase().slice(0, 40)));

  const newDiag = [...existingDiag];
  for (const builder of diagTemplates) {
    if (newDiag.length >= MIN_DIAG) break;
    const candidate = builder(fm);
    if (existingDiagText.has(candidate.action.toLowerCase().slice(0, 40))) continue;
    newDiag.push({ step: newDiag.length + 1, ...candidate });
  }

  const newFix = [...existingFix];
  for (const builder of fixTemplates) {
    if (newFix.length >= MIN_FIX) break;
    const candidate = builder(fm);
    if (existingFixText.has(candidate.action.toLowerCase().slice(0, 40))) continue;
    newFix.push({ step: newFix.length + 1, ...candidate });
  }

  return {
    ...fm,
    diagnostic_steps: newDiag,
    fix_steps: newFix,
  };
}

async function main(): Promise<void> {
  const inputPath = process.argv[2];
  const outputPath = process.argv[3];
  if (!inputPath || !outputPath) {
    console.error("usage: deepen-fms.ts <input.json> <output.json>");
    process.exit(1);
  }
  const raw = await readFile(inputPath, "utf8");
  const fms: Fm[] = JSON.parse(raw);

  const deepened = fms.map(deepen);

  // Quality stats
  const stats = {
    total: deepened.length,
    stillThin: deepened.filter((f) => (f.diagnostic_steps?.length ?? 0) < MIN_DIAG || (f.fix_steps?.length ?? 0) < MIN_FIX).length,
    avgDiag: (deepened.reduce((a, f) => a + (f.diagnostic_steps?.length ?? 0), 0) / deepened.length).toFixed(2),
    avgFix: (deepened.reduce((a, f) => a + (f.fix_steps?.length ?? 0), 0) / deepened.length).toFixed(2),
  };
  console.error(JSON.stringify(stats, null, 2));

  if (stats.stillThin > 0) {
    console.error(`WARNING: ${stats.stillThin} fms still below minimum thresholds (likely missing template for their leaf).`);
    for (const f of deepened) {
      if ((f.diagnostic_steps?.length ?? 0) < MIN_DIAG || (f.fix_steps?.length ?? 0) < MIN_FIX) {
        console.error(`  ${f.id}: diag=${f.diagnostic_steps?.length} fix=${f.fix_steps?.length}`);
      }
    }
  }

  await writeFile(outputPath, JSON.stringify(deepened, null, 2), "utf8");
  console.error(`wrote ${outputPath}`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.stack : String(err));
  process.exit(1);
});
