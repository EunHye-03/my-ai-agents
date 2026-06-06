# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Personal collection of Claude Code agents designed to automate repetitive tasks and maintain a consistent development style.

## Structure

```
.claude/
  agents/          # Subagent definitions for Claude Code
    blog-writer      # PAAR 구조 기술 블로그 → Tistory + GitHub + Obsidian
    weekly-report    # 연구실 주간보고서 → 로컬 + Notion
    schedule-briefer # 일간 브리핑 (캘린더, Notion, Gmail, Slack, 학교 공지)
    project-notes    # 개발 마일스톤 기록 → ~/Notes/Projects/<ProjectName>/
docs/superpowers/
  specs/           # 설계 문서
  plans/           # 구현 플랜
  pre-mortem/      # pre-mortem 리포트 및 프로세스 로그
```

Skills are managed separately in `~/.agents/skills/` (see [my-agents](https://github.com/Je-hye/my-agents)).

## Agent Format

Agents live in `.claude/agents/<name>.md`. Each file includes:
- `name`, `description`, and optionally `model`/`tools` in YAML frontmatter
- A system prompt defining the agent's role, behavior, and constraints

## Language

Agent content and documentation are written in Korean. Frontmatter fields remain in English for Claude Code compatibility.
