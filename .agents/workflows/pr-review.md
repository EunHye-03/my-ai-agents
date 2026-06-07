---
description: PR 리뷰 루프 — PR 타입별 페르소나 조합으로 병렬 리뷰 후 우선순위화된 피드백 작성
---

When the user types `/pr-review <PR번호 또는 브랜치명> [--type <타입>]`, execute the following:

> Claude Code 환경에서는 `pr-reviewer` 서브에이전트(`.claude/agents/pr-reviewer.md`)가 이 로직을 실행한다.

## Step 1: 컨텍스트 수집

```bash
gh pr diff <PR번호>
gh pr view <PR번호>
```

`artifacts/issue.md`가 있으면 읽어 수용 기준을 파악한다.
없으면 PR 설명에서 목적을 추론한다.

## Step 2: PR 타입 결정

`--type` 플래그가 있으면 그대로 사용한다.
없으면 diff를 분석해 아래 기준으로 자동 추론한다. 모호한 경우 사용자에게 확인 후 진행한다.

| 타입 | 판단 기준 | 실행 페르소나 |
|------|----------|-------------|
| `feature` | 새 파일 또는 새 API 엔드포인트 추가 | @reviewer + @adversarial + @security + @qa |
| `hotfix` | 단일 버그 수정, 변경 범위 좁음 | @reviewer + @security |
| `refactor` | 기능 변경 없이 구조 재편 | @reviewer + @adversarial |
| `docs/chore` | 문서, 설정, 의존성만 변경 | @reviewer |

## Step 3: 페르소나별 컨텍스트 준비

| 페르소나 | 받는 정보 |
|---------|---------|
| @reviewer | diff 전체 + 수용 기준 + 스펙 |
| @adversarial | diff + 테스트 파일만 (스펙 없음) |
| @security | diff만 (스펙 없음 — 바이어스 제거) |
| @qa | 테스트 파일 + 변경 파일 목록 |

## Step 4: 페르소나별 리뷰 실행

타입에 따라 결정된 조합으로 각 관점에서 순차 분석한다. 지적 사항 형식:

```
- [심각도: 필수/권장/참고] 내용
  신뢰도: High / Medium / Low
  파일: path/to/file:line
```

`artifacts/review-{페르소나}.md`에 저장한다.

## Step 5: 취합 → artifacts/review-final.md

중복 항목은 합치고 출처 표시. 필수 → 권장 → 참고 순, High 신뢰도 우선.

```markdown
# PR 리뷰 결과
**PR**: #번호 | **타입**: ... | **리뷰어**: ...
**결론**: 승인 / 수정 후 승인 / 반려

## 🔴 필수 수정
- [ ] 내용 (출처: @security, High) — 파일:줄

## 🟠 권장 사항
- [ ] 내용 (출처: @reviewer, Medium)

## 🔵 참고
- 내용 (출처: @adversarial, Low)
```

전체 내용을 사용자에게 출력한다.

## Step 6: 수정 후 선택적 재리뷰

재실행 시 `artifacts/review-final.md`에서 미완료(`- [ ]`) 항목과 출처 페르소나를 읽는다.
해당 페르소나만 재확인한다 (전체 재실행 금지).
완료 항목을 `- [x]`로 표시하고 파일을 업데이트한다.
미완료 항목이 없으면 "모든 지적 사항 해결됨 — 승인 가능"을 출력한다.
