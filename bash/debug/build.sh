#!/usr/bin/env bash
# debug/build.sh — diagnose Docker build failures (Dockerfile, buildkit, layers)
#
# Reads: Dockerfile, build cache, image history, layer sizes
# Writes: nothing (read-only — safe in prod)
#
# Usage:   debug/build.sh [dockerfile] [image]
# Example: debug/build.sh Dockerfile myapp:latest
#          debug/build.sh                            # auto-detect Dockerfile

set +e

df="${1:-Dockerfile}"
img="${2:-}"
section() { echo ""; echo "=== $* ==="; }

if [ "$df" = "-h" ] || [ "$df" = "--help" ]; then
  sed -n '2,10p' "$0" | sed 's/^# *//'
  exit 0
fi

section "Dockerfile exists?"
if [ -f "$df" ]; then
  echo "  ✓ Found: $df ($(wc -l < "$df") lines)"
else
  echo "  ✗ NOT FOUND: $df"
  echo "  Searching for Dockerfiles..."
  find . -maxdepth 3 -name 'Dockerfile*' -o -name '*.dockerfile' 2>/dev/null | head -10
  exit 1
fi

section "Dockerfile lint (common issues)"
# Check for common anti-patterns
echo "  Checking for issues..."
grep -n 'ADD ' "$df" 2>/dev/null | grep -v '.tar\|.gz\|http' | while read -r line; do
  echo "  WARN: $line  (use COPY instead of ADD for local files)"
done
grep -n 'apt-get install' "$df" 2>/dev/null | grep -v 'apt-get update' | grep -v '&&' | while read -r line; do
  echo "  WARN: $line  (apt-get install without apt-get update in same RUN)"
done
grep -n '^RUN.*cd ' "$df" 2>/dev/null | while read -r line; do
  echo "  WARN: $line  (use WORKDIR instead of cd in RUN)"
done
grep -qE '^HEALTHCHECK' "$df" || echo "  INFO: no HEALTHCHECK instruction defined"
grep -c '^FROM' "$df" | { read -r n; [ "$n" -gt 1 ] && echo "  INFO: multi-stage build ($n stages)" || echo "  INFO: single-stage build"; }

section "Multi-stage ARG check"
# ARGs before first FROM are global but must be re-declared after each FROM
awk '/^ARG /{args[$2]=NR} /^FROM/{stage++; if(stage>1) for(a in args) if(!seen[a]) print "  CHECK: ARG "a" (line "args[a]") might need re-declaration after FROM at line "NR; for(a in args) seen[a]=1}' "$df" 2>/dev/null

section "Base images used"
grep '^FROM' "$df" | while read -r line; do
  echo "  $line"
done

section ".dockerignore check"
dir=$(dirname "$df")
if [ -f "$dir/.dockerignore" ]; then
  echo "  ✓ .dockerignore exists ($(wc -l < "$dir/.dockerignore") rules)"
  grep -c 'node_modules\|\.git\|__pycache__' "$dir/.dockerignore" | {
    read -r n; [ "$n" -gt 0 ] && echo "  ✓ common exclusions found" || echo "  WARN: missing node_modules/.git/__pycache__ exclusions"
  }
else
  echo "  ✗ NO .dockerignore — build context may include everything (slow!)"
fi

if [ -n "$img" ]; then
  section "Image history (layer sizes): $img"
  docker history "$img" --format 'table {{.Size}}\t{{.CreatedBy}}' 2>/dev/null | head -20

  section "Image size"
  docker image inspect "$img" --format 'Size={{.Size}} ({{printf "%.1f" (divf .Size 1048576)}}MB)' 2>/dev/null || \
    docker images "$img" --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' 2>/dev/null
fi

section "Build cache"
docker builder prune --dry-run 2>/dev/null | tail -3 || echo "  (buildkit info not available)"
docker system df 2>/dev/null | grep 'Build Cache'

section "HINTS"
echo "• Build fails at npm install: check .dockerignore excludes node_modules"
echo "• ARG not available after FROM: re-declare ARG after each FROM in multi-stage"
echo "• COPY --from=build fails: make sure the stage is named (FROM ... AS build)"
echo "• Layer cache invalidated: order Dockerfile — deps first, code second"
echo "• 'no space left on device' during build: docker builder prune"
echo "• Slow builds: add .dockerignore, use multi-stage, cache package manager layers"
