import sys, importlib, re
from verify import fetch, text_of, english
mod, key = sys.argv[1], sys.argv[2]
E = importlib.import_module(mod).E
u = E.refs[key]['url']
ja = len(sys.argv) > 3 and sys.argv[3] == '--ja'
words = sys.argv[4:] if ja else sys.argv[3:]
t = text_of(fetch(u if ja else english(u))[1])
print(key, len(t))
for w in words:
    idx = [m.start() for m in re.finditer(re.escape(w.lower()), t)][:2]
    print(f'[{w}]', 'なし' if not idx else ' | '.join(t[max(0,i-120):i+160] for i in idx))
