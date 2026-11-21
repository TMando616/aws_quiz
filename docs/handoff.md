# ハンドオフ資料：AWS認定の学習アプリ（アプリ名は未決。仮称「クラウド認定」）

最終更新: 2026-11-21（SAP専用の一問一答アプリから、全試験対応の学習アプリに方向転換。同日、App Store の競合調査を反映。詳細は `docs/market-research.md`）

## 1. このアプリの目的

- 個人開発で**給料以外の収入を1円でも得る**ことが目標（金額より「自分の作ったもので収益が発生する」体験を重視）
- 収益化は広告（AdMob）を想定。年会費の回収は必須ではない
- **AWS認定の全試験に対応し、全冠取得を目指せる学習アプリ**にする。自分の全冠に向けた勉強と、アプリ開発を一本化する
  - 問題を最初に入れるのはSAP（次に受験予定）。試験を追加するときは、問題データを追加するだけで済む構造にしてある
- 制作の過程はNoteの記事ネタとしても使う想定

## 2. 決定事項と理由

| 項目 | 決定 | 理由 |
|---|---|---|
| フレームワーク | Flutter | iOSとAndroidの両方に出せる（ユーザーの母数が増える） |
| 対応する試験 | AWS認定の全試験（今受けられるもの）。ベータ版は入れない。終了予定の試験は「◯月で終了」と表示し、終了日を過ぎたら外す | 全冠を目指す本人の学習と連動させるため。ただし差別化の軸は「質」（下の行）で、全試験対応は将来の広がりという位置づけ |
| 問題を収録する試験 | まずSAP（SAP-C03） | 次に受験予定なので、問題作りがそのまま勉強になる。競合調査でも、日本語のSAP専用アプリは見つからなかった（競合はCLF・SAAに集中） |
| 差別化の軸 | **質**。①SAPの長いシナリオ問題を、設計判断のポイントごとの一問一答に分解する（スマホで読みやすくするため）②全問の解説にAWS公式ドキュメントへのリンクを付ける | 問題数ではAI生成系のアプリ（数千問規模）に勝てないため（`docs/market-research.md`） |
| アプリ名の方針 | 独自ブランドにし、「AWS」を主役にしない。「AWS認定SAP対策」などはサブタイトル・説明文・キーワードで表現する。名前そのものは未決（下の「未決事項」） | AWSの商標ガイドラインで、混同を招く使い方・提携や承認を暗示する使い方・自社ブランドより目立たせる使い方が禁止されているため |
| 免責文 | ストアの説明文とアプリ内に入れる。例：「本アプリはAmazon Web Services, Inc.とは提携していません。AWSおよびAWS認定はAmazon.com, Inc.またはその関連会社の商標です。」 | 公式アプリや提携と誤解されないようにするため。アプリ内では「このアプリについて」とホームの一番下に表示（`AppInfo.trademarkNotice`）。ストアの文案は `docs/store_listing.md` |
| 一問一答の形式 | 短い4択と○×（2択）の混在。「どのサービスか」は4択、「〜できるか」は○× | 問いの内容に合った形式のほうが自然で、テンポよく解けるため（2026-11-21 決定） |
| 本番形式の問題 | 残す。一問一答で理解 → 本番形式で確認 → 模試で仕上げる流れにする | 模試には本番形式の問題が必要なため（2026-11-21 決定） |
| v1 に入れる試験 | SAP と SAA | SAA は競合が多いが、ダウンロードの入口が増えるため（2026-11-21 決定） |
| データの持ち方 | アプリ内のJSON（`assets/exams.json` と `assets/questions/<試験ID>.json`） | 最初のバージョンを早く出すため。将来Supabaseなどに移す場合も、リポジトリ層（`lib/data/`）だけ差し替えればよい |
| 分野の参照 | 分野はexams.jsonで `{id, name, weight}` として定義し、問題側はID（`d1`など）で参照 | 分野名は長く表記ゆれしやすい。IDなら名前を直しても問題側を書き換えなくて済む（Laravelでいう外部キー） |
| 試験の版 | exams.jsonの `code` に版まで入れる（`SAP-C03`）。問題ファイルの `examCode` と一致しないと品質チェックでエラー | 版の改訂（SAPは2026-11-17にC02→C03）で、古い版の問題が混ざるのを防ぐ |
| 学習記録 | 端末内のSQLite（`sqflite`）。取得済みの印や表示モードは `shared_preferences` | サーバーを持たずに済む。SQLで分野ごとの正答率を集計できる |
| 正答率の計算 | 各問題の**最新の回答**で計算 | 間違えた問題も解き直して正解すれば反映され、今の実力に近い数字になる |
| 模試の採点 | 正答率（%）で表示。本番のスケールスコアは出さない | スケールスコアの計算方法は公開されておらず、点数風の数字は誤解を招くため |
| 見た目 | 白基調・角丸のカード・アクセントはティール1色。ダークモード対応 | AWSのオレンジと紺は公式アプリと誤解されやすいので避けた |
| 公開の方針 | 作り込みより早く出すことを優先 | 「公開して広告が表示される」までを最初のゴールにする |

