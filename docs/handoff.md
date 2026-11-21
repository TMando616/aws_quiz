# ハンドオフ資料：AWS SAP 一問一答アプリ

最終更新: 2026-11-21（Claudeアプリでの相談・初期実装からの引き継ぎ）

## 1. このアプリの目的

- 個人開発で**給料以外の収入を1円でも得る**ことが目標（金額より「自分の作ったもので収益が発生する」体験を重視）
- 収益化は広告（AdMob）を想定。年会費の回収は必須ではない
- 自分の**AWS認定全冠**に向けた勉強と、アプリ開発を一本化する
  - 1つ目の問題セットはSAP（次に受験予定）。今後はDVA、SOAなどの問題セットを追加していく
- 制作の過程はNoteの記事ネタとしても使う想定

## 2. 決定事項と理由

| 項目 | 決定 | 理由 |
|---|---|---|
| フレームワーク | Flutter | iOSとAndroidの両方に出せる（ユーザーの母数が増える）。画面がシンプルなので、iOSらしい作り込みが不要 |
| 最初の試験 | SAP | 次に受験予定の試験なので、問題作りがそのまま勉強になる |
| データの持ち方 | アプリ内のJSON（サーバーなし） | 最初のバージョンを早く出すため。将来API化する場合も、リポジトリ層だけ差し替えればいい構成にしてある |
| 公開の方針 | 作り込みより早く出すことを優先 | 「公開して広告が表示される」までを最初のゴールにする |

## 3. 必ず守るルール

- **問題は必ず自作する**：AWSの本番の試験問題は口外禁止の規約がある。問題集・模試の問題を写すのも著作権的にNG。公式ドキュメントを根拠に作る
- **アプリ名に「AWS」を前面に出さない**：他社の商標を使った名前は審査で止められることがある。「クラウド資格 一問一答」のような名前にし、説明文でAWS認定対策と書く
- **自分で広告をクリックしない**：AdMobの規約違反になる

## 4. 開発環境

- Mac（Apple Silicon）、Xcode 27（iOS 27.2のシミュレーター）
- Flutter SDK：`~/Developer/tools/flutter`（VS Code拡張からインストール）
- プロジェクト：`~/Developer/tools/aws_quiz`
  - ※ 本来は`~/Developer/personal/`に置く予定だった。移動するかは未決定。`personal/aws_qioz`という似た名前のフォルダもあり、こちらが不要かどうかも未確認
- CocoaPods：インストール済み

### シミュレーターの起動（Xcode 27での注意点）

Xcode 27ではSimulatorアプリの名前がDevice Hubに変わっていて、`flutter emulators --launch apple_ios_simulator`では起動できなかった。直接起動する。

```bash
xcrun simctl boot E429B161-CAA4-424E-9197-0732F1CE1036   # iPhone 18 Pro
open -a DeviceHub
flutter run -d E429B161-CAA4-424E-9197-0732F1CE1036
```

- サンプルのカウンターアプリはシミュレーターで起動確認済み
- `pubspec.yaml`やassetsを変更したときは、ホットリロード（`r`）ではなく`flutter run`のやり直しが必要

### import について

このFlutterのバージョンでは、テンプレートが`package:flutter/material.dart`ではなく`package:material_ui/material_ui.dart`をimportしている（`pubspec.yaml`の依存にも`material_ui`がある）。既存のコードに合わせること。

## 5. 現在の実装（初期実装・ビルド確認済み）

**2026-11-21 確認済み：`flutter analyze` 指摘なし、`flutter test` 通過、iOSシミュレーター（iPhone 18 Pro）で起動と1問目の表示を確認。回答・結果画面までのタップ操作は未確認。**

```
assets/questions/sap.json          問題データ（仮の自作3問。うち1問は複数選択）
lib/main.dart                      テーマ設定と、QuizScreen(exam: 'SAP')の起動だけ
lib/models/question.dart           Questionモデル。fromJson、isMultiple、isCorrect(Set<int>)
lib/data/question_repository.dart  rootBundleでassets/questions/<exam>.jsonを読む
lib/screens/quiz_screen.dart       出題 → 選択 → 回答 → 正誤と解説 → 次へ → 結果画面
test/widget_test.dart              起動するかだけのテスト（カウンターのテストから置き換え）
lib/main.dart.orig                 元のテンプレートのバックアップ。不要なら削除してよい
```

### 画面の仕様

- AppBarに「SAP 一問一答（n/全問数）」、その下に進捗バー
- 問題文は長文前提なのでスクロール可能
- 単一選択はラジオ、複数選択はチェックボックスの見た目。複数選択は「（2つ選択）」と表示し、指定数を選ぶまで「回答する」は押せない
- 回答後：正解の選択肢を緑、選んだ不正解を赤で表示し、⭕/❌と解説を出す
- 最後の問題のあとは「n問中 m問 正解」と「もう一度解く」

### 問題データの形式

```json
{
  "exam": "SAP",
  "questions": [
    {
      "id": "sap-001",
      "domain": "公式の試験ガイドの出題分野名",
      "question": "問題文",
      "choices": ["選択肢A", "選択肢B", "選択肢C", "選択肢D"],
      "answers": [1],
      "explanation": "解説"
    }
  ]
}
```

- `answers`は0始まりのインデックスの配列。複数選択なら2つ以上入れる
- `domain`は、後で分野別の正答率を出すために、公式の試験ガイドの分野名をそのまま入れる
- 試験を追加するときは`assets/questions/<試験名の小文字>.json`を置く（例：`dva.json`）

## 6. 次にやること（優先順）

1. ~~**ビルドして動作確認**~~：2026-11-21 起動まで確認済み。回答→解説→結果画面の流れは実機操作で要確認
2. ~~**gitの初期化**~~：2026-11-21 済（`main` ブランチ、リモートは未設定）
3. **SAPの問題を30問程度まで増やす**（本人が作成。目安は最初のバージョンで30問）
4. **AdMobの組み込み**：`google_mobile_ads`。まずはテスト用の広告ユニットIDで、問題の切り替え時や結果画面に表示
5. **App Storeへの公開準備**：Apple Developer Program（年99ドル）、アプリ名、アイコン、プライバシー対応（広告の同意画面）
6. Androidの環境構築とGoogle Playへの公開

### 後で追加したい機能（最初のバージョンには入れない）

- 間違えた問題だけ解き直す
- 試験の選択画面（SAP以外の問題セットの追加）
- 分野別の正答率の記録
- 問題の出題順をシャッフル

## 7. 開発者について

- 本業はLaravel・Next.jsのエンジニア。FlutterとDartは初心者
- 説明は簡潔に、具体例と「なぜそうするか」をセットにしてほしい
- Laravelの概念（リポジトリ層、サービス層など）にたとえると理解しやすい
