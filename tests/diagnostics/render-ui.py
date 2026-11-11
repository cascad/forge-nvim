"""CLI экспорта raw native UI в переносимые SVG/HTML без графических пакетов."""
from pathlib import Path
import argparse
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
from ui_grid import export

parser = argparse.ArgumentParser()
parser.add_argument("capture", type=Path)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
try:
    frames = export(args.capture, args.output)
except (ValueError, OSError, KeyError, TypeError) as error:
    parser.exit(2, f"UI export failed: {error}\n")
print(f"Exported {len(frames)} native UI checkpoints to {args.output}")