## 3. 必ず守るルール

- **問題は必ず自作する**：AWSの本番の試験問題は口外禁止の規約がある。問題集・模試の問題を写すのも著作権的にNG。公式ドキュメントを根拠に作る
- **根拠リンクは一次情報だけ**：AWS公式ドキュメント・公式ブログ・ホワイトペーパー（`docs.aws.amazon.com`、`aws.amazon.com`、`d1.awsstatic.com`）。品質チェックでドメインも確認している
- **アプリ名に「AWS」を主役として入れない**：AWSの商標ガイドラインで、混同を招く使い方・提携や承認を暗示する使い方・自社ブランドより目立たせる使い方が禁止されている。アプリ名は独自ブランド（未決。今の「クラウド認定」は仮称）にし、「AWS認定SAP対策」などはサブタイトル・説明文・キーワードで表現する。試験名（SAP、SAAなど）は使ってよい
- **免責文を入れる**：ストアの説明文とアプリ内に「本アプリはAmazon Web Services, Inc.とは提携していません。AWSおよびAWS認定はAmazon.com, Inc.またはその関連会社の商標です。」の趣旨の文を入れる
- **自分で広告をクリックしない**：AdMobの規約違反になる

## 4. 開発環境

- Mac（Apple Silicon）、Xcode 27（iOS 27.2のシミュレーター）
- Flutter SDK：`~/Developer/tools/flutter`（Flutter 3.50.1）
- プロジェクト：`~/Developer/tools/aws_quiz`
  - ※ 本来は`~/Developer/personal/`に置く予定だった。移動するかは未決定。`personal/aws_qioz`という似た名前のフォルダもあり、こちらが不要かどうかも未確認
- iOSのネイティブ依存は、Flutterが自動で CocoaPods / Swift Package Manager を使い分けている（`ios/Podfile` は無い）

### シミュレーターの起動（Xcode 27での注意点）

Xcode 27ではSimulatorアプリの名前がDevice Hubに変わっていて、`flutter emulators --launch apple_ios_simulator`では起動できなかった。直接起動する。

```bash
xcrun simctl boot E429B161-CAA4-424E-9197-0732F1CE1036   # iPhone 18 Pro
open -a DeviceHub
flutter run -d E429B161-CAA4-424E-9197-0732F1CE1036
```

- `pubspec.yaml`やassetsを変更したときは、ホットリロード（`r`）ではなく`flutter run`のやり直しが必要
- `xcrun simctl ui <ID> appearance dark` が途中から反映されなくなったことがある。ダークモードの確認は `--dart-define=THEME=dark` で行う

### 開発用のビルドオプション

