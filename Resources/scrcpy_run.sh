#!/bin/bash
export PATH="$PATH:/opt/homebrew/bin"
# 옵션은 배열로 써야 -s 파싱 안 꼬임
# --screen-off-timeout: 미러링 중에만 꺼짐 시간 연장(종료 시 원복), --turn-screen-off: 폰 패널만 끄고 미러링 유지
# 꺼진 화면 깨우기: 맥 창에서 우클릭 / Cmd+Shift+O
SCRCPY_OPTS=(--show-touches --stay-awake --legacy-paste --max-size=1024 --video-bit-rate=2M --max-fps=30 --screen-off-timeout=3600 --turn-screen-off)
#SCRCPY_OPTS=(--show-touches --stay-awake --legacy-paste --max-size=1024 --screen-off-timeout=3600 --turn-screen-off)

adb_list() { adb devices | tr -d '\r'; }

# 무선 연결 시도: 결과 메시지는 OUT에 저장, 성공이면 0 반환
connect_wireless() {
  OUT=$(adb connect "$1:5555" 2>&1)
  echo "adb: $OUT"
  echo "$OUT" | grep -qE "^(already )?connected to"
}

# 기기 테스트 - 3번 재시도
test_device() {
  local dev=$1
  for i in 1 2 3; do
    state=$(adb -s "$dev" get-state 2>&1 | tr -d '\r')
    if [ "$state" = "device" ]; then
      if adb -s "$dev" shell echo ok > /dev/null 2>&1; then
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

# 핫스팟 환경: 맥 입장에서 폰 주소 = 기본 게이트웨이
GW=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}' | tr -d '\r' | head -n1)
[ -n "$GW" ] && echo "게이트웨이(폰): $GW"

USB_DEV=$(adb_list | awk '$2=="device" && $1 !~ /:/ {print $1}' | head -1)

IP=""
if [ -n "$USB_DEV" ]; then
  # ---------- USB 연결됨: tcpip 5555 (재부팅 후 1회용) ----------
  echo "[USB] $USB_DEV 발견"

  # 1순위: 게이트웨이 (맥에서 실제로 닿는 주소)
  IP="$GW"

  # 게이트웨이를 못 구했을 때만 폰 내부에서 IP 조회 (핫스팟 중엔 안 닿을 수 있음)
  if [ -z "$IP" ]; then
    IP=$(adb -s "$USB_DEV" shell ip route get 1.1.1.1 2>/dev/null | grep -o 'src [0-9.]*' | awk '{print $2}' | tr -d '\r' | head -n1)
  fi
  if [ -z "$IP" ]; then
    IP=$(adb -s "$USB_DEV" shell ip -f inet addr show wlan0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | tr -d '\r' | head -n1)
  fi

  if [ -z "$IP" ]; then
    echo "IP를 찾지 못했습니다. -> USB로만 진행"
  else
    echo "기기 IP: $IP"
    # macOS ping의 -W 단위는 밀리초 (2가 아니라 2000)
    if ! ping -c 1 -W 2000 "$IP" > /dev/null 2>&1; then
      echo "⚠️  PC에서 $IP ping 실패 -> USB로만 진행"
      IP=""
    else
      echo "restarting in TCP mode port: 5555"
      adb -s "$USB_DEV" tcpip 5555
      echo "adbd 재시작 대기 4초..."
      sleep 4
      adb disconnect "$IP:5555" > /dev/null 2>&1 || true
      if adb connect "$IP:5555"; then
        echo "무선 연결 성공: $IP:5555"
        sleep 2
      else
        echo "무선 연결 실패"
        IP=""
      fi
    fi
  fi
