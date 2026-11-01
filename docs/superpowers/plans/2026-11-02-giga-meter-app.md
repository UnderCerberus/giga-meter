# ギガメーター 本体 実装計画

> 同じセッションで続けて実装する。コードの全文はリポジトリを正とし、ここには構成、公開インターフェース、テスト項目を記載する。

**Goal:** 今月の使用量と月末予測を、デザインAとアニメーションで見られる本番アプリを作る。

**Architecture:** 集計は`GigaCore`、カウンタ読み取りは`ProbeKit`。どちらもSwift Package `GigaKit`に置き、macOSのCIで自動テストする。SwiftUIの画面は`UsageSnapshot`を表示するだけにする。

**Tech Stack:** Swift、SwiftUI(iOS 17)、BackgroundTasks、XCTest、XcodeGen、GitHub Actions

**Spec:** `docs/superpowers/specs/2026-11-01-giga-meter-design.md`

## Global Constraints

- 対応OS: iOS 17以降。外部ライブラリなし、外部通信なし
- 1GB = 1,000,000,000バイト
- 計測対象: `pdp_ip`で始まるインターフェース
- 配色: 背景#0B0D10、カード#171A1F、アクセント#C6F432、文字#F3F5F7、補助文字#8B9098、未使用部#23272E

### Task 1: `GigaCore`の集計

**Files:** `GigaKit/Sources/GigaCore/{CounterDelta,Ledger,UsageSnapshot,LedgerStore,GBFormat}.swift`、`GigaKit/Tests/GigaCoreTests/*`

**Interfaces:**
- `Ledger.apply(counters:bootTime:now:calendar:)`
- `Ledger.setCarrierValue(bytes:)`
- `Ledger.snapshot(now:calendar:) -> UsageSnapshot`
- `GaugeScale(total:forecast:lastMonth:)`
- `LedgerStore(fileURL:)`、`.load() -> (ledger: Ledger, wasReset: Bool)`、`.save(_:) throws`
- `GBFormat.string(bytes:) -> String`、`GBFormat.bytes(from: String) -> Double?`

**テスト項目:** 通常の増分、再起動で合計が減らず未計測ありが立つ、64ビット周回、64ビット矛盾時の32ビット採用、32ビット周回と個別リセット、消えた回線の再出現で二重計上しない、日またぎと月またぎの按分、複数月の空白、時計の巻き戻し、2月の日数、初回の実測と推定、キャリア値の補正と再入力と翌月リセット、月末予測と24時間未満の非表示、メーターの目盛り、壊れたファイルの退避、数字の表示と入力の解釈

### Task 2: `ProbeKit`の整理

`ProbeStore`をDocuments専用にし、5MB超で消す処理を追加する。テストを更新する。

### Task 3: 画面とアニメーション

**Files:** `GigaMeter/{GigaMeterApp,MeterModel,Theme,MainView,GaugeView,StatCards,DailyBars,CarrierSheet,DiagnosticsView,DemoData}.swift`、`GigaMeter/Assets.xcassets`、`tools/make_icon.py`、`project.yml`

デモ表示はDebugビルドの`-demo`起動引数でのみ有効にする。

### Task 4: CIと画面確認

- `ci.yml`: `GigaKit`のテスト、ReleaseのIPA作成
- `ui-preview.yml`: 手動実行。シミュレータでデモ表示を動かし、スクリーンショットと動画を成果物にする

合格条件: テストとビルドの成功、スクリーンショットでレイアウト崩れが無いこと、動画でアニメーションが動くこと。

### Task 5: 実機確認

ユーザーがIPAを入れ、実際の値が表示されること、残りの検証項目(4GB周回、機内モード、再起動)を確認する。
