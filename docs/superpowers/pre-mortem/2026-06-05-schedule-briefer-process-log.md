# Pre-Mortem Process Log: schedule-briefer
_생성: 2026-06-05. 결론이 아닌 과정을 기록._

---

## 에이전트 및 역할

| 에이전트 | 역할 | 감정적 레지스터 | 모드 |
|---|---|---|---|
| 서브에이전트 1 | Saboteur | 차가운 쾌감 | 코드 인식 (스펙 파일 접근) |
| 서브에이전트 2 | Burned Expert | 통제된 분노 | 코드 인식 (스펙 파일 접근) |
| Gemini 2.5 Pro | Customer Advocate | 보호적 분노 | 외부 LLM (코드 접근 없음) |
| 서브에이전트 3 | Pessimist | 어두운 만족감 | 코드 인식 |

> Codex (Pessimist 초기 지정)는 exit code 2로 실패 → 서브에이전트로 대체.

---

## 전송된 시나리오 브리핑

```
PROJECT: schedule-briefer — Claude Code subagent
AUDIENCE: EunHye, KNU CS student/researcher, single user, self-maintained
CORE PROMISE: 아침 한 번에 모든 것: Apple Calendar, Notion 할 일, Gmail, Slack,
              KNU 웹사이트 3개, 로컬 git 레포, Claude 메모리. Slack 자동 전달 또는 터미널 출력.
TIMELINE: 개인 툴, 매일 의존
STAKES: 신뢰. 무음 실패 = 마감 놓침. 잘못된 출력 = 폐기.
MOMENTS OF TRUTH: 첫 자동 실행 / 소스 실패 / 학교 마감 놓침 / Slack DM 비어있음

THE SCENARIO:
3개월 후. Notion MCP stale 데이터, Slack MCP rate limit으로 빈 DM, KNU 스크래퍼 2주째 404.
신뢰 소멸. 도구 폐기.
```

---

## 각 에이전트 결과 요약

### Saboteur
**상위 3개 리스크:**
1. Notion MCP 무음 빈 배열 반환
2. KNU WebFetch 404 → 오류페이지 HTML을 정상 파싱
3. icalBuddy PATH 문제 (non-interactive shell)

**"아무도 말하고 싶지 않은 실패":** "에이전트가 완벽해도, 정보 밀도가 너무 높아 3주 안에 스크롤 없이 첫 줄만 읽게 된다."

**독보적 발견:** icalBuddy 자동 실행 환경 PATH 문제 — 수동 실행은 정상이고 자동 실행만 실패해서 한 달이 지나도 원인을 모른다.

---

### Burned Expert
**상위 3개 리스크:**
1. Notion MCP 무음 실패 (자기 의심 패턴)
2. KNU URL 변경 → 즉각적 신뢰 폭발
3. 매일 반복 → 습관화 → 조용한 폐기

**"아무도 말하고 싶지 않은 실패":** "개인 자동화 도구의 사망 원인은 복잡성이 아니라 유지 비용이 사용자의 게으름을 초과하는 순간이다."

**독보적 발견:** 신뢰 침식의 단계적 패턴 (보정 행동 → 섹션별 신뢰 차별화 → 인지 부하 증가 → 조용한 폐기).

---

### Customer Advocate (Gemini)
**상위 3개 리스크:**
1. KNU 404 → 장학금 마감 놓침 (부끄러움 + 멍청한 느낌)
2. Notion 캐시 stale 데이터 → 가스라이팅
3. Gmail 권한 범위 축소 → "inbox zero" 환상

**"아무도 말하고 싶지 않은 실패":** "EunHye는 도구 탓이 아닌 자기 탓을 한다. 도구가 자기 의심을 만들어내는 기계가 된다."

**독보적 발견:** 사용자가 실패를 자신의 무능함으로 귀인하는 패턴 — 기술적 실패가 심리적 상처로 전환됨. 기존 에이전트들이 놓친 관점.

---

### Pessimist
**상위 3개 리스크:**
1. `/schedule` 자동 실행 = Claude Code 세션 필요 → macOS 잠자기 시 스킵
2. Claude Code 업데이트 후 MCP 버전 부정합
3. 7개 통합 유지 비용 누적

**"아무도 말하고 싶지 않은 실패":** "이 도구는 처음부터 사용자를 위한 것이 아니라 제작자의 만족을 위한 것이었다."

**독보적 발견:** `/schedule` 실행 환경 가정 — 노트북을 닫으면 자동 실행이 안 된다는 근본적인 제약. 다른 에이전트가 모두 놓쳤다.

---

## 관점 수렴

다음 리스크는 2개 이상의 역할이 독립적으로 발견 → 보고서에서 Critical 분류:

| 리스크 | 발견한 역할 수 |
|--------|--------------|
| Notion MCP 무음 실패 | 4개 전부 |
| KNU WebFetch 404 무음 처리 | 4개 전부 |
| Slack DM 전송 실패 | 4개 전부 |
| icalBuddy PATH 문제 | Saboteur + Pessimist |
| git 스캔 성능 | Saboteur + Burned Expert |

---

## 관점 충돌

- **Saboteur vs Burned Expert: 신뢰 소멸 경로** — Saboteur는 "기술적 실패가 신뢰를 한 번에 폭발시킨다"고 봤고, Burned Expert는 "섹션별로 점진적으로 신뢰가 죽는다"고 봤다. 종합: 둘 다 맞다. 경로는 소스마다 다르다.
- **Gemini 단독: 자기 귀인 패턴** — 다른 3개 역할은 "도구가 신뢰를 잃는다"에 집중했고, Gemini만 "사용자가 자기 탓을 한다"는 관점을 제시했다. 이 관점은 기술적 완화로 해결되지 않는 부분이라 Uncomfortable Truth에 별도 반영.
- **Pessimist 단독: 제작자 동기 비판** — "도구가 사용자를 위한 게 아니라 제작자 만족을 위한 것"이라는 주장은 다른 역할이 채택하지 않았다. 보고서에 직접 반영하지 않고 과정 로그에만 기록.

---

## 합성 판단

- `/schedule` 세션 의존성을 Critical로 올린 이유: 자동 브리핑이 핵심 기능인데 이게 근본적으로 동작하지 않을 수 있다는 것은 설계 가정 자체의 실패다.
- Gemini의 "Git status checks wrong repo" 리스크는 Watch List로 낮춘 이유: `~/src/repos/` 전체를 스캔하는 방식이라 설정 누락보다는 "엉뚱한 레포가 포함되는" 문제에 가깝다.
- Gmail "중요" 필터 이슈는 Significant로 유지: 치명적이진 않지만 섹션 전체의 신뢰를 죽이는 구조적 문제.

---

## 프로세스 품질 노트

- **지나치게 유사했던 역할:** Saboteur + Burned Expert가 기술적 리스크에서 많이 겹침. 다음엔 Burned Expert를 유지보수 부하에 더 집중시켜야 함.
- **가장 많이 기여한 역할:** Pessimist — `/schedule` 세션 의존성이라는 구조적 문제를 단독 발견. 항상 포함해야 함.
- **이 유형의 프로젝트에서 추가하면 좋을 역할:** Maintenance Auditor (6개월 후 유지보수 비용만 전담), Privacy/Trust Prosecutor (Claude 메모리 파일 접근 범위).