| オプション | 効果 |
|---|---|
| `--dart-define=ADS=false` | 広告と同意画面を出さない（画面確認やテストで使う） |
| `--dart-define=THEME=dark` / `light` | テーマを固定する |
| `--dart-define=DEBUG_ROUTE=exam` | 起動後、問題のある最初の試験のトップまで自動で進む。ほかに `quiz`（出題）、`explanation`（1問目で不正解を選んだ解説）、`mock`（模試）、`mock-result`（模試の結果）。デバッグビルドだけで効く |

### import について

このFlutterのバージョンでは、テンプレートが`package:flutter/material.dart`ではなく`package:material_ui/material_ui.dart`をimportしている。既存のコードに合わせること。

## 5. 現在の実装

`flutter analyze` 指摘なし、`flutter test` 35件通過、品質チェック エラー0件・警告0件（2026-11-21）。

### ファイル構成

```
assets/exams.json                       試験の一覧と設定（12試験）
assets/questions/sap.json               SAPの問題（本番形式50問＋一問一答27問）
assets/questions/saa.json               SAAの問題（自作35問。分野1〜4に 9・9・7・10問、うち複数選択2問）
lib/main.dart                           テーマと起動。最初の画面のあとに広告の同意確認
lib/models/exam.dart                    Exam・Domain・MockSetting・ExamLevel
lib/models/question.dart                Question・Choice・Reference
lib/data/exam_repository.dart           exams.jsonの読み込み、問題ファイルの有無の判定
lib/data/question_repository.dart       問題の読み込み（対応していない種類の問題は除く）
lib/data/study_repository.dart          学習記録（SQLite）。回答の記録・正答率・模試の結果
lib/data/certification_repository.dart  取得済みの印（shared_preferences）
lib/logic/mock_builder.dart             模試の問題選び（比重どおりに配分）と採点
lib/validation/question_validator.dart  問題データの品質チェック（純粋なDart）
lib/screens/home_screen.dart            ホーム：全冠の進捗と、レベル別の試験一覧
lib/screens/exam_screen.dart            試験トップ：出題方法の選択、分野ごとの問題数と正答率
lib/screens/quiz_screen.dart            練習モードの出題と結果
lib/screens/mock_screen.dart            模試の出題（タイマー・一覧・まとめて採点）
lib/screens/mock_result_screen.dart     模試の結果と、間違えた問題の見直し
lib/widgets/explanation_view.dart       回答後の解説（練習と模試の見直しで共通）
lib/widgets/domain_accuracy_bar.dart    分野ごとの正答率のバー
lib/widgets/related_questions_buttons.dart  解説の下の「類題に挑戦」「ポイント別の一問一答」「元の問題に挑戦」
lib/screens/about_screen.dart           このアプリについて（注意書き・免責文・プライバシーポリシー・問い合わせ・ライセンス）
lib/config/app_info.dart                アプリ名・問い合わせ先・注意書き・免責文
lib/settings/quiz_layout.dart           出題画面の表示モード（タブ／スワイプ）
lib/theme/app_theme.dart                ライト・ダークのテーマ、正誤の色
lib/ads/                                広告（下の「広告の実装」）
tool/validate_questions.dart            品質チェックのコマンド
```

### 画面

1. **ホーム**：上部に「n / 12 取得」の進捗。Foundational / Associate / Professional / Specialty ごとにカード。問題ファイルが無い試験は「準備中」で薄く表示（タップ不可）。右の ✓ で取得済みの印をつけられる（準備中の試験にもつけられる）
2. **試験トップ**：取得済みの切り替え、「全分野から出題」「分野を選んで出題」「模試」、前回の模試の結果、分野ごとの問題数・正答率・比重。分野をタップするとその分野だけを出題
3. **出題（練習）**：右上のメニューで表示モードを切り替え（問題と選択肢をタブで分ける／選択肢だけスワイプ）。回答すると解説を表示
4. **解説**：選んだ選択肢の解説を色付きの枠で一番上に → 正解（選んでいなかった場合）→ ほかの選択肢 → まとめ → 根拠リンク（タップで外部ブラウザ）
5. **練習の結果**：正答率と分野ごとの内訳
6. **模試**：試験ごとの問題数・時間で、比重どおりに分野を配分して出題。1問ごとの正誤は出さない。前の問題に戻れる・一覧から未回答に飛べる。残り時間は終了時刻から計算し、時間切れで自動採点。中断すると回答は保存されない
   - 収録数が足りないときは、ある分だけで実施し、時間も比例して短くする（今のSAPは50問・120分）
