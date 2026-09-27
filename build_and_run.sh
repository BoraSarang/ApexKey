#!/bin/bash
# build_and_run.sh — ApexKey macOS 빌드/테스트 디스패처
# usage:
#   ./build_and_run.sh [debug|release|build] [macos]   빌드 + 설치 (+ debug는 기존 앱 종료 후 재시작)
#   ./build_and_run.sh test [macos] [smoke|unit|full]  테스트 실행 (unit 기본)

set -euo pipefail

MODE="${1:-debug}"
PLATFORM="${2:-macos}"
APP_NAME="ApexKey"
BUNDLE_ID="com.borasarang.ApexKey"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
INSTALL_DIR="${HOME}/Applications"

# ── 색상 ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 플랫폼 체크 ──────────────────────────────────────
if [ "$PLATFORM" != "macos" ]; then
  error "지원되지 않는 플랫폼: $PLATFORM (현재 macOS만 지원)"
fi

# ── 0. 게이트: 현지화 + 버전 단일 출처 ───────────────────
info "0/6a: 현지화 가드 (잔여 한글 리터럴 검사)..."
python3 "$PROJECT_DIR/scripts/check-localizable.py" || error "현지화 가드 실패 — 미로컬라이즈 문자열을 확인하세요"

info "0/6b: 버전 단일 출처 가드 (project.yml)..."
python3 "$PROJECT_DIR/scripts/check-version.py" || error "버전 가드 실패 — project.yml의 MARKETING_VERSION을 확인하세요"

# ── 0. 테스트 서브커맨드 ─────────────────────────────
if [ "$MODE" = "test" ]; then
  TEST_SCOPE="${3:-unit}"
  info "xcodegen으로 프로젝트 생성 중..."
  cd "$PROJECT_DIR"
  xcodegen generate --spec project.yml
  info "xcodebuild test (${TEST_SCOPE}) 실행 중..."
  START_SECS=$SECONDS
  # 스코프별 필터. 이전에는 3개 분기가 완전히 동일해서 매번 전체를 돌렸다 (T-164).
  # 이제 실제 구분이 있다. 예산: smoke <=10s / unit <=60s / full <=5분
  case "$TEST_SCOPE" in
    smoke)
      # 컴파일 + 가장 빠른 실패 표면. 이번 감사에서 추가한 회귀 계열 중심
      TEST_FILTER=(
        -only-testing:ApexKeyTests/ProcessRunnerTests
        -only-testing:ApexKeyTests/AIStubHonestyTests
        -only-testing:ApexKeyTests/ExecutionResultPropagationTests
        -only-testing:ApexKeyTests/ActionCatalogIntegrityTests
        -only-testing:ApexKeyTests/VariableResolverNumberTests
        -only-testing:ApexKeyTests/ShellInjectionGuardTests
        -only-testing:ApexKeyTests/MenuActionPathTests
      )
      BUDGET=30
      ;;
    unit)
      # 기본 피드백 루프 — 전체 스위트
      TEST_FILTER=()
      BUDGET=60
      ;;
    full)
      # 전체 (실기 연동 계열 포함)
      TEST_FILTER=()
      BUDGET=300
      ;;
    *)
      error "알 수 없는 test 스코프: ${TEST_SCOPE} (smoke|unit|full)"
      ;;
  esac
  info "예산 ${BUDGET}초 (초과 시 경고)"

  set +o pipefail
  xcodebuild test -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" \
    -destination 'platform=macOS' -derivedDataPath "${BUILD_DIR}" \
    "${TEST_FILTER[@]}" \
    CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=6GPJQ7BQC9 2>&1 | tail -40
  PIPE_STATUS=${PIPESTATUS[0]}
  set -o pipefail

  ELAPSED=$((SECONDS - START_SECS))
  info "테스트 완료 (${ELAPSED}초 / 예산 ${BUDGET}초)"
  if [ "$ELAPSED" -gt "$BUDGET" ]; then
    warn "예산 초과: ${ELAPSED}초 > ${BUDGET}초"
  fi
  # T-164: xcodebuild 실패가 `| tail`에 삼켜져 exit 0으로 끝나던 문제
  if [ "$PIPE_STATUS" -ne 0 ]; then
    error "테스트 실패 (xcodebuild 종료코드 ${PIPE_STATUS})"
  fi
  exit 0
fi

# ── 1. xcodegen ──────────────────────────────────────
info "1/5: xcodegen으로 프로젝트 생성 중..."
cd "$PROJECT_DIR"
xcodegen generate --spec project.yml

# ── 2. 빌드 ──────────────────────────────────────────
info "2/5: xcodebuild ${MODE} 빌드 중..."
CONFIG="Debug"
if [ "$MODE" = "release" ]; then
  CONFIG="Release"
fi

# 개발팀 자동 서명 — 매 빌드 동일한 코드 identity 유지 (ad-hoc 제거)
# 접근성(TCC) 권한이 리빌드 후에도 유지되도록 TeamID 고정 서명을 사용한다.
CODE_SIGN_FLAGS="CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=6GPJQ7BQC9"
if [ "$MODE" = "release" ]; then
  CODE_SIGN_FLAGS="$CODE_SIGN_FLAGS CODE_SIGN_IDENTITY=Apple Development"
fi

xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration "${CONFIG}" \
  -derivedDataPath "${BUILD_DIR}" \
  ${CODE_SIGN_FLAGS} \
  build 2>&1 | tail -20

APP_PATH="${BUILD_DIR}/Build/Products/${CONFIG}/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
  error "빌드 실패: ${APP_PATH} 없음"
fi
info "빌드 성공: ${APP_PATH}"

# ── 3. ~/Applications에 복사 ────────────────────────
info "3/5: ~/Applications에 설치 중..."
mkdir -p "$INSTALL_DIR"
if [ -e "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi
cp -R "$APP_PATH" "${INSTALL_DIR}/${APP_NAME}.app"
info "설치 완료: ${INSTALL_DIR}/${APP_NAME}.app"

# ── 4. 현지화 검증 ──────────────────────────────────
info "4/5: 현지화 검증 (애펙스키)..."
if [ -e "${INSTALL_DIR}/${APP_NAME}.app/Contents/Resources/ko.lproj/InfoPlist.strings" ]; then
  name=$(mdls -name kMDItemDisplayName "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null | awk -F' = ' '{print $2}')
  info "kMDItemDisplayName = ${name}"
else
  warn "ko.lproj/InfoPlist.strings 미존재 (현지화 미반영 가능)"
fi

echo ""

# ── 5. 기존 앱 종료 + 재시작 (debug 전용) ────────────
if [ "$MODE" = "debug" ]; then
  info "5/5: 기존 앱 종료 후 재시작 중..."
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 1
  open "${INSTALL_DIR}/${APP_NAME}.app"
  sleep 2
  if pgrep -x "$APP_NAME" >/dev/null; then
    info "실행 중 (PID $(pgrep -x "$APP_NAME" | head -1))"
  else
    warn "앱 실행 확인 실패 — 수동으로 열어주세요: ${INSTALL_DIR}/${APP_NAME}.app"
  fi
fi

info "빌드/설치 완료: ${INSTALL_DIR}/${APP_NAME}.app"
