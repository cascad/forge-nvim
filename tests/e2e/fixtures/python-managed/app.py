import sys
from pathlib import Path
from forge_fixture_dependency import calculate_answer

answer = calculate_answer(21)
print("MANAGED_VALUE", answer, flush=True)
print("MANAGED_PROJECT_VENV", Path(sys.prefix).resolve() == (Path(__file__).parent / ".venv").resolve(), flush=True)
print("MANAGED_AFTER", answer, flush=True)  # E2E_BREAKPOINT
