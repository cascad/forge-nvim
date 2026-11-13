import sys
from pathlib import Path

answer = 42
Path("python-run.txt").write_text(sys.prefix, encoding="utf-8")
print("MIX_PY_BEFORE", answer, flush=True)
observed = answer  # MIX_BREAKPOINT
print("MIX_PY_AFTER", observed, flush=True)
