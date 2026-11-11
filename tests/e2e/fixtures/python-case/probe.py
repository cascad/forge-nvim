"""Real short Python process for the CLI filter/argv/exit contract."""
import json
import os
from pathlib import Path
import sys

Path(os.environ['FORGE_PYTHON_CASE_PROBE']).write_text(json.dumps({
    'argv': sys.argv[1:], 'cwd': str(Path.cwd()), 'executable': sys.executable,
    'pid': os.getpid(), 'major': sys.version_info.major,
}, ensure_ascii=False), encoding='utf-8')
sys.stdout.write('PYTHON_CASE_STDOUT ü\n')
sys.stderr.write('PYTHON_CASE_STDERR ü\n')
sys.exit(7 if sys.argv[1].startswith('fail') else 0)
