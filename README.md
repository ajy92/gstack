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

hermes-profile/
├── SOUL.md            GStack 공용 컨텍스트 (에이전트 roster, 규칙)
└── config.yaml        hermes 프로필 설정 (ollama 연결, 병렬화 전략)

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

## 셋업

### 1. hermes 프로필 설치

```bash
mkdir -p ~/.hermes/profiles/gstack/memories
cp hermes-profile/SOUL.md ~/.hermes/profiles/gstack/SOUL.md
cp hermes-profile/config.yaml ~/.hermes/profiles/gstack/config.yaml
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
