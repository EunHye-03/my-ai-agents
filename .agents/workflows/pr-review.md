---
description: PR 리뷰 루프 — PR 타입별 페르소나 조합으로 병렬 리뷰 후 우선순위화된 피드백 작성
---

When the user types `/pr-review <PR번호 또는 브랜치명> [--type <타입>]`, execute the following:

## Step 1: 컨텍스트 수집

PR의 변경 파일 목록과 diff를 수집한다.
`artifacts/issue.md`가 있으면 읽어 수용 기준을 파악한다.
없으면 PR 설명에서 목적을 추론한다.

## Step 2: PR 타입 결정

`--type` 플래그가 있으면 그대로 사용한다.
없으면 diff를 분석해 아래 기준으로 자동 추론한다:

| 타입 | 판단 기준 | 실행 페르소나 |
|------|----------|-------------|
| `feature` | 새 파일 또는 새 API 엔드포인트 추가 | @reviewer + @adversarial + @security + @qa |
| `hotfix` | 단일 버그 수정, 변경 범위 좁음 | @reviewer + @security |
| `refactor` | 기능 변경 없이 구조 재편, 테스트 파일 다수 수정 | @reviewer + @adversarial |
| `docs/chore` | 문서, 설정, 의존성만 변경 | @reviewer |

타입을 출력한 뒤 진행한다. 모호한 경우 사용자에게 확인 후 진행한다.

## Step 3: 페르소나별 컨텍스트 준비

각 리뷰어는 자신의 관점에 필요한 정보만 받는다:

| 리뷰어 | 제공 컨텍스트 |
|--------|-------------|
| @reviewer | diff 전체 + `artifacts/issue.md` (수용 기준) + 관련 스펙 문서 |
| @adversarial | diff 전체 + 테스트 파일만 (스펙 없음 — 가정 없이 엣지 케이스 탐색) |
| @security | diff 전체만 (스펙 없음 — "이건 설계상 OK"라는 바이어스 제거) |
| @qa | 테스트 파일 + 변경된 소스 파일 목록 (커버리지 관점) |

## Step 4: 병렬 리뷰 실행

Step 2에서 결정된 페르소나 조합으로 동시에 리뷰를 실행한다.
각 리뷰어는 지적 사항마다 아래 형식으로 기록한다:

```
- [심각도: 필수/권장/참고] 내용
  신뢰도: High / Medium / Low
  파일: path/to/file.py:line
```

결과를 각자의 파일에 저장한다:
- `artifacts/review-reviewer.md`
- `artifacts/review-adversarial.md` (해당 시)
- `artifacts/review-security.md` (해당 시)
- `artifacts/review-qa.md` (해당 시)

## Step 5: 취합 + 우선순위화

모든 리뷰 결과를 읽어 `artifacts/review-final.md`를 작성한다.

**중복 처리**: 2명 이상이 같은 문제를 지적하면 단일 항목으로 합치고 출처를 표시한다.
**우선순위**: 필수 항목 → 권장 → 참고 순으로 정렬한다.
**신뢰도 가중**: High 신뢰도 항목을 Low보다 앞에 배치한다.

`artifacts/review-final.md` 형식:

```markdown
# PR 리뷰 결과

**PR**: #번호 | **타입**: feature/hotfix/refactor/docs | **리뷰어**: @reviewer, @security, ...
**결론**: 승인 / 수정 후 승인 / 반려

## 🔴 필수 수정
- [ ] 내용 (출처: @security, High) — 파일:줄

## 🟠 권장 사항
- [ ] 내용 (출처: @reviewer, Medium)

## 🔵 참고
- 내용 (출처: @adversarial, Low)
```

작성 완료 후 전체 내용을 사용자에게 출력한다.

## Step 6: 수정 후 선택적 재리뷰

수정 완료 후 `/pr-review` 를 다시 실행하면:

1. `artifacts/review-final.md`에서 미완료 항목(`- [ ]`)과 각 항목의 출처 리뷰어를 읽는다.
2. 해당 항목을 지적한 리뷰어만 재리뷰를 실행한다 (전체 4명 재실행 금지).
3. 재확인 완료된 항목을 `- [x]`로 표시하고 `review-final.md`를 업데이트한다.
4. 미완료 항목이 없으면 "모든 지적 사항 해결됨 — 승인 가능"을 출력한다.
