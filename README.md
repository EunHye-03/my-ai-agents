# 🧠 Personal AI Developer Agents

Claude 기반 개인 맞춤형 에이전트 & 스킬 모음 레포지토리

## 🎯 Purpose

- 반복되는 개발 작업 자동화
- 설계 → 구현 → 디버깅 workflow 정리
- 개인 개발 스타일의 일관성 유지

## 🏗️ Structure

```
.claude/agents/        # Claude Code 서브에이전트
docs/superpowers/      # 설계 문서, 플랜, pre-mortem
```

### Agents

| 에이전트 | 설명 | 트리거 |
|---|---|---|
| `blog-writer` | PAAR 구조 기술 블로그 작성 → Tistory + GitHub + Obsidian | "블로그 써줘" |
| `weekly-report` | 연구실 주간보고서 작성 → 로컬 저장 + Notion | "주간보고서 써줘" |
| `schedule-briefer` | 일간 브리핑 (캘린더, Notion, Gmail, Slack, 학교 공지, 프로젝트 현황) | "브리핑해줘" / `--slack`으로 Slack 전송 |

### Skills

개인 스킬은 `~/.agents/skills/`에서 관리. 각 에이전트가 invoke하는 스킬:

- `korean-polishing` — 솔직하고 담백한 문체 적용 (blog-writer, weekly-report에서 사용)
