import sys, importlib, concurrent.futures as cf
from verify import fetch, english, is_redirect_stub
m = importlib.import_module(sys.argv[1])
E = m.E
items = sorted(E.refs.items())
with cf.ThreadPoolExecutor(8) as ex:
    res = list(ex.map(lambda kv: (kv[0], kv[1]['url'], fetch(kv[1]['url']), fetch(english(kv[1]['url']))), items))
bad = 0
for k, u, (s, b), (se, be) in res:
    if s != 200 or se != 200 or is_redirect_stub(b) or len(b) < 2000:
        bad += 1
        print('NG', k, s, se, len(b), u)
print('refs', len(items), 'NG', bad)
