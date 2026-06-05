# 🧠 Personal AI Developer Agents

나만의 개발 생산성을 극대화하기 위한  
**Claude 기반 개인 맞춤형 에이전트 & 스킬 모음 레포지토리**


## 🎯 Purpose

이 레포는 다음을 목표로 합니다:

- 반복되는 개발 작업 자동화
- 설계 → 구현 → 디버깅 workflow 정리
- 개인 개발 스타일의 일관성 유지
- AI를 활용한 생산성 극대화


## 🏗️ Structure

- `.claude/agents/`
  - **schedule-briefer**: 일간 브리핑 (캘린더, Notion 할 일, Gmail, Slack, 학교 공지, 프로젝트 현황, AI 컨텍스트)
    - 호출: "브리핑해줘" 또는 `/schedule-briefer`
    - Slack 전송: `--slack` 인자 추가
  - service-architect: 서비스 설계
  - code-debugger: 코드 디버깅
  - writing-polisher: 글쓰기/퇴고

- `.claude/skills/`
  - api-design
  - db-design
  - c-debug-checklist
  - korean-polishing