#!/bin/bash
# FortiClient OTP 완전 제거
set -e

INSTALL_DIR="$HOME/forticlient-otp"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.forticlient-otp.plist"
KEYCHAIN_SERVICE="forticlient-otp-imap"

echo "FortiClient OTP 제거 중..."

# launchd 정지 및 plist 삭제
if [ -f "$PLIST_PATH" ]; then
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"
  echo "✓ launchd 등록 해제"
fi

# 키체인에서 비밀번호 삭제 (이메일 모르므로 전체 서비스로 삭제 시도)
while security find-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1; do
  security delete-generic-password -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1 || break
done
echo "✓ 키체인 비밀번호 삭제"

# 설치 디렉토리 삭제 확인
if [ -d "$INSTALL_DIR" ]; then
  read -p "$INSTALL_DIR 삭제할까요? (y/N): " ANS
  if [ "$ANS" = "y" ] || [ "$ANS" = "Y" ]; then
    rm -rf "$INSTALL_DIR"
    echo "✓ 설치 디렉토리 삭제"
  fi
fi

# 로그 삭제
rm -f /tmp/forticlient-otp.log

echo ""
echo "제거 완료"