7. **模試の結果**：正答率・かかった時間・分野別の正答率・間違えた問題の一覧（タップで解説付きの見直し）

### データの形式

`assets/exams.json`（1試験分）

```json
{
  "id": "sap",
  "code": "SAP-C03",
  "shortName": "SAP",
  "name": "Solutions Architect - Professional",
  "nameJa": "ソリューションアーキテクト - プロフェッショナル",
  "level": "professional",
  "status": "available",
  "domains": [
    { "id": "d1", "name": "クラウド向けに構築されたアーキテクチャの設計と実装", "weight": 25 }
  ],
  "mock": { "questionCount": 75, "timeLimitMinutes": 180 },
  "guideUrl": "https://docs.aws.amazon.com/ja_jp/aws-certification/latest/..."
}
```

- `level`：`foundational` / `associate` / `professional` / `specialty`
- `status`：`available` か `retiring`（`retiring` のときは `retireDate` も書く）
- 分野名・比重は公式の試験ガイド（日本語版）の表記そのまま
- 模試の問題数は採点されない問題も含めた本番の問題数

`assets/questions/<試験ID>.json`

```json
{
  "examId": "sap",
  "examCode": "SAP-C03",
  "questions": [
    {
      "id": "sap-001",
      "domain": "d2",
      "question": "問題文",
      "choices": [
        { "text": "選択肢A", "explanation": "Aが不正解の理由" },
        { "text": "選択肢B", "explanation": "Bが正解の理由" }
      ],
      "answers": [1],
      "explanation": "全体のまとめ解説",
      "references": [
        { "title": "サービスコントロールポリシー (SCP)", "url": "https://docs.aws.amazon.com/ja_jp/..." }
      ]
    }
  ]
}
```

- `answers`は0始まりのインデックスの配列。複数選択なら2つ以上
- 本番の形式に合わせ、単一選択は4択、複数選択は5つ以上の選択肢にする（違うと品質チェックで警告）
- ※ 一問一答（`type: "drill"`）は下の「一問一答」を参照
- `type` は省略可（`choice`）。並べ替えなど新しい種類を足すときは `type` を変え、`Question.supportedTypes` に足す。古いアプリは知らない種類の問題を読み飛ばすので、アップデート前のアプリでも壊れない

### 試験を追加する手順

1. 公式の試験ガイドで、分野・比重・版が `assets/exams.json` と合っているか確認する
2. `assets/questions/<試験ID>.json` を作る（`examId` と `examCode` を exams.json に合わせる）
3. `dart run tool/validate_questions.dart` でエラーが無いことを確認する
4. `flutter test` を通す（同じチェックがテストでも走る）

ホームの「準備中」は、問題ファイルを置くと自動で外れる。

### 品質チェック（`dart run tool/validate_questions.dart`）

エラー：根拠リンクが無い／根拠リンクが一次情報のドメインでない／選択肢の解説が無い／answersが範囲外・重複／idの重複（全試験を通して）／domainがexams.jsonに無い／examCodeが版と一致しない
警告：単一選択が4択でない／複数選択の選択肢が5つ未満／単一選択の正解の位置が偏っている（8問以上で、1つの位置に半分以上）

### 学習記録（`lib/data/study_repository.dart`）

