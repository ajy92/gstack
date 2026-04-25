# GStack — ASMR YouTube Auto-Pipeline

Paperclip + Hermes 기반 AI 에이전트 팀. 빗소리 ASMR 영상을 자동으로 제작하여 YouTube에 매일 1개씩 업로드한다.

## 파이프라인

```
Stage 1: Content Generator  → ~/asmr-output/plans/DATE_기획서.md
Stage 2: Equipment Specialist → ~/asmr-output/assets/DATE_rain.wav
         SEO Specialist       → ~/asmr-output/seo/DATE_seo.md
Stage 3: Content Creator      → ~/asmr-output/videos/DATE_빗소리.mp4
Stage 4: Upload Agent         → YouTube URL
```

CEO가 10분 heartbeat로 파이프라인을 감시하고, Ops Agent가 장애를 감지·복구한다.

## 구조

```
agents/
├── ceo/               CEO — 파이프라인 게이팅 (10분 heartbeat)
│   └── reference/     HIRING.md, COMPANY_SETUP.md (on-demand)
├── ops/               Ops Agent — 장애 감지·복구 (heartbeat)
├── content-generator/ Stage 1 — 기획서 작성 (qwen3.5:35b)
├── equipment-specialist/ Stage 2 — 오디오 처리 (qwen3.5:35b)
├── seo-specialist/    Stage 2 — SEO 메타데이터 (qwen3.5:9b)
├── content-creator/   Stage 3 — ffmpeg 영상 합성 (qwen3.5:35b)
├── content-strategist/ 전략 지원 (qwen3.5:9b)
└── upload-agent/      Stage 4 — YouTube 업로드 (qwen3.5:9b)

hermes-profiles/
├── gstack-mgmt/       CEO + Ops — 파이프라인 관리 + 장애 진단 memory
│   ├── SOUL.md
│   └── config.yaml
├── gstack-prod-35b/   Content Generator + Equipment + Creator — 창작/도구 memory
│   ├── SOUL.md
│   └── config.yaml
└── gstack-prod-9b/    SEO + Upload + Strategist — 텍스트/API memory
    ├── SOUL.md
    └── config.yaml

scripts/
├── ollama-watchdog.sh              ollama hang 감지 및 자동 재시작
└── com.gstack.ollama-watchdog.plist  launchd 데몬 설정
```

## 모델 전략

| 모델 | 에이전트 | 역할 |
|------|----------|------|
| qwen3.5:9b (~8GB) | CEO, Ops, SEO, Upload, Strategist | 오케스트레이션 |
| qwen3.5:35b (~24GB) | Content Generator, Equipment, Creator | 창작/도구 작업 |

두 모델을 동시에 로드해 Stage 2 병렬 실행(Equipment + SEO)을 지원한다.

### Memory 분리 (프로필별)

각 프로필은 독립적인 `memories/MEMORY.md`를 가져 역할별 학습이 섞이지 않는다.

| 프로필 | memory 축적 내용 | 2200자 한도 |
|--------|-----------------|-------------|
| gstack-mgmt | 파이프라인 패턴, 장애 root cause, 사용자 선호 | 독립 |
| gstack-prod-35b | ffmpeg 옵션, 오디오 처리 팁, freesound quirk | 독립 |
| gstack-prod-9b | SEO 메타데이터 패턴, YouTube API 사용법 | 독립 |

## 셋업

### 1. hermes 프로필 설치

```bash
for profile in gstack-mgmt gstack-prod-35b gstack-prod-9b; do
  mkdir -p ~/.hermes/profiles/$profile/memories
  cp hermes-profiles/$profile/SOUL.md ~/.hermes/profiles/$profile/SOUL.md
  cp hermes-profiles/$profile/config.yaml ~/.hermes/profiles/$profile/config.yaml
done
```

### 2. ollama watchdog 설치

```bash
mkdir -p ~/bin
cp scripts/ollama-watchdog.sh ~/bin/ollama-watchdog.sh
chmod +x ~/bin/ollama-watchdog.sh
cp scripts/com.gstack.ollama-watchdog.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.gstack.ollama-watchdog.plist
```

### 3. Paperclip 에이전트 등록

각 에이전트의 AGENTS.md를 Paperclip에 등록한다. UUID는 Paperclip 서버에서 부여된다.

```bash
# 에이전트 목록 확인
curl -s "http://127.0.0.1:3100/api/companies/{COMPANY_ID}/agents" | \
  python3 -c "import sys,json; [print(a['name'], a['id']) for a in json.load(sys.stdin)]"
```

### 4. 출력 디렉토리

```bash
mkdir -p ~/asmr-output/{plans,assets,videos,seo}
```

## 장애 대응

- **ollama hang** → watchdog이 30초 내 감지 후 자동 재시작
- **에이전트 hang** → Ops Agent heartbeat가 25~50분 임계값 초과 시 blocked 처리
- **파이프라인 중단** → CEO 10분 heartbeat가 파일 확인 후 다음 스테이지 태스크 생성
- **사용자 입력 필요** → 에이전트가 Paperclip approvals API로 요청 전송
