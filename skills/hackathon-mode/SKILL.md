---
name: hackathon-mode
description: Use when building under a hard deadline — hackathon, rapid prototype, demo, proof-of-concept, or "make something working by X". Switches development mode from quality-first to demo-first. Normal rules (ADR, TDD, PR, worktree) are explicitly suspended.
---

# Hackathon Mode

## 핵심 원칙

**데모가 동작하는 것 > 코드 품질.** 마감 전에 동작하는 데모가 없으면 나머지는 의미 없다.

기본 개발 루틴(Issue → ADR → worktree → TDD → PR)은 **이 스킬이 활성화된 동안 정지**된다.

## 트리거

다음 표현이 나오면 이 스킬을 invoke한다:
- "해커톤", "프로토타입", "빠르게 만들어", "데모 만들어", "PoC", "MVP"
- "prototype", "hackathon", "quick demo", "proof of concept"
- 마감 시간이 명시된 빌드 요청 ("내일까지", "3시간 안에", "오늘 발표")

## 정지되는 규칙

| 정상 루틴 | 해커톤 모드 |
|-----------|------------|
| GitHub Issue 필수 | 생략 — 바로 시작 |
| ADR 작성 | 생략 — 결정은 인라인 주석으로 |
| worktree 분기 | 생략 — main 직접 커밋 허용 |
| TDD | 최소화 — 데모 경로 스모크 테스트만 |
| PR 경유 | 생략 — 직접 push 허용 |
| 코드 리뷰 | 생략 |

**단, 시크릿/자격증명 커밋 금지는 유지된다.**

## 5단계 워크플로우

### 1단계: SCOPE (15분)
데모에서 반드시 동작해야 하는 것만 정의한다.

```
질문:
- 심사위원/관객에게 보여줄 핵심 흐름이 뭔가?
- 그 흐름에 필요한 최소 기능은?
- 없어도 데모에 지장 없는 것은?
```

출력: `must_have[]` / `nice_to_have[]` / `cut[]` 3분류

**스코프 컷 기준**: 구현 시간이 전체의 20% 초과하는 기능은 모두 모의(mock)로 대체한다.

### 2단계: STACK (5분)
데모 요구사항에 맞는 최소 스택을 선택한다. 고정 스택 없음 — 상황 판단 우선.

**Backend 선택 기준**:
```
REST API 필요, Python 선호       → FastAPI + uvicorn
DB 모델 + 어드민이 핵심          → Django (ORM + admin 패널 내장)
REST API 필요, Java/Kotlin 선호  → Spring Boot
AI 모델 서빙, 빠른 프로토        → FastAPI (Python 생태계 활용)
백엔드 불필요 (브라우저 only)    → 생략
```

**Frontend 선택 기준**:
```
UI가 단순하거나 데이터 중심      → 단일 HTML 파일 (vanilla JS)
AI 데모, 빠른 인터랙티브 UI     → Streamlit
컴포넌트가 많고 상태 복잡        → React + Vite (빌드 포함 감수)
```

**공통 원칙**:
```
AI/ML:  기존 모델/API 직접 호출 — 학습 없음
DB:     SQLite 또는 인메모리 dict — 운영 DB 불필요
Auth:   없음 — 하드코딩된 토큰으로 대체
```

선택 이유를 한 줄 인라인 주석으로 남긴다. (예: `// FastAPI 선택 — Python CV 라이브러리 활용 필요`)

### 3단계: PLAN (10분)
태스크를 30분~2시간 단위로 분해한다.

```yaml
형식:
- id: T-01
  title: "..."
  estimated_hours: N
  depends_on: []
  demo_critical: true/false  # 데모 경로에 필수인지

buffer: 전체 시간의 15% 확보 (통합/디버깅용)
critical_path: 데모 경로에 필수인 태스크만
```

`demo_critical: true` 태스크를 먼저 완료한다. 시간이 남으면 나머지.

### 4단계: EXECUTE
- 독립 태스크가 2개 이상이면 → `superpowers:dispatching-parallel-agents` 호출
- 순차 실행이면 → `superpowers:executing-plans` 호출
- 각 태스크 완료 후 스모크 테스트: **데모 경로가 실제로 동작하는가?**

### 5단계: DEMO CHECK
발표 30분 전 필수 체크.

```
□ 데모 흐름을 처음부터 끝까지 3번 실행 — 매번 동작해야 함
□ 에러 메시지가 화면에 노출되지 않음
□ 느린 구간에 로딩 표시 또는 사전 로드
□ 네트워크 없이도 동작하는가? (발표장 Wi-Fi 불안정 대비)
□ 환경변수/시크릿이 코드에 하드코딩되어 있지 않음
```

## 스택별 빠른 시작

### FastAPI + HTML
```bash
mkdir proto && cd proto
python -m venv .venv && source .venv/bin/activate
pip install fastapi uvicorn python-multipart
# main.py — API + static 서빙 / index.html — UI
# uvicorn main:app --reload
```

### Django (DB + 어드민 필요 시)
```bash
pip install django djangorestframework
django-admin startproject proto && cd proto
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
# /admin 에서 데이터 바로 확인 가능
```

### Spring Boot
```bash
# Spring Initializr (start.spring.io) — Web, DevTools 선택
./gradlew bootRun
# 또는 mvn spring-boot:run
```

### Streamlit (AI/데이터 데모)
```bash
pip install streamlit
# app.py 하나로 완성
# streamlit run app.py
```

### 단일 HTML (빌드 없는 UI)
```html
<!-- CDN만으로 동작, 브라우저에서 바로 열기 -->
<script src="https://unpkg.com/vue@3"></script>
```

## 시간대별 체크포인트

| 경과 시간 | 체크 |
|-----------|------|
| 25% | 백엔드 엔드포인트 1개 이상 응답하는가? |
| 50% | 데모 경로 앞부분이 동작하는가? |
| 75% | 전체 데모 흐름이 연결됐는가? |
| 90% | 데모 3회 연속 성공했는가? |

90% 시점에 데모가 안 되면 → nice_to_have를 전부 잘라내고 동작하는 것만 남긴다.

## 모의(Mock) 처리 기준

다음은 항상 모의로 대체한다:
- **인증**: 하드코딩 토큰 또는 인증 없음
- **DB 영속성**: 인메모리 dict 또는 SQLite
- **외부 API**: 응답 고정 JSON 반환
- **ML 추론**: 미리 계산된 결과 반환
- **이메일/알림**: print/log로 대체

**단**, 데모의 핵심 가치가 해당 기능에 있다면 모의 불가. 그게 핵심이면 실제로 구현한다.

## 완료 후 정리

해커톤 종료 후 코드를 계속 쓸 계획이라면:
- `TODO: hackathon-debt` 주석으로 기술 부채 표시
- 모의 처리된 부분 문서화
- 정지됐던 루틴 복원 (Issue, ADR, PR 등)

계속 안 쓸 코드라면 그냥 아카이브.

## 관련 스킬

- `superpowers:brainstorming` — 아이디어가 막연할 때 scope 전에 호출
- `superpowers:dispatching-parallel-agents` — 독립 태스크 병렬 실행
- `rapid-prototyper` — 단일 기능 프로토타입 빠르게 생성
- `shipping-and-launch` — 데모 배포가 필요한 경우
