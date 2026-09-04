#!/bin/bash
# build_and_run.sh — ApexKey macOS 빌드/테스트 디스패처
# usage:
#   ./build_and_run.sh [debug|release|build] [macos]   빌드 + 설치
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

# ── 0. 테스트 서브커맨드 ─────────────────────────────
if [ "$MODE" = "test" ]; then
  TEST_SCOPE="${3:-unit}"
  info "xcodegen으로 프로젝트 생성 중..."
  cd "$PROJECT_DIR"
  xcodegen generate --spec project.yml
  info "xcodebuild test (${TEST_SCOPE}) 실행 중... (예산: unit ≤60s / full ≤5분)"
  START_SECS=$SECONDS
  if [ "$TEST_SCOPE" = "full" ]; then
    xcodebuild test -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" \
      -destination 'platform=macOS' -derivedDataPath "${BUILD_DIR}" \
      CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=6GPJQ7BQC9 2>&1 | tail -30
  else
    # smoke/unit: ApexKeyTests 앱 타깃 전체 (macOS 단일 타깃)
    xcodebuild test -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" \
      -destination 'platform=macOS' -derivedDataPath "${BUILD_DIR}" \
      CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=6GPJQ7BQC9 2>&1 | tail -30
  fi
  ELAPSED=$((SECONDS - START_SECS))
  info "테스트 완료 (${ELAPSED}초)"
  exit 0
fi

# ── 1. xcodegen ──────────────────────────────────────
info "1/4: xcodegen으로 프로젝트 생성 중..."
cd "$PROJECT_DIR"
xcodegen generate --spec project.yml

# ── 2. 빌드 ──────────────────────────────────────────
info "2/4: xcodebuild ${MODE} 빌드 중..."
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
info "3/4: ~/Applications에 설치 중..."
mkdir -p "$INSTALL_DIR"
if [ -e "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi
cp -R "$APP_PATH" "${INSTALL_DIR}/${APP_NAME}.app"
info "설치 완료: ${INSTALL_DIR}/${APP_NAME}.app"

# ── 4. 현지화 검증 ──────────────────────────────────
info "4/4: 현지화 검증 (애펙스키)..."
if [ -e "${INSTALL_DIR}/${APP_NAME}.app/Contents/Resources/ko.lproj/InfoPlist.strings" ]; then
  name=$(mdls -name kMDItemDisplayName "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null | awk -F' = ' '{print $2}')
  info "kMDItemDisplayName = ${name}"
else
  warn "ko.lproj/InfoPlist.strings 미존재 (현지화 미반영 가능)"
fi

echo ""
info "빌드/설치 완료: ${INSTALL_DIR}/${APP_NAME}.app"
