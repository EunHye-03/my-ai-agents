# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Reusable collection of Claude Code agents, skills, templates, and workflows.

## Structure

```
.claude/
  agents/          # Subagent definitions for Claude Code
    blog-writer      # PAAR 구조 기술 블로그 → Tistory + GitHub + Obsidian
    weekly-report    # 주간보고서 → 로컬 + Notion
    schedule-briefer # 일간 브리핑 (캘린더, Notion, Gmail, Slack, 외부 공지)
    project-notes    # ADR 및 프로젝트 회고 기록
.agents/
  templates/       # 프로젝트 컨텍스트 템플릿
  workflows/       # 개발 및 리뷰 워크플로
skills/            # 재사용 가능한 skill
config.example.md  # 로컬 private 설정 예시
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
