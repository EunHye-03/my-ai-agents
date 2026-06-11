# AI Developer Agents

재사용 가능한 AI 개발 에이전트, 스킬, 템플릿, 워크플로 모음.

## 🎯 Purpose

- 반복되는 개발 작업 자동화
- 설계 → 구현 → 디버깅 workflow 정리
- 개인 개발 스타일의 일관성 유지

## 🏗️ Structure

```
.claude/agents/        # Claude Code 서브에이전트
.agents/               # Antigravity 에이전트, 템플릿, 워크플로
skills/                # 재사용 가능한 skill
scripts/               # 설치 및 초기화 스크립트
config.example.md      # private 로컬 설정 예시
```

### Agents

| 에이전트 | 설명 | 트리거 |
|---|---|---|
| `blog-writer` | PAAR 구조 기술 블로그 작성 → Tistory + GitHub + Obsidian | "블로그 써줘" |
| `weekly-report` | 주간보고서 작성 → 로컬 저장 + Notion | "주간보고서 써줘" |
| `schedule-briefer` | 일간 브리핑 (캘린더, Notion, Gmail, Slack, 공지, 프로젝트 현황) | "브리핑해줘" / `--slack`으로 Slack 전송 |

### Skills

각 에이전트가 invoke하는 스킬:

- `korean-polishing` — 솔직하고 담백한 문체 적용 (blog-writer, weekly-report에서 사용)

Third-party skill notices are listed in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Local Configuration

개인 경로, 계정명, 서비스 페이지 ID는 저장소에 커밋하지 않는다. [`config.example.md`](config.example.md)를 참고해 `~/.config/agent-rules/local-values.env` 같은 private 경로에서 관리한다.

## Antigravity

Google 계열 agent 작업은 Antigravity를 기본 대상으로 한다. Antigravity는 현재 `~/.gemini/`의 호환 설정을 사용하므로 전역 규칙은 `~/.gemini/AGENTS.md`에 생성한다.

프로젝트에 Antigravity 개발 루프를 추가하려면:

```bash
./scripts/init-antigravity.sh /path/to/project
```

생성 구조:

```text
.agents/
├── agents.md
├── context/
├── workflows/
└── artifacts/
```

기존 Gemini CLI는 migration 검증 기간의 호환 도구로만 유지한다.
