# schedule-briefer 설계 문서

**날짜:** 2026-06-05  
**상태:** 확정

---

## 개요

매일 아침 또는 수동 호출 시, 여러 소스에서 정보를 수집해 하루 브리핑을 생성하는 Claude Code 서브에이전트.

---

## 파일 위치

```
my-ai-agents/.claude/agents/schedule-briefer.md
```

---

## 수집 소스

| 소스 | 방법 | 상세 |
|------|------|------|
| Apple Calendar | `icalBuddy` CLI | 오늘 + 내일 일정 |
| Notion 할 일 | Notion MCP | 페이지 ID `002a894f-a829-83e9-b954-014816e6fa18`, 미완료 항목 |
| Gmail | Gmail MCP | 미읽음·중요 메일 |
| Slack | Slack MCP | 미읽음 메시지 |
| CSE 학과 공지 | WebFetch | `https://cse.knu.ac.kr/index.php` 커뮤니티 섹션 |
| 소프트웨어교육원 공지 | WebFetch | `https://swedu.knu.ac.kr/05_sub/01_sub.html` |
| 경북대 국제처 공지 | WebFetch | `https://international.knu.ac.kr/HOME/global/index.htm` |
| 프로젝트 현황 | 로컬 파일 + Bash | `~/src/repos/` 내 최근 30일 내 커밋 있는 레포만 |
| AI 작업 컨텍스트 | 파일 직접 읽기 | `~/.claude/projects/*/memory/MEMORY.md` |

### 프로젝트 현황 상세

각 레포에서 수집:
- 현재 브랜치 (`git branch --show-current`)
- 최근 커밋 5개 (`git log --oneline -5`)
- 미커밋 변경 여부 (`git status --short`)
- `NOTES.md` 최근 날짜 항목

조건: `git log --since="30 days ago"`로 커밋이 있는 레포만 포함.

---

## 브리핑 포맷

```
🗓️ YYYY-MM-DD (요일) 브리핑

✅ 오늘 할 일
- [ ] 항목 1
- [ ] 항목 2

📅 일정
- HH:MM 일정명
- 내일: 일정명

📬 이메일 (미읽음 N건)
- [중요] 발신자: 제목...

💬 Slack
- #채널명: 내용 요약...

🏫 학교 공지
- [CSE] 공지 제목...
- [SW교육원] 공지 제목...
- [국제처] 공지 제목...

💻 프로젝트 현황
- [레포명] branch: 브랜치명
  최근 커밋: 커밋 메시지 요약
  미커밋 변경: 있음/없음
  NOTES: 최근 항목 요약

🤖 AI 컨텍스트
- 메모리 파일 요약
```

---

## 트리거 & 출력

| 트리거 | 출력 대상 |
|--------|-----------|
| 매일 아침 자동 (`/schedule` 등록) | Slack DM |
| "브리핑해줘" 수동 호출 | 터미널 출력 |

자동/수동 구분: 에이전트 호출 시 args에 `--slack` 포함되면 Slack 전송, 없으면 터미널 출력. `/schedule` 자동 실행 시 `--slack` args 포함.

---

## v2 예약 항목

- **KNU 러닝엑스**: Playwright 자동 로그인으로 과제 마감·공지 수집 (blog-writer Tistory 패턴 참고)
- **학과 Discord**: 봇 추가 가능해지면 Slack MCP 방식과 유사하게 붙이기
