#!/bin/bash
# "어른의 수학" 앱을 연결된 기기/시뮬레이터에서 실행한다.
#
# 이 앱은 백엔드가 없는 로컬 전용 앱이라 서버 주입은 없다.
# 이 PC 의 LAN IP 는 참고용으로만 출력한다(추후 백엔드가 생기면 여기에 주입).
#
# 사용법:
#   ./run_app.sh                 # 연결된 기기/시뮬레이터 자동 선택
#   ./run_app.sh -d <device_id>  # 특정 기기 지정 (flutter run 인자 그대로 전달)
#   ./run_app.sh -d chrome       # 크롬(웹)으로 실행
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"

# --- LAN IP 감지: 기본 라우트 인터페이스 → en0/en1 폴백 ---
detect_ip() {
  local iface ip
  iface=$(route -n get default 2>/dev/null | awk '/interface: / {print $2}') || true
  if [ -n "${iface:-}" ]; then
    ip=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
    [ -n "$ip" ] && { echo "$ip"; return 0; }
  fi
  for candidate in en0 en1 en2 en3; do
    ip=$(ipconfig getifaddr "$candidate" 2>/dev/null || true)
    [ -n "$ip" ] && { echo "$ip"; return 0; }
  done
  return 1
}

IP=$(detect_ip || echo "감지 실패")
echo "▶ 이 PC LAN IP: $IP  (실기기는 같은 Wi-Fi 에 연결되어 있어야 합니다)"
echo "▶ flutter run ${*:-(연결된 기기 자동 선택)}"

cd "$ROOT"
exec flutter run "$@"
