# Agent Hiring Reference

## Pre-hire check (ALWAYS run first)

Before creating any agent, verify it doesn't already exist:
```bash
curl -s "http://127.0.0.1:3100/api/companies/473939b4-12c7-4c47-9576-d617c0a07180/agents" | \
  python3 -c "import sys,json; [print(a['name'], a['id']) for a in json.load(sys.stdin)]"
```
If same name exists → use that agent. Do NOT create a duplicate.
**Never rely on SOUL.md roster — always verify via API.**

## Hire command

Valid `role` values: `ceo | cto | cmo | cfo | engineer | designer | pm | qa | devops | researcher | general`

```bash
curl -s -X POST "http://127.0.0.1:3100/api/companies/473939b4-12c7-4c47-9576-d617c0a07180/agents" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "에이전트 이름",
    "title": "직함",
    "role": "engineer",
    "adapterType": "hermes_local",
    "adapterConfig": {
      "model": "qwen3.5:9b",
      "timeoutSec": 1800,
      "persistSession": false,
      "extraArgs": ["--profile", "gstack"],
      "cwd": "/Users/home/asmr-output"
    }
  }'
```

## After hiring

1. Note the new agent's `id` from the response
2. Create instructions directory and write AGENTS.md:
   ```bash
   mkdir -p ~/.paperclip/instances/default/companies/473939b4-12c7-4c47-9576-d617c0a07180/agents/{NEW_ID}/instructions
   ```
3. Write AGENTS.md with:
   - Agent role and responsibilities
   - Output directory (`mkdir -p` + absolute path)
   - Paperclip task lifecycle rules (with file verification + blocked escalation)
   - Issue ID note (use `id` UUID, not `identifier`)
