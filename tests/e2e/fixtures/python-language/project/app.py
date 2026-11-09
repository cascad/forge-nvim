import sys
from pathlib import Path
from src.forge_math import double
from forge_fixture_dependency import PACKAGE_MARKER

print(f"PY_BEFORE {sys.argv[1] if len(sys.argv) > 1 else 'default'}", flush=True)
print('PY_STDERR', file=sys.stderr, flush=True)
answer = double(21)
print('PY_VALUE', answer, flush=True)  # E2E_BREAKPOINT
print('PY_DEPENDENCY', PACKAGE_MARKER, flush=True)
print('PY_PREFIX', sys.prefix, flush=True)
print('PY_PROJECT_VENV', Path(sys.prefix).resolve() == (Path(__file__).parent / '.venv').resolve(), flush=True)
Path('python-cwd.txt').write_text(str(Path.cwd()), encoding='utf-8')
