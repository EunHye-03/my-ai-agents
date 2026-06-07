#!/bin/bash
# 새 프로젝트에 Antigravity .agents/ 템플릿을 복사한다
# 사용법: ./scripts/init-antigravity.sh [대상 프로젝트 경로]

TEMPLATE_DIR="$(cd "$(dirname "$0")/.." && pwd)/.agents"
TARGET="${1:-$(pwd)}"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "오류: 템플릿 디렉터리를 찾을 수 없음 ($TEMPLATE_DIR)"
  exit 1
fi

if [ -d "$TARGET/.agents" ]; then
  echo "이미 .agents/ 존재: $TARGET/.agents"
  echo "덮어쓰려면 먼저 삭제하세요."
  exit 1
fi

cp -rL "$TEMPLATE_DIR" "$TARGET/.agents"
mkdir -p "$TARGET/.agents/artifacts"
echo ".agents/artifacts" >> "$TARGET/.gitignore" 2>/dev/null || true

echo "✓ .agents/ 초기화 완료: $TARGET"
echo ""
echo "Antigravity에서 사용 가능한 슬래시 커맨드:"
echo "  /dev-loop <기능명>   — 전체 개발 루프 (스펙 → 구현 → 리뷰 → PR)"
echo "  /pr-review <PR번호>  — PR 리뷰 루프"