- `answers` テーブル：回答1回ごと（試験ID・問題ID・正誤・モード・日時）。練習と模試の両方を記録（模試は回答した問題だけ）
- `mock_results` テーブル：模試1回ごと（問題数・正解数・かかった時間・分野ごとの結果）
- 正答率は各問題の最新の回答で計算し、分野は「今の問題データの分野」で集計する（あとで分野を付け替えてもズレない）
- 列を足すときは `openDatabase` の `version` を上げ、`onUpgrade` に `ALTER TABLE` を書く（Laravelのマイグレーションにあたる）

### 広告の実装

```
lib/ads/ad_config.dart               広告ユニットIDの置き場所。今はGoogle公式のテスト用ID
lib/ads/ad_consent.dart              同意（UMP）とトラッキング許可（ATT）、SDKの初期化
lib/ads/banner_ad_view.dart          画面幅に合わせたバナー。読み込めるまでは何も表示しない
lib/ads/interstitial_ad_manager.dart 全画面広告の先読みと表示
```

- バナー：出題画面（練習・模試）の下と、結果画面の下
- 全画面広告：練習の最後の問題で「結果を見る」を押したときと、模試を採点したときに1回だけ。模試の途中には出さない
- アプリIDは `ios/Runner/Info.plist`（`GADApplicationIdentifier`）と `android/app/src/main/AndroidManifest.xml`。どちらもテスト用ID
- 同意の流れ：最初の画面が出たら、①UMPで同意が必要な地域（EU・イギリスなど）の人にだけ同意画面 → ②iOSのトラッキング許可（ATT） → ③広告SDKの初期化。この確認が終わるまで広告は読み込まない
- 同意が必要な地域の人には、ホームと出題画面の右上メニューに「広告のプライバシー設定」が出る（GDPRで、同意をあとから変えられる導線が必須）

**リリース前にやること（広告まわり）**
- AdMobでアプリと広告ユニットを作る。広告ユニットIDはリリースビルドのときに `--dart-define=ADMOB_BANNER_IOS=...` などで渡す（渡さなければテスト用IDのまま。使い方は `lib/ads/ad_config.dart` の先頭）。アプリIDは `Info.plist` と `AndroidManifest.xml` を直接書き換える
- `Info.plist` の `SKAdNetworkItems` は、Google の一覧（2026-01-30 更新版、50件）を入れ済み。リリース前に https://developers.google.com/admob/ios/3p-skadnetworks の更新日を確認する
- AdMobの管理画面で、同意画面（GDPR用）とATT前の説明画面（IDFAメッセージ）の文面を日本語で作る
- プライバシーポリシー：下書きは `docs/privacy_policy.md`。`［ ］` を埋めて公開し（GitHub Pages など）、URLを `lib/config/app_info.dart` の `privacyPolicyUrl` に入れる
- 問い合わせ用のメールアドレスを決めて `lib/config/app_info.dart` の `supportEmail` に入れる（解説の下の「この問題の誤りを報告」と「このアプリについて」で使う。空だと「未設定」と表示される）
- バンドルID（iOS `com.example.awsQuiz`、Android `com.example.aws_quiz`）を自分のものに変える。公開後は変えられない

### 類題（2026-11-21 追加）

- 問題に任意の `"group"`（例: `"s3-storage-class"`）を付けると、同じグループの問題が「類題」になる
- 類題は**条件を変えると正解が変わる問題**にする。言い回しだけ変えた問題は作らない（同じグループで正解の選択肢の文が同じだと、品質チェックが警告を出す）
- 解説の根拠の下に「類題に挑戦（n問）」ボタンが出る（練習モードと模試の見直し）
- 模試では、グループごとに1問を優先して選ぶ。収録数が足りないときだけ2問目以降でも補う（`lib/logic/mock_builder.dart`）
- 今あるグループ
  - SAA：s3-storage-class（4問）、messaging-service（3問）、db-availability-or-read（3問）、compute-pricing（3問）
  - SAP：vpc-connectivity（4問）、s3-storage-class・compute-pricing・messaging-service・permission-guardrails（各2問）
