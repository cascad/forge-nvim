from pathlib import Path
import sys
from forge_fixture_dependency import calculate_answer


def test_nearest():
    answer = calculate_answer(21)
    print('PYTEST_VALUE', answer, flush=True)  # E2E_BREAKPOINT
    print('PYTEST_PREFIX', sys.prefix, flush=True)
    print('PYTEST_PROJECT_VENV', Path(sys.prefix).resolve() == (Path(__file__).parents[1] / '.venv').resolve(), flush=True)
    assert answer == 42


def test_neighbor_fails():
    Path('neighbor-ran.txt').write_text('executed', encoding='utf-8')
    assert 1 == 2
