"""Восстановление single-grid RGB UI Neovim из opt-in записи redraw."""
from copy import deepcopy
from html import escape
from pathlib import Path
import json
import re


class Grid:
    def __init__(self):
        self.width = self.height = 0
        self.cells = []
        self.highlights = {0: {}}
        self.defaults = {"foreground": 0xFFFFFF, "background": 0, "special": 0xFFFFFF}
        self.cursor = None
        self.counts = {}

    def event(self, name, args):
        self.counts[name] = self.counts.get(name, 0) + 1
        if name == "default_colors_set":
            self.defaults = dict(zip(("foreground", "background", "special"), args[:3]))
        elif name == "hl_attr_define":
            self.highlights[args[0]] = args[1] if isinstance(args[1], dict) else {}
        elif name.startswith("grid_"):
            if args[0] != 1:
                raise ValueError("Only composited single-grid UI is supported")
            if name == "grid_resize":
                old = self.cells
                self.width, self.height = args[1:3]
                self.cells = [[old[row][col] if row < len(old) and col < len(old[row]) else (" ", 0)
                               for col in range(self.width)] for row in range(self.height)]
            elif name == "grid_clear":
                self.cells = [[(" ", 0) for _ in range(self.width)] for _ in range(self.height)]
            elif name == "grid_line":
                row, col, cells = args[1:4]
                attr = None
                for cell in cells:
                    if not isinstance(cell[0], str):
                        raise ValueError("Non-text grid cell")
                    if len(cell) > 1:
                        attr = cell[1]
                    if attr is None or attr not in self.highlights:
                        raise ValueError("Undefined/inherited highlight in grid_line")
                    for _ in range(cell[2] if len(cell) > 2 else 1):
                        if not (0 <= row < self.height and 0 <= col < self.width):
                            raise ValueError("grid_line outside viewport")
                        self.cells[row][col] = (cell[0], attr)
                        col += 1
            elif name == "grid_scroll":
                top, bottom, left, right, rows, cols = args[1:]
                old = deepcopy(self.cells)
                for row in range(top, bottom):
                    for col in range(left, right):
                        source_row, source_col = row + rows, col + cols
                        if top <= source_row < bottom and left <= source_col < right:
                            self.cells[row][col] = old[source_row][source_col]
                        # Освободившиеся клетки задаст последующий grid_line.
            elif name == "grid_cursor_goto":
                self.cursor = args[1:3]

    def style(self, attr):
        result = dict(self.defaults)
        result.update(self.highlights[attr])
        if result.get("reverse"):
            result["foreground"], result["background"] = result["background"], result["foreground"]
        return result

    def snapshot(self, label, metadata):
        return {"label": label, "width": self.width, "height": self.height,
                "cells": deepcopy(self.cells), "highlights": deepcopy(self.highlights),
                "defaults": dict(self.defaults), "cursor": self.cursor,
                "events": dict(self.counts), "metadata": metadata}


def read_capture(path):
    grid = Grid()
    frames = []
    with Path(path).open(encoding="utf-8") as source:
        for line in source:
            record = json.loads(line)
            if record["kind"] == "redraw":
                for batch in record["events"]:
                    for args in batch[1:]:
                        grid.event(batch[0], args)
            elif record["kind"] == "checkpoint":
                if not grid.cells or grid.counts.get("flush", 0) == 0:
                    raise ValueError("Checkpoint before a rendered UI frame")
                frames.append(grid.snapshot(record["label"], record.get("metadata", {})))
            else:
                raise ValueError("Unknown UI capture record")
    if not frames:
        raise ValueError("No UI checkpoints")
    return frames


def svg(frame, cell_width=9, cell_height=18):
    grid = Grid()
    grid.highlights = frame["highlights"]
    grid.defaults = frame["defaults"]
    width, height = frame["width"] * cell_width, frame["height"] * cell_height
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img">',
             f'<title>{escape(frame["label"])}</title>',
             '<g font-family="Cascadia Mono,Consolas,DejaVu Sans Mono,monospace" font-size="15" xml:space="preserve">']
    for row, cells in enumerate(frame["cells"]):
        col = 0
        while col < len(cells):
            start = col
            attr = cells[col][1]
            while col < len(cells) and cells[col][1] == attr:
                col += 1
            style = grid.style(attr)
            fg, bg = style["foreground"], style["background"]
            parts.append(f'<rect x="{start*cell_width}" y="{row*cell_height}" width="{(col-start)*cell_width}" height="{cell_height}" fill="#{bg:06x}"/>')
            weight = ' font-weight="bold"' if style.get("bold") else ""
            italic = ' font-style="italic"' if style.get("italic") else ""
            for offset in range(start, col):
                value = cells[offset][0]
                if value and value != " ":
                    x, y = offset * cell_width, row * cell_height
                    cx, cy, radius = x + cell_width / 2, y + cell_height / 2, min(cell_width, cell_height) / 2
                    paths = {
                        '─': f'M{x},{cy}H{x+cell_width}',
                        '│': f'M{cx},{y}V{y+cell_height}',
                        '╭': f'M{x+cell_width},{cy}H{cx+radius}Q{cx},{cy} {cx},{cy+radius}V{y+cell_height}',
                        '╮': f'M{x},{cy}H{cx-radius}Q{cx},{cy} {cx},{cy+radius}V{y+cell_height}',
                        '╰': f'M{cx},{y}V{cy-radius}Q{cx},{cy} {cx+radius},{cy}H{x+cell_width}',
                        '╯': f'M{cx},{y}V{cy-radius}Q{cx},{cy} {cx-radius},{cy}H{x}',
                    }
                    if value in paths:
                        thickness = 1.5 if style.get('bold') else 1
                        parts.append(f'<path d="{paths[value]}" fill="none" stroke="#{fg:06x}" stroke-width="{thickness}"/>')
                    else:
                        parts.append(f'<text x="{x}" y="{y+14}" fill="#{fg:06x}"{weight}{italic}>{escape(value)}</text>')
    parts.extend(["</g>", "</svg>"])
    return "\n".join(parts)


def export(path, output):
    frames = read_capture(path)
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    views = []
    for index, frame in enumerate(frames):
        picture = svg(frame)
        label = re.sub(r'[^a-zA-Z0-9_-]+', '-', frame["label"]).strip('-') or 'frame'
        (output / f'{index:02d}-{label}.svg').write_text(picture, encoding="utf-8")
        views.append(f'<section><h2>{escape(frame["label"])}</h2>{picture}</section>')
    html = '<!doctype html><html lang="ru"><meta charset="utf-8"><title>Native Neovim UI</title><style>body{font:15px system-ui;background:#11131c;color:#d9dce8;margin:24px}section{margin:0 0 32px;overflow:auto}svg{display:block;max-width:none}h2{font-size:16px}</style><body>' + "\n".join(views) + '</body></html>'
    (output / 'index.html').write_text(html, encoding="utf-8")
    (output / 'frames.json').write_text(json.dumps(frames, ensure_ascii=False), encoding="utf-8")
    return frames