- 類題を足す候補：混同しやすい論点（SAP の s3-storage-class・messaging-service に3問目、DR の方式の使い分け、Route 53 のルーティングポリシーの使い分けなど）

### 一問一答（2026-11-21 追加）

- 本番形式のシナリオ問題を、設計判断のポイントごとに分解した短い問題。差別化の軸（質）の1つ
- データ：`"type": "drill"`。`source`（分解元の本番形式の問題のID）と `point`（設計判断のポイントの見出し）を持つ。分野（`domain`）は分解元に合わせる
- 形式：「どのサービスか」は短い4択、「〜できるか」は○×（選択肢は `○ 正しい` / `× 誤り` の2つ）。正解は1つ
- 品質チェック：選択肢2〜4つ・正解1つ（エラー）、`source` が実在する本番形式の問題か（エラー）、問題文が120字を超える・`point` が無い（警告）、正解の位置の偏りは本番形式と別に数える
- 画面：試験トップの一番上に「一問一答（n問）」。選択肢をタップした時点で回答し、すぐに解説が出る。表示モードの設定に関係なく1画面
- 本番形式の解説の下に「ポイント別の一問一答（n問）」、一問一答の解説の下に「元の問題（本番形式）に挑戦」が出る
- 模試・分野別の出題・ホームの問題数（「n問」）は本番形式だけ。一問一答の数は「一問一答 n問」と別に出す
- 学習記録は `mode = 'drill'` で記録する。分野ごとの正答率は本番形式と一問一答を合わせて計算
- 今あるもの：SAP の10問（sap-001・004・005・006・007・008・009・012・013・014）から27問（sap-d001〜d027）。残りの本番形式の問題も順に分解する

## 6. 次にやること（優先順）

1. **シミュレーターで画面を触って確認**（下の「未確認のこと」）
2. **SAPの問題を見直す**：2026-11-21 に Claude が50問まで作成した（分野1〜5に 12・12・8・8・10問、うち複数選択5問）。SAP-C03 の試験ガイドのタスクから、仕組みが安定している論点を選んで自作し、根拠リンクはすべて実在を確認済み。ただし内容の正確さは本人の目でも確認する（問題を解きながら、解説と根拠リンクを読むのがおすすめ）
   - 2026-11-21 に品質チェック済み：全問の解説の主張を根拠ページと照合し（主張と引用の対応表を作成）、食い違い・古い情報を修正、根拠リンクを18件追加した。正解が1つに決まるかのレビューも実施。根拠ページに直接の記述が見つからず残っているのは sap-007（PrivateLink は CIDR が重複しても使える）と sap-010（スティッキーセッションでセッションが消える）
   - 試験ガイドの「範囲内のサービス」に入っていないサービスを正解にしていた2問を作り直した（sap-002：Application Discovery Service → AWS Transform、sap-018：AWS Artifact → AWS Verified Access）。問題を作るときは、正解のサービスが試験ガイドの範囲内のサービスの一覧にあるかを確認する
   - sap-031〜050 と saa-001〜030 は根拠ページで事実を確かめてから作成した。sap-031〜038（Glacier Deep Archive、スポット、Compute Optimizer、Budgets の予算アクション、DMS＋SCT、Transform MGN、S3 File Gateway、FIS）
   - 作成時、単一選択の正解の多くが B に偏ったため、選択肢を並べ替えて A〜D に散らした（品質チェックにも偏りの警告を追加）
   - 今後足すなら、まだ入れていない論点（Bedrock Guardrails、Resilience Hub、Elastic Beanstalk、Lake Formation、EKS など）も、公式ドキュメントを確認しながら入れていく
3. **App Storeへの公開準備**：Apple Developer Program（年99ドル）、アイコン、上の「リリース前にやること（広告まわり）」。ホーム画面に出るアプリ名は仮に「クラウド認定」にしてある（`CFBundleDisplayName`・`android:label`）。アプリ内の表記は `lib/config/app_info.dart` の `appName`。正式な名前が決まったらこの3か所を変える
4. Androidの環境構築とGoogle Playへの公開
5. ほかの試験の問題を追加（次に受ける試験から）

