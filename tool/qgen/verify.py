"""根拠リンクの実在と、根拠ページ（英語版）に決め手の語句があるかを照合する。

使い方: python3 verify.py clf   （clf_data.py の E を読む）
"""
import concurrent.futures as cf
import hashlib
import html
import importlib
import os
import re
import sys
import urllib.request

CACHE = os.path.join(os.path.dirname(__file__), 'cache')
os.makedirs(CACHE, exist_ok=True)
UA = 'Mozilla/5.0 (question-reference-check)'


def fetch(url):
    path = os.path.join(CACHE, hashlib.sha1(url.encode()).hexdigest())
    if os.path.exists(path):
        with open(path, encoding='utf-8') as f:
            status, body = f.read().split('\n', 1)
        return int(status), body
    try:
        req = urllib.request.Request(url, headers={'User-Agent': UA})
        with urllib.request.urlopen(req, timeout=30) as r:
            status, body = r.status, r.read().decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        status, body = e.code, ''
    except Exception as e:  # noqa
        status, body = 0, str(e)
    if status in (200, 404):
        with open(path, 'w', encoding='utf-8') as f:
            f.write(f'{status}\n{body}')
    return status, body


def english(url):
    if '/ja_jp/' in url:
        return url.replace('/ja_jp/', '/')
    return url.replace('aws.amazon.com/jp/', 'aws.amazon.com/')


def text_of(body):
    m = re.search(r'<div id="main-col-body">(.*?)<div class="prev-next"', body, re.S)
    b = m.group(1) if m else body
    b = re.sub(r'<script.*?</script>|<style.*?</style>', ' ', b, flags=re.S)
    b = re.sub(r'<[^>]+>', ' ', b)
    return re.sub(r'\s+', ' ', html.unescape(b)).lower()


def is_redirect_stub(body):
    # docs.aws の「このページは移動しました」系
    return 'http-equiv="refresh"' in body.lower() and len(body) < 3000


def main(exam):
    sys.path.insert(0, os.path.dirname(__file__))
    E = importlib.import_module(f'{exam}_data').E
    urls = {r['url'] for r in E.refs.values()}
    en = {english(u) for u in urls}
    with cf.ThreadPoolExecutor(8) as ex:
        res = dict(zip(sorted(urls | en), ex.map(fetch, sorted(urls | en))))
    bad = 0
    for key, r in sorted(E.refs.items()):
        st, body = res[r['url']]
        if st != 200 or is_redirect_stub(body):
            bad += 1
            print(f'NG リンク {st} {key} {r["url"]}')
    used = set()
    for item in E.items:
        used |= set(item['refs'])
        for d in item['drills']:
            used |= set(d.refs or [])
    for key in sorted(set(E.refs) - used):
        print(f'未使用の ref: {key}')
    miss = 0
    for qid, key, phrases in E.evidence():
        url = E.refs[key]['url']
        for ph in phrases:
            # 日本語の語句は日本語版のページで、英語の語句は英語版のページで照合する
            ja = any(ord(ch) > 0x2000 for ch in ph)
            t = text_of(res[url if ja else english(url)][1])
            if ph.lower() not in t:
                miss += 1
                print(f'語句なし {qid} [{key}] "{ph}"')
    print(f'== {exam}: リンク {len(urls)}件（NG {bad}）・照合 {len(E.evidence())}件（語句なし {miss}）')


if __name__ == '__main__':
    main(sys.argv[1])
