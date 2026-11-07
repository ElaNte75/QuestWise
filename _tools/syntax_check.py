import os, sys, re
from lupa import LuaRuntime

root = sys.argv[1]
lua = LuaRuntime(unpack_returned_tuples=True)
toc = open(os.path.join(root, os.path.basename(os.path.normpath(root)) + ".toc"), encoding="utf-8").read().splitlines()
files = [l.strip() for l in toc if l.strip() and not l.startswith("##")]
bad = 0
for f in files:
    src = open(root + "/" + f, encoding="utf-8").read()
    try:
        lua.eval("function(s, n) local f, e = load(s, n); if not f then error(e) end end")(src, f)
        print("OK  ", f, len(src.splitlines()), "lines")
    except Exception as e:
        bad += 1
        print("FAIL", f, e)
print("failures:", bad)
