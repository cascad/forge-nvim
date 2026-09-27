"""Проба через conpty.dll: сочетания nvim_forge на Windows (WT-KBD-9, WT-KEYS-10;
add-nvim-chords-on-windows, design, решения 3 и 6).

Три вопроса, на которые отвечает настоящий conpty.dll из поставки WezTerm:
  A — доходит ли объявление nvim_forge (OSC 1337 SetUserVar) через ConPTY до
      терминала байт в байт;
  B — какую клавишу получает nvim от байтов подменной клавиши (K1), не
      совпадает ли она с клавишей от физического нажатия (K2), не печатает ли
      шелл мусор при зависшем объявлении (K3), одно ли у подмен правило (K4);
  C — чем повтор исходного нажатия (запись win32-input-mode через SendString)
      отличается от настоящего нажатия у трёх читателей: сырой VT-ввод,
      записи консоли, nvim.

Вывод — протокол tests/lib/check.lua: строки `  ok   <имя>`, `  FAIL <имя>  --
<причина>`, `  SKIP <имя>  -- <причина>`; код 1 при любом FAIL.

Фикстура chords.fixture.json — итог пробы: таблица «сочетание → байты →
клавиша nvim», записи исходных нажатий, множество физических клавиш,
происхождение. Сверка идёт без даты и происхождения. Обновить осознанно:
    python tests/wezterm/conpty/chords.test.py --update-fixture
Раскладка переключается руками перед запуском: --layout ru|en (по умолчанию —
активная). Не та раскладка, не Windows, нет conpty.dll — SKIP, а не PASS.
"""
import argparse
import datetime
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
FIXTURE = os.path.join(HERE, 'chords.fixture.json')

ESC = b'\x1b'
# Версия таблицы подмен — та же в wezterm.lua и nvim_forge/lua/config/wezterm_chords.lua.
TABLE_VERSION = '1'
ANNOUNCE = ESC + b']1337;SetUserVar=FORGE_NVIM=MQ==\x07'  # base64("1")
LEFT_CTRL, RIGHT_CTRL, SHIFT, LEFT_ALT = 0x8, 0x4, 0x10, 0x2

# Таблица WT-KEYS-10 по порядку строк: сочетание, lhs nvim_forge, исходное
# нажатие (vk, scan, uc, ctrl_state — как пишет WezTerm 20240203, одинаково на
# ru и en: MapVirtualKeyEx/ToUnicodeEx, проба 2026-09-27).
CHORDS = [
    ('Ctrl+Shift+F', '<C-S-f>', (70, 33, 6, LEFT_CTRL | SHIFT)),
    ('Ctrl+Shift+P', '<C-S-p>', (80, 25, 16, LEFT_CTRL | SHIFT)),
    ('Ctrl+Shift+E', '<C-S-e>', (69, 18, 5, LEFT_CTRL | SHIFT)),
    ('Ctrl+Shift+D', '<C-S-d>', (68, 32, 4, LEFT_CTRL | SHIFT)),
    ('Ctrl+Shift+F5', '<C-S-F5>', (116, 63, 0, LEFT_CTRL | SHIFT)),
    ('Ctrl+.', '<C-.>', (190, 52, 0, LEFT_CTRL)),
    ('Ctrl+Enter', '<C-CR>', (13, 28, 10, LEFT_CTRL)),
    ('Ctrl+/', '<C-/>', (191, 53, 0, LEFT_CTRL)),
    ('Ctrl+Space', '<C-Space>', (32, 57, 32, LEFT_CTRL)),
]

# Подменные клавиши — одно правило (K4): xterm F13…F20 с Ctrl (`CSI код;5~`),
# когда они кончаются — те же с Ctrl+Shift (`;6~`). F21+ ConPTY не разбирает,
# записи VK_F13+ до nvim не доходят, Alt даёт две клавиши (итог пробы B).
F13_F20 = [25, 26, 28, 29, 31, 32, 33, 34]
SUBST_RE = re.compile(rb'^\x1b\[(25|26|28|29|31|32|33|34);[56]~$')


def substitute_bytes(i):
    code, mod = F13_F20[i % len(F13_F20)], 5 + i // len(F13_F20)
    return ESC + f'[{code};{mod}~'.encode()


FKEY_SCAN = {1: 0x3B, 2: 0x3C, 3: 0x3D, 4: 0x3E, 5: 0x3F, 6: 0x40, 7: 0x41, 8: 0x42, 9: 0x43, 10: 0x44,
             11: 0x57, 12: 0x58}
