#!/bin/bash
# FortiClient OTP auto-clipboard installer.
# - Copies watcher to ~/forticlient-otp/
# - Saves Gmail app password to macOS Keychain
# - Registers as a LaunchAgent (auto-starts at login)
set -e

INSTALL_DIR="$HOME/forticlient-otp"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.forticlient-otp.plist"
KEYCHAIN_SERVICE="forticlient-otp-imap"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "════════════════════════════════════════"
echo "  FortiClient OTP 자동 클립보드 설치"
echo "════════════════════════════════════════"
echo ""

# ── 사전 체크 ─────────────────────────────────
if [ "$(uname)" != "Darwin" ]; then
  echo "❌ macOS 전용입니다."
  exit 1
fi

if ! command -v /usr/bin/python3 >/dev/null 2>&1; then
  echo "❌ Python3가 없습니다. 다음 명령을 먼저 실행하세요:"
  echo "   xcode-select --install"
  exit 1
fi

# ── 이메일 입력 ───────────────────────────────
read -p "Gmail/Workspace 주소 (예: you@company.com): " EMAIL
if [ -z "$EMAIL" ]; then
  echo "❌ 이메일이 비어있습니다."
  exit 1
fi

# ── 앱 비밀번호 입력 ───────────────────────────
echo ""
echo "Gmail 앱 비밀번호 입력 (입력해도 화면에 표시 안 됨):"
echo "  발급: https://myaccount.google.com/apppasswords"
echo "  (2단계 인증 활성화 필요)"
read -s APP_PW
echo ""
APP_PW="${APP_PW// /}"  # 공백 제거
if [ ${#APP_PW} -lt 12 ]; then
  echo "❌ 앱 비밀번호가 너무 짧습니다 (16자리여야 함)."
  exit 1
fi

# ── IMAP 연결 테스트 ──────────────────────────
echo ""
echo "IMAP 연결 테스트 중..."
TEST_OUT=$(/usr/bin/python3 -c '
import imaplib, sys
email_addr = sys.argv[1]
pw = sys.stdin.read().strip()
try:
    M = imaplib.IMAP4_SSL("imap.gmail.com", 993, timeout=15)
    M.login(email_addr, pw)
    M.logout()
    print("OK")
except imaplib.IMAP4.error as e:
    print(f"AUTH_FAIL: {e}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"CONN_FAIL: {e}", file=sys.stderr)
    sys.exit(2)
' "$EMAIL" <<< "$APP_PW" 2>&1) || {
  echo ""
  echo "❌ 연결 실패"
  echo "   $TEST_OUT"
  echo ""
  echo "확인 사항:"
  echo "  1) Gmail 주소가 정확한가요? ($EMAIL)"
  echo "  2) 앱 비밀번호는 https://myaccount.google.com/apppasswords 에서 발급한 16자리인가요?"
  echo "  3) Google 계정 2단계 인증이 켜져 있나요?"
  echo "  4) 회사 IT가 IMAP을 막아놓진 않았나요?"
  exit 1
}
echo "✓ IMAP 연결 OK"

# ── 키체인 저장 ───────────────────────────────
security add-generic-password -U -s "$KEYCHAIN_SERVICE" -a "$EMAIL" -w "$APP_PW"
echo "✓ 키체인에 비밀번호 저장 완료"

# ── 파일 복사 (같은 디렉토리에서 실행하면 스킵) ──
if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
  mkdir -p "$INSTALL_DIR/assets"
  cp -f "$SCRIPT_DIR/watcher.py" "$INSTALL_DIR/"
  cp -f "$SCRIPT_DIR/run.sh" "$INSTALL_DIR/"
  cp -f "$SCRIPT_DIR/assets/icon.png" "$INSTALL_DIR/assets/"
  [ -f "$SCRIPT_DIR/assets/icon.icns" ] && cp -f "$SCRIPT_DIR/assets/icon.icns" "$INSTALL_DIR/assets/"
  if [ -d "$SCRIPT_DIR/FortiClientOTP.app" ]; then
    rm -rf "$INSTALL_DIR/FortiClientOTP.app"
    cp -R "$SCRIPT_DIR/FortiClientOTP.app" "$INSTALL_DIR/"
  fi
  echo "✓ 파일 복사: $INSTALL_DIR"
else
  echo "✓ 이미 설치 위치에서 실행됨 (복사 스킵)"
fi
chmod +x "$INSTALL_DIR/run.sh" "$INSTALL_DIR/watcher.py" 2>/dev/null || true

# ── 알림 앱 Launch Services 등록 ──────────────
if [ -d "$INSTALL_DIR/FortiClientOTP.app" ]; then
  touch "$INSTALL_DIR/FortiClientOTP.app"
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$INSTALL_DIR/FortiClientOTP.app" >/dev/null 2>&1 || true
  echo "✓ 알림 앱 등록 완료"
else
  echo "⚠️  FortiClientOTP.app이 없어 알림은 osascript로 폴백됩니다 (아이콘 없음)"
fi

# ── launchd plist 생성 ────────────────────────
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.forticlient-otp</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>$INSTALL_DIR/run.sh</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>FORTICLIENT_OTP_EMAIL</key>
        <string>$EMAIL</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/forticlient-otp.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/forticlient-otp.log</string>
</dict>
</plist>
EOF
echo "✓ launchd 설정 생성: $PLIST_PATH"

# ── 데몬 시작 ─────────────────────────────────
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "✓ 데몬 시작"

# ── 테스트 알림 ───────────────────────────────
sleep 1
if [ -x "$INSTALL_DIR/FortiClientOTP.app/Contents/MacOS/terminal-notifier" ]; then
  "$INSTALL_DIR/FortiClientOTP.app/Contents/MacOS/terminal-notifier" \
    -title "🔐 설치 완료" \
    -subtitle "FortiClient OTP" \
    -message "VPN 연결 시 코드가 자동 복사됩니다" \
    -sound Glass \
    -group forticlient-otp >/dev/null 2>&1 || true
fi

echo ""
echo "════════════════════════════════════════"
echo "  ✅ 설치 완료"
echo "════════════════════════════════════════"
echo ""
echo "사용법:"
echo "  1) FortiClient VPN 연결 시도"
echo "  2) 3초 내에 macOS 알림 + 클립보드에 OTP 자동 복사"
echo "  3) 입력창에 ⌘V → Enter"
echo ""
echo "⚠️  알림이 안 보이면 시스템 설정 → 알림에서"
echo "    'FortiClient OTP' 찾아서 알림 허용을 켜세요"
echo ""
echo "로그 확인:    tail -f /tmp/forticlient-otp.log"
echo "일시 정지:    launchctl unload $PLIST_PATH"
echo "다시 시작:    launchctl load $PLIST_PATH"
echo "완전 제거:    ./uninstall.sh"