### 後で追加したい機能

- 間違えた問題だけ解き直す（学習記録に最新の正誤があるので作りやすい）
- 練習モードの出題順のシャッフル
- 模試の結果の履歴（`mockResults` で取得できるので、画面を作るだけ）
- 問題データをSupabaseなどに置き、アップデートなしで問題を追加できるようにする（`QuestionRepository` を差し替える。取得できないときはアプリ内のJSONを使う）

## 7. 未決事項（本人の判断待ち。Claude は勝手に決めない）

### 競合調査から（2026-11-21、`docs/market-research.md`）
- **アプリ名**：候補はクラ問 / くもドリル / スキマ認定 / ワンタップ認定
- **収益化の形**：「無料＋広告」に「広告を消す買い切り（数百円）」を加えるかどうか。広告なしを求める層を取りこぼさないための案
- **作者の立場の書き方**：SAP合格前に公開する場合、「SAP合格を目指しながら作った問題集」のように正直に書く案
- **v1に入れる機能**：苦手分野の可視化（レーダーチャートなど）と模擬試験モードを、v1に入れるか後回しにするか（模擬試験モードはすでに実装済み）

### リリース準備から
- 問い合わせ用のメールアドレス（`lib/config/app_info.dart` の `supportEmail`）
- プライバシーポリシーの公開先（GitHub Pages など）と、載せる開発者名
- バンドルID（今は `com.example.awsQuiz`。公開後は変えられない）
- プロジェクトのフォルダを `~/Developer/personal/` に移すかどうか

## 8. 未確認のこと・注意点

### 画面操作で未確認（シミュレーターはスクショでしか確認できていない）
- 「分野を選んで出題」のシート
- 模試の操作の流れ（選択・前後の移動・一覧・採点の確認ダイアログ・中断）
- 根拠リンクをタップしてブラウザが開くか
- 同意画面の「Continue」を押したあと、ATTのダイアログ → バナー表示まで進むか
- 試験トップの「取得済み」の切り替え
- 「この問題の誤りを報告」でメールアプリが開くか（`supportEmail` を入れてから。シミュレーターにはメールアプリが無いので実機で）
- 「このアプリについて」→「ライセンス」

### 試験情報で未確認・期限があるもの（2026-11-21時点）
- **AIP-C01**：180分・75問（採点対象65問＋採点対象外10問）を公式ページで確認済み
- **DVA**：DVA-C02は2026-11-30で終了。DVA-C03は2026-10-27に申し込み受付開始済み。exams.jsonはDVA-C03
- **MLA**：英語版のMLA-C01は2026-09-28で終了し、MLA-C02はベータ中（170分・85問、正式リリース日は未定）。日本語版はC02の正式リリースまでMLA-C01が受けられるので、exams.jsonはMLA-C01のまま。C02の分野は「データ準備 28%／モデルと基盤モデルの開発 24%／デプロイとオーケストレーション 24%／運用・モニタリング・セキュリティ 24%」
- **ANS（Advanced Networking - Specialty）**：2026-12-31で終了。終了日を過ぎた試験はアプリが自動で一覧から外す（`Exam.isOpenOn`）ので、アップデートは急がなくてよい。次に更新するときにexams.jsonから消す
- **AI Business Strategist（AIB-C01）**：ベータ版のため入れていない。正式リリースされたら追加を検討（レベルが「Business」なので、`ExamLevel` に追加が必要）

## 9. 開発者について

- 本業はLaravel・Next.jsのエンジニア。FlutterとDartは初心者
- 説明は簡潔に、具体例と「なぜそうするか」をセットにしてほしい
- Laravelの概念（リポジトリ層、サービス層など）にたとえると理解しやすい
