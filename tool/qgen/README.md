# tool/qgen — 問題の作成と根拠リンクの照合（CLF・DVA・SOA）

2026-11-22 に CLF・DVA・SOA の問題を作ったときのスクリプト。**アプリが読むのは `assets/questions/<試験ID>.json` で、こちらが正**。JSON を手で直したら、ここのスクリプトとはずれるので注意（作り直すときは、先にここのスクリプトに同じ修正を入れる）。

## ファイル

| ファイル | 役割 |
|---|---|
| `qdsl.py` | 問題を短い書式で書いて JSON に変換する。単一選択の正解の位置を A〜D に散らし、一問一答は正解が少ない位置に置く |
| `<試験>_refs.py` | 根拠リンクの一覧 |
| `<試験>_q<分野>.py` | 問題（分野ごと）。`ev=` は根拠ページにあるはずの語句（JSON には出さない） |
| `<試験>_data.py` | 上を読み込んで 1 つの試験にまとめる |
| `verify.py` | 根拠リンクの実在と、`ev` の語句が根拠ページにあるかを照合する（日本語の語句は日本語版、英語の語句は英語版のページで照合） |
| `checkrefs.py` | 根拠リンクの一覧だけを先に確認する |
| `grep.py` | 根拠ページの本文から語句を探す（照合に失敗したときの調査用） |
| `flip.py` | ○×の一問一答を「誤り」が正解の文に書き換える（正誤の比率の調整用） |

## 使い方

```bash
cd tool/qgen
python3 verify.py soa          # 照合（ページは cache/ に保存される。AWS のドキュメントが変わったら cache/ を消して再実行）
python3 -c "from soa_data import E; E.write('../../assets/questions/soa.json')"
cd ../.. && dart run tool/validate_questions.dart
```

AWS のドキュメントは改定で記述が変わるので、ときどき `cache/` を消して `verify.py` を流すと、解説が古くなった問題を見つけられる。
