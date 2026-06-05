# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo is a personal collection of Claude Code agents and skills designed to maximize development productivity. The goal is to automate repetitive tasks, standardize design→implement→debug workflows, and maintain a consistent personal development style.

## Planned Structure

```
.claude/
  agents/        # Subagent definitions for Claude Code
    service-architect   # Service design and architecture
    code-debugger       # Code debugging workflows
    writing-polisher    # Writing and text refinement
  skills/        # Reusable skill files invokable via /skill-name
    api-design
    db-design
    c-debug-checklist
    korean-polishing
```

## Agent Format

Agents live in `.claude/agents/<name>.md`. Each file should include:
- `name`, `description`, and optionally `model`/`tools` in YAML frontmatter
- A system prompt defining the agent's role, behavior, and constraints

## Skill Format

Skills live in `.claude/skills/<name>.md`. Each file should include:
- `name`, `description`, and `type` in YAML frontmatter
- The skill body: instructions, checklists, or workflows Claude follows when the skill is invoked

## Language

Documentation and skill content in this repo is written in Korean where noted in the README (e.g., `korean-polishing`). Agent and skill frontmatter fields should remain in English for compatibility with Claude Code tooling.
