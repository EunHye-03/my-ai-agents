#!/usr/bin/env bash
# dev-loop 워크플로 단계 전환 사전 조건 검사

# 이전 단계 산출물 존재 여부 확인
# 없으면 오류 메시지를 stderr에 출력하고 return 1
check_prerequisite() {
  local artifact="$1"
  local current_step="$2"
  local required_step="$3"
  if [[ ! -f "$artifact" ]]; then
    echo "❌ 오류: $(basename "$artifact") 이(가) 없습니다." >&2
    echo "   ${current_step}을(를) 실행하려면 ${required_step}을(를) 먼저 완료해야 합니다." >&2
    return 1
  fi
}
