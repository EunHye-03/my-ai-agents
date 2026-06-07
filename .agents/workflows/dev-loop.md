---
description: 기능 개발 전체 루프 — 스펙 정의부터 PR까지 에이전트가 자동으로 이어받는다
---

When the user types `/dev-loop <feature>`, execute the following pipeline:

## Step 1: 스펙 정의 (@pm + spec-writing skill)

@pm이 `<feature>`를 받아 `spec-writing` 스킬로 `artifacts/issue.md`를 작성한다.
완료 후 사용자에게 `artifacts/issue.md`를 보여주고 승인을 요청한다.
승인 전까지 Step 2로 진행하지 않는다.

## Step 2: 구현 (@engineer + tdd-implement skill)

사용자가 승인하면 @engineer가 `artifacts/issue.md`를 읽고 테스트 모드를 선언한 뒤 구현을 시작한다.

- 요구사항 확정 → TDD (수용 기준 하나씩 커밋)
- 설계 탐색 중 → Test-after (구현 완료 후 테스트 추가, PR 전 필수)
- 1회성 코드 → No-test (커밋 메시지에 이유 명시)

모든 기준 완료 시 구현 결과 요약을 출력하고 Step 3으로 이동한다.

## Step 3: 리뷰 (@reviewer + code-review skill)

@reviewer가 `code-review` 스킬을 실행한다.
`artifacts/review.md`에 결과 저장.

- ✅ 승인 → Step 4로 이동
- ❌ 반려 → @engineer에게 피드백 전달, Step 2로 복귀 (해당 항목만 재처리)

## Step 4: QA 검증 (@qa)

@qa가 `artifacts/issue.md`의 엣지 케이스와 에러 시나리오를 기반으로 테스트한다.
결과를 `artifacts/test-plan.md`에 저장.

- 이슈 발견 → @engineer에게 위임 후 Step 3부터 재시작
- 통과 → Step 5로 이동

## Step 5: PR 생성

구현 브랜치에서 main으로 PR을 생성한다.
PR 설명에 `artifacts/issue.md` 수용 기준과 `artifacts/review.md` 리뷰 결과를 포함한다.
PR URL을 사용자에게 출력하고 파이프라인을 종료한다.