FKEY_MODS = {'': 0, 'S-': SHIFT, 'C-': LEFT_CTRL, 'A-': LEFT_ALT, 'C-S-': LEFT_CTRL | SHIFT,
             'A-S-': LEFT_ALT | SHIFT, 'C-A-': LEFT_CTRL | LEFT_ALT}


def press_release(h, vk, sc, uc, cs):
    return h.win32_key(vk, sc, uc, True, cs) + h.win32_key(vk, sc, uc, False, cs)


def physical_inputs(h):
    """Множество физических нажатий для K2: F1–F12 со всеми модификаторами,
    сочетания таблицы (WT-KBD-6), буквы и цифры с Ctrl и с Alt."""
    out = []
    for m, cs in FKEY_MODS.items():
        for n, sc in FKEY_SCAN.items():
            out.append((f'{m}F{n}', press_release(h, 0x6F + n, sc, 0, cs)))
    for name, _, (vk, sc, uc, cs) in CHORDS:
        out.append((name, press_release(h, vk, sc, uc, cs)))
    scans = 'qwertyuiop' + 'asdfghjkl' + 'zxcvbnm'
    scancodes = list(range(0x10, 0x1A)) + list(range(0x1E, 0x27)) + list(range(0x2C, 0x33))
    for ch, sc in zip(scans, scancodes):
        vk = ord(ch.upper())
        out.append((f'Ctrl+{ch}', press_release(h, vk, sc, vk - 64, LEFT_CTRL)))
        out.append((f'Alt+{ch}', press_release(h, vk, sc, ord(ch), LEFT_ALT)))
    for d in range(10):
        vk, sc = 0x30 + d, 0x0B if d == 0 else 0x01 + d
        out.append((f'Ctrl+{d}', press_release(h, vk, sc, 0, LEFT_CTRL)))
        out.append((f'Alt+{d}', press_release(h, vk, sc, 0x30 + d, LEFT_ALT)))
    return out


def matches(name, id_):
    """Фильтр --id / FORGE_TEST_ID — как check.lua: 'WT-KBD' берёт capability,
    'WT-KBD-9' не захватывает ID с более длинным номером."""
    if not id_ or name == id_:
        return True
    return name.startswith(id_) and name[len(id_):len(id_) + 1] in ('-', ' ')


class Report:
    def __init__(self, id_filter=None):
        self.failed = False
        self.id_filter = id_filter

    def wanted(self, name):
        return matches(name, self.id_filter)

    def ok(self, name):
        if self.wanted(name):
            print(f'  ok   {name}', flush=True)

    def fail(self, name, why):
        if not self.wanted(name):
            return
        self.failed = True
        lines = str(why).splitlines() or ['']
        print(f'  FAIL {name}  -- {lines[0]}', flush=True)
        for extra in lines[1:]:
            print(f'      | {extra}', flush=True)

    def skip(self, name, why):
        if self.wanted(name):
            print(f'  SKIP {name}  -- {why}', flush=True)

    def check(self, name, cond, why=''):
        (self.ok(name) if cond else self.fail(name, why))
        return cond


