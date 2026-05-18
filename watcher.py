#!/usr/bin/env python3
"""FortiClient OTP auto-clipboard watcher.

Polls Gmail IMAP for new FortiClient verification emails that arrive AFTER
the watcher started, extracts the 6-digit code from the subject line, copies
it to the clipboard, and shows a macOS notification. Marks the email as read
after processing. Older mails are ignored.
"""
import imaplib
import email
import re
import subprocess
import sys
import time
from email.header import decode_header

import os

EMAIL_ADDRESS = os.environ.get("FORTICLIENT_OTP_EMAIL", "").strip()
if not EMAIL_ADDRESS:
    import sys as _sys
    _sys.stderr.write(
        "FORTICLIENT_OTP_EMAIL 환경변수가 설정되지 않았습니다. "
        "install.sh로 다시 설치하거나 plist에 환경변수를 추가하세요.\n"
    )
    _sys.exit(1)
KEYCHAIN_SERVICE = "forticlient-otp-imap"
IMAP_HOST = "imap.gmail.com"
IMAP_PORT = 993
POLL_INTERVAL = 3
SENDER_MATCH = "notification.fortinet.net"
SUBJECT_CODE_REGEX = re.compile(r"AuthCode:\s*(\d{6})", re.I)
UIDNEXT_REGEX = re.compile(rb"UIDNEXT (\d+)")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ICON_PATH = os.path.join(SCRIPT_DIR, "assets", "icon.png")
TERMINAL_NOTIFIER = os.path.join(
    SCRIPT_DIR, "FortiClientOTP.app", "Contents", "MacOS", "terminal-notifier"
)


def get_password() -> str:
    result = subprocess.run(
        ["security", "find-generic-password",
         "-s", KEYCHAIN_SERVICE, "-a", EMAIL_ADDRESS, "-w"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        sys.stderr.write(f"키체인 조회 실패: {result.stderr}\n")
        sys.exit(1)
    return result.stdout.strip().replace(" ", "")


def notify(title: str, message: str, subtitle: str = "") -> None:
    if os.path.exists(TERMINAL_NOTIFIER):
        cmd = [
            TERMINAL_NOTIFIER,
            "-title", title,
            "-message", message,
            "-sound", "Glass",
            "-group", "forticlient-otp",
        ]
        if subtitle:
            cmd += ["-subtitle", subtitle]
        subprocess.run(cmd)
    else:
        safe_t = title.replace('"', '\\"')
        safe_m = message.replace('"', '\\"')
        subprocess.run([
            "osascript", "-e",
            f'display notification "{safe_m}" with title "{safe_t}" sound name "Glass"',
        ])


def copy_to_clipboard(text: str) -> None:
    subprocess.run(["pbcopy"], input=text.encode("utf-8"))


def decode_header_str(raw) -> str:
    if not raw:
        return ""
    out = ""
    for part, enc in decode_header(raw):
        if isinstance(part, bytes):
            out += part.decode(enc or "utf-8", errors="replace")
        else:
            out += part
    return out


def get_baseline_uid(M) -> int:
    typ, data = M.status("INBOX", "(UIDNEXT)")
    if typ != "OK" or not data or not data[0]:
        return 1
    m = UIDNEXT_REGEX.search(data[0])
    return int(m.group(1)) if m else 1


def process_inbox(M, baseline_uid: int) -> None:
    last_reconnect = time.time()
    while True:
        # 5분마다 강제 재연결 (Gmail idle disconnect 방지)
        if time.time() - last_reconnect > 300:
            print(f"[{time.strftime('%H:%M:%S')}] 5분 경과, 재연결",
                  flush=True)
            raise ConnectionResetError("forced reconnect")
        # 연결 살아있는지 확인
        try:
            M.noop()
        except Exception:
            raise
        typ, data = M.uid(
            "SEARCH", "UNSEEN",
            "FROM", SENDER_MATCH,
            "UID", f"{baseline_uid}:*",
        )
        if typ != "OK":
            return
        for uid in data[0].split():
            typ, msg_data = M.uid(
                "FETCH", uid, "(BODY.PEEK[HEADER.FIELDS (SUBJECT FROM)])"
            )
            if typ != "OK" or not msg_data or not msg_data[0]:
                continue
            msg = email.message_from_bytes(msg_data[0][1])
            subject = decode_header_str(msg.get("Subject", ""))
            from_addr = decode_header_str(msg.get("From", ""))
            m = SUBJECT_CODE_REGEX.search(subject)
            if not m:
                continue
            code = m.group(1)
            copy_to_clipboard(code)
            notify(
                title=f"🔐 {code}",
                subtitle="FortiClient VPN 인증코드",
                message="클립보드에 복사됨 · ⌘V 로 붙여넣기",
            )
            print(f"[{time.strftime('%H:%M:%S')}] {code} <- {from_addr}",
                  flush=True)
            M.uid("STORE", uid, "+FLAGS", "\\Seen")
        time.sleep(POLL_INTERVAL)


def main() -> None:
    password = get_password()
    while True:
        try:
            with imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT, timeout=30) as M:
                M.login(EMAIL_ADDRESS, password)
                baseline_uid = get_baseline_uid(M)
                M.select("INBOX")
                print(f"[{time.strftime('%H:%M:%S')}] 연결됨: {EMAIL_ADDRESS} "
                      f"(UID >= {baseline_uid} 처리)", flush=True)
                process_inbox(M, baseline_uid)
        except KeyboardInterrupt:
            return
        except Exception as e:
            print(f"[{time.strftime('%H:%M:%S')}] 오류 (5초 후 재연결): {e}",
                  file=sys.stderr, flush=True)
            time.sleep(5)


if __name__ == "__main__":
    main()