else
  # ---------- USB 없음: 이미 열려 있는 5555로 바로 연결 ----------
  if [ -n "$GW" ]; then
    echo "[USB 없음] $GW:5555 로 연결 시도"
    if connect_wireless "$GW"; then
      echo "무선 연결 성공: $GW:5555"
      sleep 1
    else
      # No route to host = adb 서버가 로컬 네트워크에 못 나가는 상태로 떠 있는 경우 -> 서버 재시작 후 1회 재시도
      if echo "$OUT" | grep -q "No route to host"; then
        echo "adb 서버 재시작 후 재시도..."
        adb kill-server > /dev/null 2>&1
        sleep 1
        adb start-server > /dev/null 2>&1
        if connect_wireless "$GW"; then
          echo "무선 연결 성공(재시도): $GW:5555"
          sleep 1
        else
          echo "⚠️  재시도도 실패. 터미널/실행 앱의 로컬 네트워크 권한을 확인하세요."
        fi
      else
        echo "⚠️  $GW:5555 연결 실패 (폰 재부팅 후라면 USB로 한 번 연결 필요)"
      fi
    fi
  else
    echo "[USB 없음] 게이트웨이를 찾지 못했습니다. (핫스팟에 연결돼 있나요?)"
  fi
fi

# 현재 살아있는 기기 목록 다시 읽기
DEVICES=$(adb_list | grep -v "List" | awk '$2=="device" {print $1}')
echo "현재 devices: $DEVICES"

SELECTED=""
TCP_DEV=$(echo "$DEVICES" | grep ":5555" | head -1 | tr -d '\r' | xargs)

# 1순위: TCP 기기
if [ -n "$TCP_DEV" ]; then
  echo -n "테스트 $TCP_DEV ... "
  if test_device "$TCP_DEV"; then
    echo "OK"
    SELECTED="$TCP_DEV"
  else
    echo "FAIL (adbd 아직 준비중일 수 있음)"
    # 실패해도 바로 disconnect 하지 않음 - 재시도 여지 둠
  fi
fi

# 2순위: USB 기기 (TCP 실패했을 때만)
if [ -z "$SELECTED" ] && [ -n "$USB_DEV" ]; then
  # USB가 목록에 다시 나타났는지 확인 (tcpip 후엔 잠깐 사라짐)
  sleep 1
  DEVICES=$(adb_list | grep -v "List" | awk '$2=="device" {print $1}')
  if echo "$DEVICES" | grep -q "$USB_DEV"; then
    echo -n "테스트 $USB_DEV ... "
    if test_device "$USB_DEV"; then
      echo "OK"
      SELECTED="$USB_DEV"
      # TCP 중복이면 정리
      if [ -n "$TCP_DEV" ] && [ "$TCP_DEV" != "$SELECTED" ]; then
        echo "중복 연결 정리: $TCP_DEV disconnect"
        adb disconnect "$TCP_DEV" > /dev/null 2>&1 || true
      fi
    else
      echo "FAIL"
    fi
  fi
fi

# 3순위: 그 외 아무 기기
if [ -z "$SELECTED" ]; then
  for d in $DEVICES; do
    d=$(echo "$d" | tr -d '\r' | xargs)
    [ -z "$d" ] && continue
    if [ "$d" = "$TCP_DEV" ] || [ "$d" = "$USB_DEV" ]; then continue; fi
    echo -n "테스트 $d ... "
    if test_device "$d"; then
      echo "OK"
      SELECTED="$d"
      break
    else
      echo "FAIL"
    fi
  done
fi

if [ -z "$SELECTED" ]; then
  echo "사용 가능한 기기가 없습니다."
  echo "adb devices -l 결과:"
  adb devices -l
  exit 1
fi

echo "실행 기기: $SELECTED"
echo "실행 명령: scrcpy -s $SELECTED ${SCRCPY_OPTS[*]}"

# nohup 말고 직접 실행 - 에러 바로 보이게
#scrcpy -s "$SELECTED" "${SCRCPY_OPTS[@]}"
nohup scrcpy -s "$SELECTED" "${SCRCPY_OPTS[@]}" > /dev/null 2>&1 &
disown
echo "scrcpy 실행됨"
