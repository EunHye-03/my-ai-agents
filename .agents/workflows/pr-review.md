---
description: PR 리뷰 진입점 — pr-reviewer 서브에이전트에 위임한다
---

When the user types `/pr-review <PR번호 또는 브랜치명> [--type <타입>]`, execute the following:

`pr-reviewer` 서브에이전트를 호출한다.
리뷰 로직 전체는 `.claude/agents/pr-reviewer.md`에 정의되어 있다.

args를 그대로 전달한다:
- PR 번호가 있으면 → 리뷰 모드
- "재리뷰" 또는 미완료 항목이 있으면 → 재리뷰 모드
