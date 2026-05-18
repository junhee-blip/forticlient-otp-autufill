# FortiClient OTP 자동 클립보드

FortiClient VPN 연결할 때마다 이메일에서 6자리 인증번호 복사해 붙여넣는 거 귀찮아서 만든 도구.

**OTP 메일 도착 → 자동으로 6자리 코드 추출 → 클립보드 복사 + 알림 → ⌘V 한 번이면 끝.**

---

## 사전 준비물

**Gmail 앱 비밀번호** 1개. 발급:

1. https://myaccount.google.com/apppasswords
2. 2단계 인증이 켜져 있어야 메뉴가 보임
3. 앱 이름 아무거나 입력하고 생성 → 16자리 비밀번호 메모

---

## 설치

```bash
git clone https://github.com/junhee-blip/forticlient-otp-autufill.git
cd forticlient-otp-autufill
./install.sh
```

묻는 대로 입력:
- Gmail 주소
- 앱 비밀번호 (입력해도 화면에 안 보임, 정상)

설치 직후 테스트 알림이 뜨면 성공. 안 보이면 시스템 설정 → 알림 → **"FortiClient OTP"** 찾아서 알림 허용 ON.

---

## 사용

1. FortiClient에서 **Connect**
2. 잠시 후 macOS 우상단에 **🔐 716845** 알림 + 클립보드에 자동 복사
3. OTP 입력창 클릭 → **⌘V** → Enter
4. 끝

> 로그인할 때마다 자동 시작됩니다. 컴퓨터 껐다 켜도 알아서 돌아감.

---

## 관리

```bash
# 로그 보기
tail -f /tmp/forticlient-otp.log

# 일시 정지
launchctl unload ~/Library/LaunchAgents/com.user.forticlient-otp.plist

# 다시 시작
launchctl load ~/Library/LaunchAgents/com.user.forticlient-otp.plist

# 완전 제거
./uninstall.sh

# 앱 비밀번호 변경
security add-generic-password -U -s "forticlient-otp-imap" -a "you@company.com" -w "새16자리"
launchctl unload ~/Library/LaunchAgents/com.user.forticlient-otp.plist
launchctl load ~/Library/LaunchAgents/com.user.forticlient-otp.plist
```
