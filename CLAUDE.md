# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Reusable collection of Claude Code agents, skills, templates, and workflows.

## Structure

```
.claude/
  agents/                # Claude Code 서브에이전트 정의
    blog-writer          # 기술 블로그 작성 → Tistory + GitHub + Obsidian
    weekly-report        # 연구실 주간보고서 → 로컬 + Notion
    schedule-briefer     # 일간 브리핑 (캘린더, Notion, Gmail, Slack, 학교 공지)
    project-notes        # 개발 마일스톤 기록 → ~/Notes/Projects/<ProjectName>/
    pr-writer            # PR 작성 및 생성
    pr-reviewer          # PR 멀티 페르소나 리뷰 + 재리뷰

.agents/                 # Antigravity 멀티에이전트 개발 루프 (init-antigravity.sh로 프로젝트에 복사)
  agents.md              # @pm / @engineer / @reviewer / @qa 페르소나 정의
  workflows/
    dev-loop.md          # /dev-loop 슬래시 커맨드 (스펙 → 구현 → 리뷰 → QA → PR)
    pr-review.md         # /pr-review 진입점 → pr-reviewer 에이전트 위임
  skills/                # ~/.agents/skills/ 심링크 (init 시 실제 파일로 복사)
  templates/             # 신규 프로젝트 init 시 context/로 복사되는 초기 템플릿
    project.yaml
    domain-rules.md
    error-codes.yaml
  artifacts/             # 런타임 산출물 — gitignored

docs/superpowers/
  specs/                 # 기능별 설계 문서 (brainstorming 산출물)
  plans/                 # 기능별 구현 플랜 (writing-plans 산출물)
  pre-mortem/            # pre-mortem 리포트 및 프로세스 로그

scripts/
  init-antigravity.sh    # 신규 프로젝트에 .agents/ 템플릿 초기화

skills/                  # 재사용 가능한 skill
config.example.md        # 로컬 private 설정 예시
```

Personal paths, account identifiers, and service page IDs must remain in a local private configuration outside this repository.

Google agent workflows target Antigravity. The current Antigravity release shares compatible global configuration under `~/.gemini/`, while project-specific workflows live in `.agents/`.

## Agent Format

Agents live in `.claude/agents/<name>.md`. Each file includes:
- `name`, `description`, and optionally `model`/`tools` in YAML frontmatter
- A system prompt defining the agent's role, behavior, and constraints

## Language

Agent content and documentation are written in Korean. Frontmatter fields remain in English for Claude Code compatibility.

## 문서 형식 규칙

구조적 데이터(에러 코드, 기술 스택, 설정값, 코드 목록)는 **YAML**로 작성한다.
설명·규칙·가이드처럼 산문이 필요한 문서는 **Markdown**으로 작성한다.

| YAML로 쓸 것 | Markdown으로 쓸 것 |
|---|---|
| error-codes, project context, config | domain-rules, agents, workflows, ADR |
