---
name: project-notes
description: ADR 작성 또는 프로젝트 회고 작성. "ADR 써줘", "아키텍처 결정 기록해줘" → 프로젝트 docs/decisions/에 ADR 생성. "회고 써줘" → ${NOTES_DIR}/Projects/<ProjectName>.md 생성 후 Notes 저장소 커밋·푸시.
---

# project-notes

두 가지 작업을 처리한다:
- **ADR**: 아키텍처 결정을 프로젝트 `docs/decisions/NNN-제목.md`에 기록
- **회고**: 프로젝트 완료 후 `${NOTES_DIR}/Projects/<ProjectName>.md` 작성

**Announce at start:** "project-notes 에이전트로 [ADR / 회고]를 작성하겠습니다."

## Local Configuration

`${AGENT_RULES_CONFIG:-$HOME/.config/agent-rules/local-values.env}`에서 `NOTES_DIR`을 읽는다. 파일이 없거나 값이 비어 있으면 저장 전에 사용자에게 경로를 확인한다.

```bash
CONFIG_FILE="${AGENT_RULES_CONFIG:-$HOME/.config/agent-rules/local-values.env}"
[ -f "$CONFIG_FILE" ] && set -a && . "$CONFIG_FILE" && set +a
```

---

## ADR 작성

### 트리거
"ADR 써줘", "아키텍처 결정 기록해줘", "결정 기록해줘" 등.

### 저장 위치
현재 프로젝트 루트의 `docs/decisions/NNN-제목.md`.
- `NNN`: 기존 파일 확인 후 다음 번호 (없으면 001)
- 제목: kebab-case (예: `001-db-selection.md`)
- `docs/decisions/` 폴더가 없으면 생성

### 내용 수집
- 어떤 결정을 했는지
- 어떤 선택지를 고려했는지
- 왜 이 선택을 했는지
- 예상되는 결과/영향

### ADR 포맷

```
# ADR-NNN: <제목>

## Status
Accepted

## Context
어떤 상황에서 이 결정이 필요했는가.

## Decision
무엇을 결정했는가.

## Tradeoffs
| 선택지 | 장점 | 단점 |
|--------|------|------|
| A      | ...  | ...  |
| B      | ...  | ...  |

## Consequences
이 결정의 결과와 영향.
```

### 커밋 (사용자 확정 후)

초안 확인 완료 후 반드시 별도로 확인:
```
"이대로 커밋·푸시할까요?" → 명시적 OK 받기 전까지 git 명령 실행 금지
```

```bash
git add docs/decisions/
git commit -m "docs: ADR-NNN — <제목>"
git push origin <현재 브랜치>
```

---

## 회고 작성

### 트리거
"회고 써줘", "retrospective 써줘" 등.

### 저장 위치
`${NOTES_DIR}/Projects/<ProjectName>.md`
- 프로젝트명을 컨텍스트에서 파악하거나 사용자에게 확인
- 파일이 이미 있으면:
  1. 기존 내용 Read
  2. "기존 회고가 있어요. 덮어쓸까요, 아니면 내용을 보강할까요?" 확인
  3. 보강이면 기존 내용 참고해서 merge, 덮어쓰기면 새로 작성

### 내용 수집
- 잘 된 것
- 힘들었던 것과 해결 방법 (Challenges)
- 다음엔 다르게 할 것
- 남은 것 / 아쉬운 것

### 회고 포맷

```
# Retrospective — <ProjectName>

## Overview
- 목적:
- 기간:
- GitHub:

## Tech Stack
- ...

## 잘 된 것
- ...

## Challenges
- 문제: ...
  해결: ...

## 다음엔 다르게 할 것
- ...

## 남은 것 / 아쉬운 것
- ...
```

초안 출력 후 "수정할 부분 있으면 말해줘" 라고 묻는다. 확정 전까지 반복.

### 커밋·푸시 (사용자 확정 후)

초안 확인 완료 후 반드시 별도로 확인:
```
"이대로 커밋·푸시할까요?" → 명시적 OK 받기 전까지 git 명령 실행 금지
```

```bash
git -C "$NOTES_DIR" add "Projects/<ProjectName>.md"
git -C "$NOTES_DIR" commit -m "docs: <ProjectName> — retrospective"
git -C "$NOTES_DIR" push origin main
```

---

## Notes

- 사용자가 말한 내용을 과장하거나 부풀리지 않는다.
- Tradeoffs 테이블은 실제로 고민한 선택지가 있을 때만 작성한다.
- 내용이 적어도 괜찮다. 짧게라도 기록하는 게 목적.
