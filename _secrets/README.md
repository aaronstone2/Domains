# `_secrets/` — age-encrypted files only

This directory holds **age-encrypted** secrets that are safe to commit to the
repo. The plaintext NEVER appears here.

## What's in here

- `anthropic-key.age` — your Anthropic API key, encrypted with your SSH public
  key. Safe to commit because nothing without your SSH PRIVATE key can decrypt
  it.

## How to provision

One-time, from your trusted machine:

```bash
pnpm bootstrap key encrypt
# prompts for the API key with hidden input
# encrypts using ~/.ssh/id_ed25519.pub (or id_rsa.pub if no ed25519)
# writes ./anthropic-key.age
git add _secrets/anthropic-key.age
git commit -m "ship encrypted anthropic key"
git push
```

## How install consumes it

On any box that has BOTH `~/.ssh/id_ed25519` (or id_rsa) and the `age` binary,
the `anthropic-key` module in `packages/bootstrap` runs:

```bash
age --decrypt -i ~/.ssh/id_ed25519 _secrets/anthropic-key.age \
  > ~/.config/domains/anthropic-key   # chmod 600 atomic write
```

After that, `pnpm bootstrap install --launch` (and `claude` directly) work
zero-paste.

## What's gitignored vs allowed in here

- `*.age` — committed (encrypted, safe)
- `.gitkeep` — committed (so the empty dir survives clones)
- `README.md` (this file) — committed
- **EVERYTHING ELSE** — gitignored. Don't put plaintext secrets here.

## Re-encryption

If you need to add a second SSH recipient (e.g. a second laptop with a
different SSH key), pass multiple `-R` flags:

```bash
age -R ~/.ssh/id_ed25519.pub -R ~/laptop2_id_ed25519.pub \
    -o _secrets/anthropic-key.age <<< 'sk-ant-...'
```

If you rotate your SSH key, re-encrypt and re-commit:

```bash
pnpm bootstrap key encrypt   # uses your current ~/.ssh/id_ed25519.pub
```
