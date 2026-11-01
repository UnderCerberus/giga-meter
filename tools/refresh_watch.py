"""Sideloadlyの自動更新を見張り、止まっていたらWindowsの通知で知らせる。

読むのはinstallations.dbの更新日時とエラーだけ。Apple IDや認証情報には触れない。

    python tools/refresh_watch.py --status      状態を表示する(通知しない)
    python tools/refresh_watch.py --test-toast  通知の表示を試す
    python tools/refresh_watch.py               問題があれば通知する(自動実行用)
"""
import argparse
import os
import re
import sqlite3
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

APP_NAME = "ギガメーター"
WARN_REMAINING_DAYS = 2
SECONDS_PER_DAY = 24 * 60 * 60
DATABASE = os.path.expandvars(r"%LOCALAPPDATA%\Sideloadly\installations.db")
FIX_HINT = "iPhoneをPCにつなぎ、画面をオンにしてSideloadlyを開いてほしい"

TOAST_SCRIPT = r"""
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
$manager = [Windows.UI.Notifications.ToastNotificationManager]
$xml = $manager::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$nodes = $xml.GetElementsByTagName('text')
$nodes.Item(0).AppendChild($xml.CreateTextNode($env:GIGA_TOAST_TITLE)) > $null
$nodes.Item(1).AppendChild($xml.CreateTextNode($env:GIGA_TOAST_BODY)) > $null
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
$manager::CreateToastNotifier($appId).Show($toast)
"""


@dataclass
class Install:
    name: str
    last_updated: datetime
    ttl_days: int
    last_error: str
    failures: int


@dataclass
class Alert:
    title: str
    body: str


def parse_time(text: str) -> datetime:
    # Sideloadlyの小数秒は7桁で、fromisoformatが読めない場合があるため6桁に切る
    return datetime.fromisoformat(re.sub(r"(\.\d{6})\d+", r"\1", text))


def remaining_days(install: Install, now: datetime) -> float:
    age = (now - install.last_updated).total_seconds() / SECONDS_PER_DAY
    return install.ttl_days - age


def evaluate(install: Optional[Install], now: datetime) -> Optional[Alert]:
    if install is None:
        return Alert(f"{APP_NAME}が見つからない", "Sideloadlyの登録を確認してほしい")

    remaining = remaining_days(install, now)
    if remaining <= 0:
        return Alert(f"{APP_NAME}の期限が切れた", FIX_HINT)
    if install.failures > 0 or install.last_error:
        detail = install.last_error or f"{install.failures}回失敗"
        return Alert(f"{APP_NAME}の自動更新に失敗", f"{detail} / {FIX_HINT}")
    if remaining <= WARN_REMAINING_DAYS:
        return Alert(f"{APP_NAME}の自動更新が止まっている", f"あと{int(remaining)}日で切れる。{FIX_HINT}")
    return None


def load_install(path: str = DATABASE, name: str = APP_NAME) -> Optional[Install]:
    connection = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        row = connection.execute(
            "select name, last_updated, known_ttl, last_error, failures_count from installations "
            "where name = ? and deleted_at is null order by last_updated desc limit 1",
            (name,),
        ).fetchone()
    finally:
        connection.close()
    if row is None:
        return None
    return Install(row[0], parse_time(row[1]), row[2], row[3] or "", row[4] or 0)


def show_toast(alert: Alert) -> None:
    subprocess.run(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", TOAST_SCRIPT],
        env={**os.environ, "GIGA_TOAST_TITLE": alert.title, "GIGA_TOAST_BODY": alert.body},
        creationflags=subprocess.CREATE_NO_WINDOW,
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Sideloadlyの自動更新の見張り")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--test-toast", action="store_true")
    args = parser.parse_args()

    if args.test_toast:
        show_toast(Alert(f"{APP_NAME}の見張り", "通知のテスト。この通知が見えれば設定は正常"))
        return 0

    try:
        install = load_install()
    except sqlite3.Error as error:
        show_toast(Alert(f"{APP_NAME}の見張りエラー", f"Sideloadlyの記録を読めない: {error}"))
        return 1

    now = datetime.now().astimezone()
    alert = evaluate(install, now)

    if args.status:
        sys.stdout.reconfigure(encoding="utf-8")
        if install:
            print(f"{install.name}: 最終更新 {install.last_updated:%Y-%m-%d %H:%M}")
            print(f"残り {remaining_days(install, now):.1f}日 / 失敗 {install.failures}回")
        print(f"通知: {alert.title if alert else 'なし'}")
    elif alert:
        show_toast(alert)
    return 0


if __name__ == "__main__":
    sys.exit(main())
