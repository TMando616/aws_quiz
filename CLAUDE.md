# aws_quiz

AWS認定（まずはSAP）の一問一答アプリ。Flutter製、iOS優先。

経緯・決定事項・現状・次のタスクは **docs/handoff.md** にまとめてある。作業を始める前に必ず読むこと。

## よく使うコマンド

```bash
xcrun simctl boot E429B161-CAA4-424E-9197-0732F1CE1036 && open -a DeviceHub
flutter analyze
flutter run -d E429B161-CAA4-424E-9197-0732F1CE1036
flutter test
```

## 守ること

- importは`package:material_ui/material_ui.dart`（このFlutterバージョンのテンプレートに合わせる）
- 問題文は自作のみ。本番の試験問題や問題集からの転載はしない
- 説明は簡潔に、「なぜそうするか」をセットで。Laravelにたとえると伝わりやすい
