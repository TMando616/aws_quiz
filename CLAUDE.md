# aws_quiz

AWS認定の全試験に対応し、全冠取得を目指せる学習アプリ。Flutter製、iOS優先。問題を収録しているのは今のところSAPだけ（38問）。

経緯・決定事項・現状・次のタスクは **docs/handoff.md** にまとめてある。作業を始める前に必ず読むこと。

## よく使うコマンド

```bash
xcrun simctl boot E429B161-CAA4-424E-9197-0732F1CE1036 && open -a DeviceHub
flutter analyze
flutter test
dart run tool/validate_questions.dart   # 問題データの品質チェック
flutter run -d E429B161-CAA4-424E-9197-0732F1CE1036

# 開発用のビルドオプション（組み合わせ可）
#   --dart-define=ADS=false            広告と同意画面を出さない
#   --dart-define=THEME=dark|light     テーマを固定する
#   --dart-define=DEBUG_ROUTE=exam|quiz|explanation|explanation-end|mock|mock-result|about
#                                      起動後、その画面まで自動で進む（デバッグビルドのみ）
```

## 守ること

- importは`package:material_ui/material_ui.dart`（このFlutterバージョンのテンプレートに合わせる）
- 問題文・解説は自作のみ。本番の試験問題や問題集からの転載はしない
- 問題の正解にするサービスは、試験ガイドの「範囲内のサービス」の一覧にあるものにする
- 問題には必ず根拠リンク（AWS公式ドキュメント・公式ブログ・ホワイトペーパー）を付け、追加・修正したら `dart run tool/validate_questions.dart` を通す
- 試験の分野・問題数・時間は公式の試験ガイドに合わせる。試験の版が変わったら `assets/exams.json` の `code` と分野を更新する
- アプリ名・画面表記に「AWS」を前面に出さない（「クラウド認定」とする）。試験名（SAP、SAAなど）は使ってよい
- 修正のたびに `flutter analyze`・`flutter test` を通してからコミットする
- 説明は簡潔に、「なぜそうするか」をセットで。Laravelにたとえると伝わりやすい
