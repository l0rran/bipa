"""Lista ou aplica (no índice) hunks selecionados do diff de um arquivo.
uso: hunks.py list FILE | hunks.py stage FILE 0,2,3"""
import subprocess, sys
mode, path = sys.argv[1], sys.argv[2]
diff = subprocess.run(['git', 'diff', '-U1', '--', path], capture_output=True, text=True, check=True).stdout
lines = diff.splitlines(keepends=True)
header, hunks, cur = [], [], None
for l in lines:
    if l.startswith('@@'):
        cur = [l]; hunks.append(cur)
    elif cur is None:
        header.append(l)
    else:
        cur.append(l)
if mode == 'list':
    for i, h in enumerate(hunks):
        body = ''.join(x for x in h[1:] if x[0] in '+-')
        print(f'--- [{i}] {h[0].strip()}\n{body[:600]}')
else:
    keep = {int(x) for x in sys.argv[3].split(',')}
    patch = ''.join(header) + ''.join(''.join(h) for i, h in enumerate(hunks) if i in keep)
    subprocess.run(['git', 'apply', '--cached', '--recount', '-'], input=patch, text=True, check=True)
