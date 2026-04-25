# New Paperclip Company Setup Reference

Every new Paperclip company needs an isolated hermes profile to prevent obsidian/personal context leaking into agents.

## Step 1 — Create profile directory
```bash
PROFILE="{company_slug}"
mkdir -p ~/.hermes/profiles/$PROFILE/memories
```

## Step 2 — Write SOUL.md
`~/.hermes/profiles/$PROFILE/SOUL.md` must contain:
- Company name and mission (1-2 sentences)
- Pipeline stages and owners
- Shared output directories and naming conventions
- Paperclip API base URL + company ID
- Agent roster table (name | UUID | role)
- Behavior rules (done marking, tool constraints)
- ⚠️ Warning: "roster는 참고용. 실제 존재 여부는 API로 확인"

Do NOT include: obsidian paths, personal info, cron jobs, memory sync rules.

## Step 3 — Copy config.yaml from gstack reference
```bash
cp ~/.hermes/profiles/gstack/config.yaml ~/.hermes/profiles/$PROFILE/config.yaml
```
Change only:
- `model.default` → company model (default: `qwen3.5:9b`)
- `custom_providers[0].model` → same as model.default

Do NOT change: `terminal.backend`, `base_url`, `ollama_num_ctx`, `toolsets`, `approvals.mode`

## Step 4 — Hire all agents with profile flag
```bash
"adapterConfig": {
  "model": "qwen3.5:9b",
  "timeoutSec": 1800,
  "persistSession": false,
  "extraArgs": ["--profile", "{company_slug}"],
  "cwd": "/absolute/path/to/output"
}
```
`cwd` is mandatory — without it agents write to the paperclip server's working directory.
