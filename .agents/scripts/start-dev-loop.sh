#!/bin/bash
# 멀티 터미널 에이전트 개발 루프 시작
# 사용법: bash .agents/scripts/start-dev-loop.sh "<기능 설명>"
set -euo pipefail

SESSION="dev-loop"
TASK="${1:-}"
REPO_ROOT="$(pwd)"

if [ -z "$TASK" ]; then
  echo "사용법: bash .agents/scripts/start-dev-loop.sh \"<기능 설명>\""
  exit 1
fi

if ! command -v tmux &>/dev/null; then
  echo "오류: tmux 미설치 — brew install tmux"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "오류: claude CLI 미설치"
  exit 1
fi

# 기존 세션 정리
tmux kill-session -t "$SESSION" 2>/dev/null || true

# 세션 생성
tmux new-session -d -s "$SESSION" -x 220 -y 55 -c "$REPO_ROOT"

# 4분할 레이아웃
# split-h: pane0(좌) | pane1(우)
tmux split-window -h -t "$SESSION:0.0"
# split-v 좌: pane0(좌상) | pane2(좌하) — pane1(우)
tmux split-window -v -t "$SESSION:0.0"
# split-v 우: pane0(좌상) | pane2(좌하) | pane1(우상) | pane3(우하)
tmux split-window -v -t "$SESSION:0.1"

# 각 pane: 프로젝트 루트로 이동
for p in 0 1 2 3; do
  tmux send-keys -t "$SESSION:0.$p" "cd '$REPO_ROOT'" Enter
done

# 역할 표시
tmux send-keys -t "$SESSION:0.0" "clear && printf '\033[34m┌─────────────────┐\n│  🔵  PM          │\n└─────────────────┘\033[0m\n대기 중...\n'" Enter
tmux send-keys -t "$SESSION:0.1" "clear && printf '\033[33m┌─────────────────┐\n│  🟡  Engineer    │\n└─────────────────┘\033[0m\n대기 중...\n'" Enter
tmux send-keys -t "$SESSION:0.2" "clear && printf '\033[32m┌─────────────────┐\n│  🟢  Reviewer    │\n└─────────────────┘\033[0m\n대기 중...\n'" Enter
tmux send-keys -t "$SESSION:0.3" "clear && printf '\033[35m┌─────────────────┐\n│  ⚙️   Orchestrator│\n└─────────────────┘\033[0m\n'" Enter

# orchestrator 실행
tmux send-keys -t "$SESSION:0.3" "bash .agents/scripts/orchestrator.sh '$TASK'" Enter

tmux attach -t "$SESSION"
