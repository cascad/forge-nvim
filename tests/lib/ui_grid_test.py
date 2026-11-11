"""Векторы протокола дополняют настоящие native UI E2E."""
from pathlib import Path
import json
import tempfile
import unittest
import xml.etree.ElementTree as ET

from ui_grid import Grid, export


class GridTests(unittest.TestCase):
    def test_scroll_copies_only_the_declared_rectangle_in_both_directions(self):
        grid = Grid()
        grid.event("grid_resize", [1, 4, 3])
        for row, value in enumerate("ABC"):
            grid.event("grid_line", [1, row, 0, [[value, 0, 4]], False])
        grid.event("grid_scroll", [1, 0, 3, 1, 3, 1, 0])
        self.assertEqual([''.join(c[0] for c in row) for row in grid.cells], ['ABBA', 'BCCB', 'CCCC'])
        grid.event("grid_scroll", [1, 0, 3, 0, 4, -1, 0])
        self.assertEqual(''.join(c[0] for c in grid.cells[1]), 'ABBA')
        grid.event("grid_scroll", [1, 0, 3, 0, 4, 0, 1])
        self.assertEqual(''.join(c[0] for c in grid.cells[1]), 'BBAA')

    def test_resize_repeat_wide_utf8_and_reverse_colours_survive_export(self):
        with tempfile.TemporaryDirectory(prefix="forge-ui-grid-") as folder:
            root = Path(folder)
            record = root / "capture.jsonl"
            record.write_text(json.dumps({"kind": "redraw", "events": [
                ["default_colors_set", [0xFFFFFF, 0, 0xFFFFFF, 1, 1]],
                ["hl_attr_define", [7, {"foreground": 0xFF5733, "background": 0x112233, "reverse": True}, {}, []]],
                ["grid_resize", [1, 7, 2]],
                ["grid_line", [1, 0, 0, [["界", 7], [""], ["&"], ["<"], [" ", 0, 3]], False]],
                ["grid_resize", [1, 8, 3]], ["flush", []]]}, ensure_ascii=False) + "\n" +
                json.dumps({"kind": "checkpoint", "label": "../Ω", "metadata": {}}) + "\n", encoding="utf-8")
            frames = export(record, root / "out")
            self.assertEqual(frames[0]["cells"][0][:4], [("界", 7), ("", 7), ("&", 7), ("<", 7)])
            picture = next((root / "out").glob("*.svg"))
            parsed = ET.fromstring(picture.read_text(encoding="utf-8"))
            self.assertEqual(parsed.attrib['width'], '72')
            text = picture.read_text(encoding="utf-8")
            self.assertIn('&amp;', text)
            self.assertIn('&lt;', text)
            self.assertIn('fill="#112233"', text)
            self.assertEqual(list(root.glob('*.svg')), [])

    def test_unsupported_grid_and_undefined_highlight_fail_explicitly(self):
        grid = Grid()
        with self.assertRaisesRegex(ValueError, "single-grid"):
            grid.event('grid_resize', [2, 4, 4])
        grid.event('grid_resize', [1, 4, 4])
        with self.assertRaisesRegex(ValueError, "highlight"):
            grid.event('grid_line', [1, 0, 0, [['X']], False])
        with self.assertRaisesRegex(ValueError, "Non-text"):
            grid.event('grid_line', [1, 0, 0, [[{}, 0]], False])


if __name__ == '__main__':
    unittest.main()
