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

# 심링크를 실제 파일로 복사 (-L: dereference symlinks)
cp -rL "$TEMPLATE_DIR" "$TARGET/.agents"

# templates/ → context/ 로 복사 (프로젝트별 컨텍스트 파일, md + yaml 모두)
mkdir -p "$TARGET/.agents/context"
cp "$TEMPLATE_DIR/templates/"* "$TARGET/.agents/context/"

# artifacts/ 초기화
mkdir -p "$TARGET/.agents/artifacts"

# .gitignore 처리
if [ -f "$TARGET/.gitignore" ]; then
  grep -qxF ".agents/artifacts" "$TARGET/.gitignore" || echo ".agents/artifacts" >> "$TARGET/.gitignore"
else
  echo ".agents/artifacts" > "$TARGET/.gitignore"
fi

echo "✓ .agents/ 초기화 완료: $TARGET"
echo ""
echo "다음 단계:"
echo "  1. $TARGET/.agents/context/project.yaml 를 채우세요 (프로젝트 개요, 기술 스택)"
echo "  2. $TARGET/.agents/context/domain-rules.md 를 채우세요 (도메인 용어, 비즈니스 규칙)"
echo "  3. $TARGET/.agents/context/error-codes.yaml 를 채우세요 (에러 코드 목록)"
echo ""
echo "Antigravity에서 사용 가능한 슬래시 커맨드:"
echo "  /dev-loop <기능명>   — 전체 개발 루프 (사전 위험 검토 → 스펙 → 구현 → 리뷰 → QA → PR)"
echo "  /pr-review <PR번호>  — PR 리뷰 루프"
