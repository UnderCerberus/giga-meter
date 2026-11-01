# ギガメーター インストールと検証手順

## インストール

1. iPhoneをUSBでPCにつなぎ、Sideloadlyを起動する
2. Sideloadlyに`artifacts/GigaMeter.ipa`を入れる
3. Apple IDを自分で入力して「Start」を押す
4. iPhoneの「設定 → 一般 → VPNとデバイス管理」で開発元を信頼する

無料Apple IDの署名は7日で切れる。切れたら同じ手順で入れ直す。記録は残る。

## 7日ごとの自動更新

Sideloadlyの常駐プログラム(`sideloadlydaemon.exe`)が、PCからiPhoneが見えるときに署名を更新する。

1. iPhoneをUSBでつなぎ、iTunesを開く
2. iPhoneのアイコン →「概要」→「オプション」→「Wi-Fi経由でこのiPhoneと同期」をオンにする
3. 「同期」→「完了」を押す

見張りツールが毎日12時とログオン時に動き、更新が止まっていたらWindowsの通知で知らせる。

- 状態の確認: `python tools/refresh_watch.py --status`
- 登録: `tools/install_refresh_watch.ps1`
- 解除: `Unregister-ScheduledTask -TaskName GigaMeterRefreshWatch -Confirm:$false`

## 残りの確認

右上のアイコンから診断画面を開き、各確認の前後でメモを付けて「今すぐ記録」を押す。

| # | 手順 | 見る点 |
|---|---|---|
| 1 | モバイル通信で約200MB通信する | `pdp_ip`が増えるか。設定アプリの増加量と近いか |
| 2 | Wi-Fiで4.3GB以上通信する。OSや大きなアプリの更新を使ってよい | `en0`の32ビット値が0付近に戻るか。64ビット値は増え続けるか |
| 3 | 機内モードをオン、オフする | カウンタが減らないか。今月の使用量が急に増えないか |
| 4 | Wi-Fiとモバイル通信を切り替える | カウンタが減らないか |
| 5 | iPhoneを再起動する | 今月の使用量が減らないか。「未計測あり」が出るか |
| 6 | アプリを閉じて3日間普段どおり使う | `background`の記録がどの程度の頻度で増えるか |

## 結果の共有

診断画面の「CSVを共有」でCSVをPCへ送り、`probe-data/`に置く。
