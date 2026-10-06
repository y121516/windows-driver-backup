# Windowsドライバのバックアップ・復元

Windows再インストール後に、Windows Updateに頼らずドライバを復元するための小さなツール集です。機種固有のINF番号は固定しません。

## 方針

既定では、登録されたデバイスに割り当てられている追加ドライバを保存します。接続中・切断済みの両方を対象にし、デバイスに割り当てられていない旧版パッケージを減らします。更新前後の厳密な差分抽出ではありません。

漏れを避けることを優先する場合は `All` モードで追加パッケージを一括保存できます。こちらは未使用の旧版も含み得ます。

## ファイル

| ファイル | 役割 |
|-|-|
| `Backup-Drivers.ps1` | 選別・一括バックアップの本体 |
| `Restore-Drivers.ps1` | このツールで作ったバックアップから復元 |
| `backup.cmd` | Windows PowerShellでバックアップ本体を実行 |
| `restore.cmd` | Windows PowerShellで復元本体を実行 |

cmd版は独立した実装ではなくPowerShell版のラッパーです。ps1とcmdを同じディレクトリに置いてください。作業ディレクトリは変更しません。

## 動作環境

- Windows 10 22H2 / Windows 11、Windows PowerShell 5.1。
- 管理者として起動したPowerShellまたはコマンドプロンプトから実行。
- 同じPC・対応するWindowsアーキテクチャへの復元を基本とします。
- この成果物はLinux上で作成しています。実機でのエクスポート・復元は未検証です。

## バックアップ

更新と必要な再起動を済ませ、デバイスの動作を確認してから実行します。バックアップ先は別ドライブ等にも複製し、初期化対象だけに残さないでください。

管理者のコマンドプロンプト：

```bat
backup.cmd
backup.cmd -Destination "E:\PC-Drivers"
backup.cmd -Destination "E:\PC-Drivers-All" -Mode All
```

管理者のPowerShell：

```powershell
.\Backup-Drivers.ps1
.\Backup-Drivers.ps1 -Destination 'E:\PC-Drivers'
.\Backup-Drivers.ps1 -Destination 'E:\PC-Drivers-All' -Mode All
```

既定の保存先は **実行時のカレントディレクトリ\drivers** です。スクリプト所在ディレクトリではありません。PowerShellからcmd版を呼ぶ場合は `.\backup.cmd` を使います。

実行ポリシーでps1を直接実行できない場合はcmd版を使えます。cmd版は起動するPowerShellプロセスにだけ `-ExecutionPolicy Bypass` を指定し、永続設定は変更しません。組織のグループポリシー等による制限は別です。

既存ファイルの混在を防ぐため、空でない保存先には書き込みません。再取得時は別名の保存先を指定してください。途中で失敗したバックアップは `Incomplete` のままとし、復元を拒否します。失敗後の再実行も新しい保存先を使います。

## 保存内容

| パス | 内容 |
|-|-|
| `drivers/packages/oemN/` | Assignedモードで選んだ各パッケージ。内部は元のINF名と必要なファイル |
| `drivers/packages/` | AllモードではPnPUtilが作るパッケージ別サブフォルダー |
| `drivers/devices.txt` | 接続中・切断済みを含むデバイス一覧 |
| `drivers/driver-packages.txt` | ドライバーストアの追加パッケージ一覧 |
| `drivers/backup.json` | 日時・PC名・モード・完了状態。Assignedでは選択INF名も記録 |

Allモードの `ExportedInfNames` は空配列です。パッケージ情報は一覧と実際の出力を参照してください。`Complete` はコマンド成功とINF出力確認を示すだけで、完全性・復元成功の保証ではありません。OSVersionはランタイムの報告値であり、インストールメディアの識別子ではありません。

一覧には機器IDやシリアル等が含まれ得ます。公開する前に確認してください。

## 復元

同じWindowsインストールメディアも別途保存しておくと、再現条件をそろえられます。復元元は `packages` ではなく `backup.json` のあるフォルダーを指定します。

```bat
restore.cmd
restore.cmd -Source "E:\PC-Drivers"
```

```powershell
.\Restore-Drivers.ps1 -Source 'E:\PC-Drivers'
```

内部では `pnputil /add-driver ... /subdirs /install` を実行します。適合するデバイスに適用し、優先順位の低いドライバへの強制置換はしません。自動再起動は行いません。必要なら手動で再起動してください。終了コード3010は再起動要求として返します。

復元後：

```bat
pnputil /enum-devices /problem
```

該当なしでも全機能の動作保証ではありません。音声、通信、タッチパッド、外部映像・音声出力など、必要な機能を実際に確認します。ネット未接続で復元を試すことが、Windows Updateに依存しない復元セットの確認になります。

既存の手作業バックアップには `backup.json` がないため、この復元スクリプトは使えません。その場合は正しい保存先を確認してPnPUtilを直接使ってください。

## 問題と対策・限界

| 問題・誤解 | 対策・判断 |
|-|-|
| 不明なデバイスだけ保存すればよい | 認識済みの機器も更新されるため、割り当て済み追加ドライバ全体を対象にする |
| 切断済みは不要 | HDMI音声等もあるため、切断済みを除外しない |
| Win32_PnPSignedDriverで全件取得できる | 切断済みが漏れた例があるため、このツールはPnPUtilの一覧を使う |
| oemNの番号で用途・更新順を判断 | Windows内の登録名にすぎない。再インストール後も同じとは限らない |
| 個別エクスポートを同じ保存先に繰り返す | 同名ファイル衝突を避けるため、パッケージごとに保存先を分ける |
| AssignedならどんなPCでも完全 | デバイスに直接割り当てられない拡張・関連パッケージは漏れ得る。必要ならAllを選ぶ |
| Assignedなら不要物はゼロ | 過去の外部機器や古いデバイス登録に割り当てられたパッケージも残り得る |
| Windows標準ドライバも保存される | 対象は追加パッケージ。OSの標準部分はインストールメディア等に依存する |
| アプリや設定も戻る | ドライバーパッケージだけ。別配布の制御アプリ・設定等は別途保全する |
| 更新されたファイルだけ保存される | パッケージ単位で保存する。バイナリ差分ではない |
| 保存のため未使用ドライバを削除すべき | このツールは削除しない。バックアップの選別だけで対応する |

Assignedは `pnputil /enum-devices` のテキストから、コロンの後に `oemN.inf` がある行を抽出します。項目名の日本語・英語には依存しませんが、出力形式の将来変更には対応が必要です。対象ゼロなら停止し、部分的な取りこぼしまでは自動検出できません。

## 将来の自分・AI向けの保守方針

- 機種名や特定のOEM番号をコードへ埋め込まない。
- 接続済みだけに絞らない。CIM列挙へ戻す場合は切断済みの取得を検証する。
- 個別エクスポートの保存先分離、既存出力の混在防止、終了コード確認を維持する。
- ドライバ削除・強制置換・自動再起動を追加しない。
- 容量最小化より漏れ防止が重要な環境ではAllを使う。
- 導入日時の調査には `%SystemRoot%\INF\setupapi.dev.log` を使う。ドライバの「日付」はPCへの導入日時ではない。
- OSのセキュリティ更新やライセンス認証の保全は、このツールの対象外。

## 参照

|  |  |
|-|-|
| [PnPUtil コマンド構文](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax) | `https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax` |
| [SetupAPI デバイスインストールログ](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/setupapi-device-installation-log-entries) | `https://learn.microsoft.com/en-us/windows-hardware/drivers/install/setupapi-device-installation-log-entries` |
