#!/usr/bin/env python3
"""Пассивная диагностика IDE-001: не исполняет shell, Go или source."""

import argparse
import os
from pathlib import Path
import re
import shlex
import sys


MAX_FILES = 40
MAX_BYTES = 256 * 1024
ENV_KEYS = ("SHELL", "ZDOTDIR", "GOTOOLCHAIN", "GOSUMDB", "GOENV", "GOWORK")
PATTERNS = (
    ("GO_CALL", re.compile(r"\bgo\s+(?:env|version|install)\b")),
    ("GO_SETTING", re.compile(r"\b(?:GOTOOLCHAIN|GOSUMDB)\b")),
    ("PROMPT", re.compile(r"\b(?:starship|p10k|powerlevel10k|precmd|preexec|chpwd|PROMPT|RPROMPT)\b")),
    ("ENV_MANAGER", re.compile(r"\b(?:mise|asdf|direnv|shellenv)\b")),
)
SOURCE = re.compile(r"^\s*(?:source|\.)\s+(.+)")
DIRECTIVE = re.compile(r"^\s*(go|toolchain)\s+([A-Za-z0-9.+-]+)\s*(?://.*)?$")


def display(value):
    """Печатаем управляющие символы как текст, а не команды терминалу."""
    return str(value).encode("unicode_escape").decode("ascii")


def read_text(path):
    try:
        with path.open("rb") as stream:
            data = stream.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            return None, "больше 256 KiB; пропущен"
        return data.decode("utf-8", errors="replace"), None
    except OSError as exc:
        return None, type(exc).__name__


def source_target(expression, home, zdotdir, parent):
    # Никаких eval/expandvars: подстановки команд остаются неизвестными.
    if any(char in expression for char in ("`", "$(", "*", "?", "[", ";", "|", "&", "<", ">")):
        return None
    try:
        words = shlex.split(expression, comments=True)
    except ValueError:
        return None
    if len(words) != 1:
        return None
    word = words[0]
    for name, value in (("HOME", home), ("ZDOTDIR", zdotdir)):
        word = word.replace("${" + name + "}", str(value))
        word = re.sub(r"\$" + name + r"\b", lambda _: str(value), word)
    if "$" in word:
        return None
    if word == "~" or word.startswith("~/"):
        word = str(home) + word[1:]
    if word.startswith("~"):
        return None
    path = Path(word)
    # zsh разрешает относительные пути от cwd, не от подключающего файла.
    return path if path.is_absolute() else parent / path


def scan_profiles(home, cwd, env, emit):
    zdotdir = Path(env.get("ZDOTDIR") or home)
    roots = [home / ".zshenv"]
    roots += [base / name for base in (home, zdotdir)
              for name in (".zshenv", ".zprofile", ".zshrc", ".zlogin")]
    queue = list(roots)
    seen = set()
    while queue and len(seen) < MAX_FILES:
        path = queue.pop(0).resolve()
        if path in seen:
            continue
        seen.add(path)
        if not path.exists():
            continue
        text, error = read_text(path)
        emit("PROFILE " + display(path) + (" [" + error + "]" if error else ""))
        if error:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            location = display(path) + ":" + str(number)
            for label, pattern in PATTERNS:
                if pattern.search(line):
                    emit(location + " " + label)
            match = SOURCE.match(line)
            if match:
                target = source_target(match[1], home, zdotdir, cwd)
                if target is None:
                    emit(location + " SOURCE_DYNAMIC (нужен локальный trace)")
                else:
                    emit(location + " SOURCE -> " + display(target))
                    queue.append(target)
    if queue:
        emit("LIMIT достигнут предел обхода профилей; часть файлов не проверена")
    emit("Профили проверены статически: совпадение не доказывает выполнение строки.")


def scan_goenv(home, env, emit):
    selected = env.get("GOENV")
    if selected == "off":
        emit("GOENV off")
        return
    # Для Mac и Linux проверяем стандартные расположения без запуска go env.
    paths = [Path(selected)] if selected else [
        home / "Library/Application Support/go/env",
        Path(env.get("XDG_CONFIG_HOME") or home / ".config") / "go/env",
    ]
    for path in paths:
        if not path.is_file():
            continue
        text, error = read_text(path)
        emit("GOENV_FILE " + display(path))
        if error:
            emit("  " + error)
            continue
        for line in text.splitlines():
            if re.match(r"^(GOTOOLCHAIN|GOSUMDB)=", line):
                emit("  " + display(line))


def scan_project(cwd, env, emit):
    # Ближайшие go.mod и go.work; явный GOWORK учитываем отдельно.
    for name in ("go.mod", "go.work"):
        if name == "go.work" and env.get("GOWORK") == "off":
            emit("PROJECT go.work отключён через GOWORK=off")
            continue
        if name == "go.work" and env.get("GOWORK"):
            candidates = [Path(env["GOWORK"])]
        else:
            candidates = [base / name for base in (cwd, *cwd.parents)]
        for path in candidates:
            if not path.is_file():
                continue
            emit("PROJECT " + display(path))
            text, error = read_text(path)
            if error:
                emit("  " + error)
            else:
                for number, line in enumerate(text.splitlines(), 1):
                    match = DIRECTIVE.match(line)
                    if match:
                        emit("  " + str(number) + ": " + " ".join(match.groups()))
            break


def scan_starship(home, env, emit):
    path = Path(env.get("STARSHIP_CONFIG") or
                Path(env.get("XDG_CONFIG_HOME") or home / ".config") / "starship.toml")
    if not path.is_file():
        return
    emit("STARSHIP_CONFIG " + display(path))
    text, error = read_text(path)
    if error:
        emit("  " + error)
        return
    section = ""
    for number, line in enumerate(text.splitlines(), 1):
        match = re.match(r"\s*\[([^]]+)\]\s*(?:#.*)?$", line)
        if match:
            section = match[1]
            if section in ("golang", "go"):
                emit("  " + str(number) + ": GO_MODULE_SECTION")
        if section in ("golang", "go") and re.match(r"\s*disabled\s*=\s*true\s*(?:#.*)?$", line):
            emit("  " + str(number) + ": GO_MODULE_DISABLED")


def report(home, cwd, env, emit=print):
    emit("IDE-001 — пассивный отчёт; shell/Go/source не запускаются")
    emit("HOME " + display(home))
    emit("CWD " + display(cwd))
    for name in ENV_KEYS:
        emit(name + "=" + display(env.get(name, "<не задано>")))
    scan_profiles(home, cwd, env, emit)
    scan_goenv(home, env, emit)
    scan_project(cwd, env, emit)
    scan_starship(home, env, emit)
    emit("Результат: это кандидаты для trace, не подтверждение причины и не замер времени.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--cwd", type=Path, default=Path.cwd())
    args = parser.parse_args()
    if not args.home.is_dir() or not args.cwd.is_dir():
        parser.error("HOME и cwd должны быть существующими каталогами")
    report(args.home.resolve(), args.cwd.resolve(), os.environ)


if __name__ == "__main__":
    sys.exit(main())
