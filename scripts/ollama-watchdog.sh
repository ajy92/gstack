#!/bin/bash
# ollama-watchdog.sh — hang 감지 및 자동 재시작
# 30초마다 ollama 헬스체크. 응답 없으면 재시작 후 Paperclip에 알림

COMPANY_ID="473939b4-12c7-4c47-9576-d617c0a07180"
API="http://127.0.0.1:3100/api"
OLLAMA_URL="http://127.0.0.1:11434"
LOG="$HOME/.hermes/profiles/gstack/logs/ollama-watchdog.log"
FAIL_COUNT=0
MAX_FAILS=2  # 연속 2회 실패 시 재시작

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
      -d "{\"body\":\"⚠️ Watchdog: ollama hang 감지 → 재시작 후 blocked 처리. CEO가 todo로 전환 필요.\"}" > /dev/null
    log "  blocked: $issue_id ($title)"
  done <<< "$ISSUES"
}

log "🚀 ollama watchdog 시작 (체크 간격: 30초, 재시작 임계값: ${MAX_FAILS}회 연속 실패)"

while true; do
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

  sleep 30
done
