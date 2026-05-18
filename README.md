# FortiClient OTP 자동 클립보드 (macOS)

FortiClient VPN 연결할 때마다 이메일 들어가서 6자리 인증번호 복사하는 거 귀찮아서 만든 도구.

**메일 도착 → 3초 내 macOS 알림 + 클립보드 자동 복사 → ⌘V 한 번이면 끝.**

---

## 동작 방식

1. 백그라운드에서 Gmail/Google Workspace IMAP을 3초마다 폴링
2. `DoNotReply@notification.fortinet.net` 발신 + `AuthCode: 123456` 형태 제목 감지
3. 6자리 코드 추출 → 클립보드 복사 → macOS 알림 (FortiClient 방패 아이콘)
4. 이메일은 자동으로 읽음 처리

부팅 시 자동 시작 (LaunchAgent).

---

## 사전 준비물

받는 사람이 깔아야 할 것:

| 항목 | 확인 방법 |
|---|---|
| **macOS** | 기본 |
| **Python 3** | `python3 --version` (없으면 `xcode-select --install`) |
| **Gmail 앱 비밀번호** | https://myaccount.google.com/apppasswords (2단계 인증 필요) |

> Homebrew, terminal-notifier 등 외부 도구는 필요 없음. 패키지에 다 포함됨.

---

## 설치

1. 압축 풀기
2. 터미널에서:
   ```bash
   cd forticlient-otp
   ./install.sh
   ```
3. 묻는 대로 입력:
   - Gmail 주소
   - 앱 비밀번호 (입력해도 화면에 안 보임, 정상)
4. 끝.

설치 직후 **테스트 알림**이 뜨면 성공. 안 뜨면 ↓

### 알림이 안 보일 때

처음 한 번은 macOS 알림 권한을 직접 켜야 합니다:

1. 시스템 설정 → 알림
2. 좌측에서 **"FortiClient OTP"** 찾기
3. **알림 허용** ON, 스타일 "배너" 또는 "알림"

권한 켠 뒤 데몬 재시작:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.forticlient-otp.plist
launchctl load ~/Library/LaunchAgents/com.user.forticlient-otp.plist
```

---

## 사용

1. FortiClient에서 **Connect** 클릭
2. OTP 입력창이 뜨면 잠시 후 macOS 우상단에 **🔐 716845** 알림
3. 입력창 클릭 → **⌘V** → Enter
4. 끝

> 알림 못 봐도 클립보드엔 이미 복사돼 있어요.

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
```

### 앱 비밀번호 변경

```bash
security add-generic-password -U \
  -s "forticlient-otp-imap" \
  -a "you@company.com" \
  -w "새16자리"
launchctl unload ~/Library/LaunchAgents/com.user.forticlient-otp.plist
launchctl load ~/Library/LaunchAgents/com.user.forticlient-otp.plist
```

---

## 파일 구조 (설치 후)

```
~/forticlient-otp/
├── watcher.py                  # 메인 Python 스크립트
├── run.sh                      # 실행 래퍼
├── FortiClientOTP.app/         # 알림 발신용 앱 (방패 아이콘)
└── assets/
    ├── icon.png
    └── icon.icns

~/Library/LaunchAgents/
└── com.user.forticlient-otp.plist   # 자동 시작 설정

macOS Keychain:
└── forticlient-otp-imap              # Gmail 앱 비밀번호 (안전 보관)
```

---

## 보안

- 앱 비밀번호는 **macOS Keychain**에 저장됩니다 (평문 파일 X)
- 스크립트는 외부로 데이터를 보내지 않음 (Gmail IMAP만 접속)
- 받은 OTP는 메모리/클립보드에만 잠시 있다가 사라짐
- 앱 비밀번호는 Gmail 외의 어떤 권한도 없음 (메일 읽기 전용)

---

## 발신자/제목 형식이 다른 경우

회사에 따라 OTP 메일 형식이 다를 수 있어요. `watcher.py` 상단에서 조정:

```python
SENDER_MATCH = "notification.fortinet.net"           # 발신자 (포함 문자열)
SUBJECT_CODE_REGEX = re.compile(r"AuthCode:\s*(\d{6})", re.I)  # 제목 정규식
```

---

## 한계

- macOS 전용 (Keychain, launchd, AppleScript 의존)
- Gmail / Google Workspace 만 (IMAP 호스트 하드코딩, 다른 메일 서버 쓰려면 `IMAP_HOST` 수정)
- IT가 IMAP 차단해놓은 회사면 동작 X
