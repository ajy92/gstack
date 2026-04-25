#!/bin/bash
# ollama-watchdog.sh — hang 감지 + 실패 감지 → Ops Agent 자동 트리거
# 30초마다: (1) ollama 헬스체크  (2) heartbeat 실패 감지 → Ops 즉시 호출

COMPANY_ID="473939b4-12c7-4c47-9576-d617c0a07180"
OPS_AGENT_ID="f4dfa305-cbf7-4f6e-80b9-47b246b67b02"
API="http://127.0.0.1:3100/api"
OLLAMA_URL="http://127.0.0.1:11434"
LOG="$HOME/.hermes/profiles/gstack/logs/ollama-watchdog.log"
SEEN_FAILURES_FILE="$HOME/.hermes/profiles/gstack/logs/seen-failures.txt"
FAIL_COUNT=0
MAX_FAILS=2
CHECK_COUNT=0

touch "$SEEN_FAILURES_FILE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"
}

restart_ollama() {
  log "⚠️  ollama 재시작 중..."
  pkill -f "ollama serve" 2>/dev/null
  sleep 3
  nohup ollama serve >> "$LOG" 2>&1 &
  sleep 5
  log "✅ ollama 재시작 완료"

  # Paperclip in_progress 이슈 모두 blocked으로 전환
  ISSUES=$(curl -s "$API/companies/$COMPANY_ID/issues" | python3 -c "
import sys, json
data = json.load(sys.stdin)
issues = data.get('issues', data) if isinstance(data, dict) else data
for i in issues:
    if i.get('status') == 'in_progress':
        print(i['id'], i.get('title','')[:40])
")

  while IFS=' ' read -r issue_id title; do
    [ -z "$issue_id" ] && continue
    curl -s -X PATCH "$API/issues/$issue_id" \
      -H "Content-Type: application/json" \
      -d '{"status":"blocked"}' > /dev/null
    curl -s -X POST "$API/issues/$issue_id/comments" \
      -H "Content-Type: application/json" \
      -d "{\"body\":\"⚠️ Watchdog: ollama hang 감지 → 재시작 후 blocked 처리.\"}" > /dev/null
    log "  blocked: $issue_id ($title)"
  done <<< "$ISSUES"

  trigger_ops "ollama 재시작 발생"
}

trigger_ops() {
  local reason="$1"
  log "🔔 Ops Agent 트리거: $reason"

  # Ops Agent가 이미 실행 중이면 스킵
  OPS_STATUS=$(curl -s "$API/agents/$OPS_AGENT_ID" | python3 -c "
import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null)

  if [ "$OPS_STATUS" = "busy" ] || [ "$OPS_STATUS" = "running" ]; then
    log "  Ops Agent 이미 실행 중 — 스킵"
    return
  fi

  # Ops Agent heartbeat 즉시 실행
  npx --yes paperclipai@latest heartbeat run \
    --agent-id "$OPS_AGENT_ID" \
    --api-base "$API" \
    --trigger "callback" \
    --timeout-ms 0 \
    >> "$LOG" 2>&1 &

  # macOS 알림
  osascript -e "display notification \"$reason → Ops Agent 자동 실행됨\" with title \"🔧 GStack Watchdog\" sound name \"Submarine\"" 2>/dev/null

  log "  Ops Agent heartbeat 실행 시작"
}

check_heartbeat_failures() {
  # 최근 10개 heartbeat run 중 failed/timed_out 확인
  NEW_FAILURES=$(curl -s --max-time 10 "$API/companies/$COMPANY_ID/heartbeat-runs?limit=10" | python3 -c "
import sys, json
data = json.load(sys.stdin)
runs = data.get('runs', data) if isinstance(data, dict) else data
for r in (runs or []):
    if r.get('status') in ('timed_out', 'failed', 'error'):
        rid = r.get('id', '')
        agent = (r.get('agentId','') or '')[:8]
        print(f'{rid}|{agent}|{r.get(\"status\")}')
" 2>/dev/null)

  if [ -z "$NEW_FAILURES" ]; then
    return
  fi

  UNSEEN=""
  while IFS='|' read -r run_id agent_id status; do
    [ -z "$run_id" ] && continue
    if ! grep -q "$run_id" "$SEEN_FAILURES_FILE" 2>/dev/null; then
      echo "$run_id" >> "$SEEN_FAILURES_FILE"
      UNSEEN="$UNSEEN $agent_id:$status"
    fi
  done <<< "$NEW_FAILURES"

  if [ -n "$UNSEEN" ]; then
    log "🚨 새로운 heartbeat 실패 감지:$UNSEEN"
    trigger_ops "heartbeat 실패 감지:$UNSEEN"
  fi
}

log "🚀 watchdog 시작 (ollama 30초 + 실패 감지 60초 간격)"

while true; do
  # --- ollama 헬스체크 (매 30초) ---
  RESPONSE=$(curl -s --max-time 8 "$OLLAMA_URL/api/tags" 2>/dev/null)

  if [ -z "$RESPONSE" ]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log "❌ ollama 응답 없음 (연속 ${FAIL_COUNT}/${MAX_FAILS}회)"

    if [ "$FAIL_COUNT" -ge "$MAX_FAILS" ]; then
      restart_ollama
      FAIL_COUNT=0
    fi
  else
    if [ "$FAIL_COUNT" -gt 0 ]; then
      log "✅ ollama 응답 복구됨"
    fi
    FAIL_COUNT=0
  fi

  # --- heartbeat 실패 감지 (매 60초 = 2번째 루프마다) ---
  CHECK_COUNT=$((CHECK_COUNT + 1))
  if [ $((CHECK_COUNT % 2)) -eq 0 ]; then
    check_heartbeat_failures
  fi

  # --- seen-failures 파일 크기 제한 (최근 200줄만 유지) ---
  if [ $(wc -l < "$SEEN_FAILURES_FILE" 2>/dev/null || echo 0) -gt 200 ]; then
    tail -100 "$SEEN_FAILURES_FILE" > "${SEEN_FAILURES_FILE}.tmp"
    mv "${SEEN_FAILURES_FILE}.tmp" "$SEEN_FAILURES_FILE"
  fi

  sleep 30
done
