import re, sys
def flip(files, table):
    done = set()
    for p in files:
        s = open(p).read()
        for point, (stmt, why) in table.items():
            pat = re.compile(r"tf\('" + re.escape(point) + r"', '([^']*)', True,\n(\s*)'([^']*)'")
            m = pat.search(s)
            if not m:
                continue
            s = s[:m.start()] + f"tf('{point}', '{stmt}', False,\n{m.group(2)}'{why}'" + s[m.end():]
            done.add(point)
        open(p, 'w').write(s)
    missing = set(table) - done
    if missing:
        print('見つからない:', missing); sys.exit(1)
    print('書き換え', len(done))