def probe(h, r, layout):
    result = {'layout': layout}

    # --- A: объявление ------------------------------------------------------
    announce_lua = os.path.join(HERE, 'readers', 'announce.lua')
    ways = {}
    for way in ('ui_send', 'chansend'):
        with h.Session(['nvim', '--clean', '-u', 'NONE', '-i', 'NONE', '-n', '--cmd', 'luafile ' + announce_lua],
                       env={'FORGE_ANNOUNCE_WAY': way}, timeout=20) as s:
            ways[way] = s.wait_for(lambda o: ANNOUNCE in o, 8)
    result['announce'] = ways
    r.check('WT-KBD-9 объявление проходит ConPTY (nvim_ui_send)', ways['ui_send'],
            'OSC 1337 SetUserVar от nvim_ui_send не дошёл до терминала байт в байт')
    r.check('WT-KBD-9 объявление проходит ConPTY (chansend v:stderr)', ways['chansend'],
            'OSC 1337 SetUserVar от chansend(v:stderr) не дошёл до терминала байт в байт')

    # Объявление самого nvim_forge (nvim_forge/lua/config/wezterm_chords.lua):
    # FORGE_NVIM=<версия> при старте, пустое значение при :qa, с выключателем —
    # ничего. nvim_forge — из этого репо (NVIM_APPNAME + XDG_CONFIG_HOME).
    repo = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
    forge_env = {'NVIM_APPNAME': 'nvim_forge', 'XDG_CONFIG_HOME': repo}
    unset = ESC + b']1337;SetUserVar=FORGE_NVIM=\x07'
    with h.Session(['nvim'], env=forge_env, timeout=60) as s:
        started = s.wait_for(lambda o: ANNOUNCE in o, 30)
        s.settle(1.0)
        s.write(b'\x1b:qa!\r')
        left = s.wait_for(lambda o: unset in o[o.find(ANNOUNCE):], 15) if started else False
    result['forge_announce'] = {'start': started, 'exit': left}
    r.check('WT-KBD-9 nvim_forge объявляет себя при запуске (FORGE_NVIM = версия таблицы)', started,
            'OSC 1337 FORGE_NVIM от nvim_forge не пришёл за 30 с')
    r.check('WT-KBD-9 nvim_forge снимает объявление при выходе (пустое значение)', left,
            'после :qa! нет OSC 1337 FORGE_NVIM с пустым значением')
    with h.Session(['nvim', '--cmd', 'let g:forge_wezterm_chords = v:false'], env=forge_env, timeout=60) as s:
        s.wait_for(lambda o: b'NORMAL' in o or b'~' in o, 20)
        s.settle(3.0)
        quiet = b'SetUserVar=FORGE_NVIM' not in s.output()
        s.write(b'\x1b:qa!\r')
        s.settle(2.0)
        quiet = quiet and b'SetUserVar=FORGE_NVIM' not in s.output()
    result['forge_announce']['disabled_quiet'] = quiet
    r.check('WT-KBD-9 выключатель vim.g.forge_wezterm_chords = false: объявления нет', quiet,
            'с выключателем nvim_forge всё равно прислал FORGE_NVIM')

    # --- B: подменные клавиши --------------------------------------------------
    subst = [substitute_bytes(i) for i in range(len(CHORDS))]
    got = h.read_keys('nvim', subst)
    phys = physical_inputs(h)
    phys_got = h.read_keys('nvim', [b for _, b in phys], pause=0.15)
    physical_keys = sorted({k for _, keys in phys_got for k in keys})
    result['physical_keys'] = physical_keys
    rows = []
    for (chord, lhs, rec), b, (_, keys) in zip(CHORDS, subst, got):
        rows.append({'chord': chord, 'lhs': lhs, 'bytes': b.decode(), 'nvim_key': keys,
                     'original': list(rec)})
        r.check(f'WT-KEYS-10 {chord}: подмена {b[1:].decode()} даёт nvim одну клавишу (K1)', len(keys) == 1,
                f'nvim получил {keys}')
        r.check(f'WT-KEYS-10 {chord}: клавиша подмены не совпадает с физическим нажатием (K2)',
                len(keys) == 1 and keys[0] not in physical_keys,
                f'{keys} есть среди клавиш физических нажатий')
    nvim_keys = [row['nvim_key'][0] if len(row['nvim_key']) == 1 else None for row in rows]
    r.check('WT-KEYS-10 подменные клавиши попарно различны', len(set(nvim_keys)) == len(nvim_keys) and None not in nvim_keys,
            f'{nvim_keys}')
    r.check('WT-KEYS-10 одно правило подмен: xterm F13–F20 с Ctrl, затем с Ctrl+Shift (K4)',
            all(SUBST_RE.match(b) for b in subst), f'{subst}')
    result['rows'] = rows

    # K3: шелл при зависшем объявлении не печатает мусор.
    enter = press_release(h, 13, 28, 13, 0)
    with h.Session(['pwsh', '-NoLogo', '-NoProfile'], timeout=40) as s:
        s.wait_for(lambda o: b'>' in o, 20)
        s.settle(1.0)
        for b in subst:
            s.write(b)
            s.settle(0.1)
        s.write(b'echo K3MARK')
        s.settle(0.4)
        s.write(enter)
        s.settle(1.5)
        text = re.sub(rb'\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b.', b'',
                      s.output()).decode('utf-8', 'replace')
    line = next((l for l in text.split('\r\n') if 'echo K3MARK' in l), '')
    r.check('WT-KBD-9 зависшее объявление: pwsh на подменные клавиши ничего не печатает (K3)',
            line.rstrip().endswith('> echo K3MARK') or line.rstrip().endswith('>echo K3MARK'),
            f'строка ввода: {line!r}')

    # Сквозная проверка (задача 3.3): nvim_forge получает байты подмены и
    # выполняет свой lhs — в журнале после переназначения исходное сочетание.
    esc = press_release(h, 27, 1, 27, 0)
    inputs = []
    for b in subst:
        inputs += [b, esc, esc]
    forge_got = h.read_keys('nvim_forge', inputs, pause=0.6, timeout=120, env=forge_env)
    for i, ((chord, lhs, _), row) in enumerate(zip(CHORDS, rows)):
        lines = forge_got[3 * i][1]
        want = f"{row['nvim_key'][0]} -> "
        hit = [l for l in lines if l.startswith(want)]
        ok = bool(hit) and hit[0][len(want):].upper() == lhs.upper()
        r.check(f'WT-KEYS-10 {chord}: nvim_forge получает {row["nvim_key"][0]} и выполняет {lhs}', ok,
                f'журнал nvim_forge (набрано -> привязка): {lines}')

    # --- C: повтор исходного нажатия --------------------------------------------
    replay = {}
    for reader in ('nvim', 'vt', 'records'):
        inputs = []
        for _, _, (vk, sc, uc, cs) in CHORDS:
            inputs.append(press_release(h, vk, sc, uc, cs))                            # повтор (SendString)
            inputs.append(press_release(h, vk, sc, uc, (cs & ~LEFT_CTRL) | RIGHT_CTRL))  # правый Ctrl
        out = h.read_keys(reader, inputs, pause=0.2)
        per = {}
        for i, (chord, _, _) in enumerate(CHORDS):
            left, right = out[2 * i][1], out[2 * i + 1][1]
            per[chord] = {'replay': left, 'right_ctrl': right}
            if reader == 'records':
                norm = [re.sub(r'cs=(\d+)', lambda m: f'cs={(int(m.group(1)) & ~RIGHT_CTRL) | LEFT_CTRL}'
                               if int(m.group(1)) & RIGHT_CTRL else m.group(0), x) for x in right]
                same = norm == left
            else:
                same = right == left
            r.check(f'WT-KBD-9 повтор {chord} ({reader}, {layout}): отличие от нажатия — только правый Ctrl',
                    same, f'повтор {left}, правый Ctrl {right}')
        replay[reader] = per
    result['replay'] = replay
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--layout', choices=('ru', 'en'))
    ap.add_argument('--update-fixture', action='store_true')
    args = ap.parse_args()
    r = Report(os.environ.get('FORGE_TEST_ID') or None)
    if r.id_filter and not any(matches(i, r.id_filter) for i in ('WT-KBD-9', 'WT-KEYS-10')):
        return 0  # под --id нет ни одной проверки этого файла — пробу не гоняем
    import harness as h
    ok, why = h.available()
    if not ok:
        r.skip('WT-KBD-9 проба через conpty.dll', why)
        r.skip('WT-KEYS-10 проба через conpty.dll', why)
        return 0
    layout = h.keyboard_layout()
    if args.layout and args.layout != layout:
        r.skip('WT-KBD-9 проба через conpty.dll', f'активная раскладка {layout}, заявлена {args.layout}')
        r.skip('WT-KEYS-10 проба через conpty.dll', f'активная раскладка {layout}, заявлена {args.layout}')
        return 0
    if layout not in ('ru', 'en'):
        r.skip('WT-KBD-9 проба через conpty.dll', f'раскладка {layout}: проба знает только ru и en')
        return 0
    prov = h.provenance()
    result = probe(h, r, layout)

    fixture = {}
    if os.path.exists(FIXTURE):
        with open(FIXTURE, encoding='utf-8') as f:
            fixture = json.load(f)
    if args.update_fixture:
        fixture.setdefault('layouts', {})[layout] = result
        fixture['version'] = TABLE_VERSION
        fixture['provenance'] = dict(prov, date=datetime.date.today().isoformat())
        with open(FIXTURE, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(fixture, f, ensure_ascii=False, indent=2, sort_keys=True)
            f.write('\n')
        r.ok(f'WT-KEYS-10 фикстура обновлена ({layout})')
    else:
        want = (fixture.get('layouts') or {}).get(layout)
        if want is None:
            r.fail(f'WT-KEYS-10 фикстура для раскладки {layout}', f'нет в {os.path.basename(FIXTURE)}: --update-fixture')
        else:
            r.check(f'WT-KEYS-10 итог пробы совпадает с фикстурой ({layout})', want == result,
                    'проба разошлась с фикстурой: сравните --update-fixture и git diff')
            r.check('WT-KEYS-10 версия таблицы в фикстуре', fixture.get('version') == TABLE_VERSION,
                    f"в фикстуре {fixture.get('version')}, в пробе {TABLE_VERSION}")
    return 1 if r.failed else 0


if __name__ == '__main__':
    sys.exit(main())
