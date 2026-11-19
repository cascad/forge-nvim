# Design

## Context

IDE-143 и motivation — proposal.md. Прочитаны native system.rs/sdk_install.rs/
sdk_actions.rs/sdks.rs, общий requirements catalog, bootstrap/cold diagnostic,
system fixtures и native unit routing. Main specs не содержат IDE baseline;
active IDE-BOOT-50/51/52 сохраняют deferred/ready/изоляцию и явные действия.

Upstream [Omarchy package installer](https://github.com/omacom/omarchy/blob/master/bin/omarchy-pkg-install)
использует pacman -S; готовую систему обновляет отдельный штатный workflow.
Список файлов Arch [libglvnd](https://archlinux.org/packages/extra/x86_64/libglvnd/files/)
подтверждает GL/EGL SONAME; [Python](https://archlinux.org/packages/core/x86_64/python/files/)
включает venv/ensurepip. Версии этих packages не пиним в продукте.

## Goals / Non-Goals

Goals: reuse OS packages/SDK, native pacman только для Arch family, общие
ask/install/check/error/recheck и reproducible CLI acceptance, отдельный
native desktop checklist. Ordinary Neovim/SDK/Mise/desktop configs сохраняются.

Non-Goals: установка Omarchy/Hyprland/драйверов, full system upgrade или sync DB,
AUR, новый SDK manager/Mise plugin, private SDK copies, новые LSP, изменение
Windows/macOS providers, Docker Desktop/WSL start/reconfigure. Omarchy VM/
hardware acceptance выполняется владельцем; Arch-контейнер не доказывает GUI.

## Decisions

### Native family и package transaction

Существующий bounded release parser остаётся общей Rust границей выбора Linux
family и используется OS inspector и SDK package recipes. Проверка только PATH
на наличие pacman недостаточна: foreign manager не должен менять provider.
Catalog schema1 дополняется optional pacman package names; apt сохраняется.
OS utilities/SONAME/scopes общие; package names принадлежат provider.

APT ветка прежняя. Arch — pacman -S --needed --noconfirm <missing>, без -Sy/-Syu,
repo edits и automatic recovery/update. Показанные command/source и подтверждение
frontend предшествуют действию; sudo/native argv boundary общий. Полный апгрейд
ради новой IDE отвергнут: он затрагивает все существующие программы. Устаревший
DB/keyring/mirror даёт родной log/error и совет обновить Omarchy штатно, затем
повторить. Recheck остаётся обязательным; exit0/no-op не ready.

Rust cc/ar используют base-devel только explicit Rust prepare/eager. Terminal
XCB/X11/fontconfig/Wayland/GL/EGL сопоставлены libxcb/libx11/fontconfig/wayland/
libglvnd. Core curl/unzip/tar/gzip. Transtitive dependencies решает pacman;
не обещаем абсолютную неизменность всех OS libraries при native transaction.

### SDK и Git

Linux package recipes Git/Node/Python выбирают тот же family: Arch packages
git; nodejs+npm; python (venv/ensurepip штатные). Debian/Ubuntu APT прежний.
Unknown Linux не получает APT по умолчанию. WinGet/Homebrew сохраняются.
Ready PATH/project/user/manual SDK пропускают package action, включая Mise.
Если на Arch Mise уже есть в effective PATH, явная подготовка отсутствующего
Go/Rust/Python/Node использует public mise ls/install/where. Версии и options
берёт сам Mise из текущего проекта; для ненастроенного языка используется
tool@latest. Только этот язык; без force/upgrade/use/global config и automatic
trust. Ошибка Mise не переключает установку молча на другой provider.
Без Mise прежние official Go/rustup и pacman Node/Python. SDK не часть kit.
Устанавливать/перенастраивать Mise не нужно; manual paths и selector общие.

SDK probes получают project cwd и child-only MISE_AUTO_INSTALL=false,
MISE_EXEC_AUTO_INSTALL=false, MISE_NOT_FOUND_AUTO_INSTALL=false. Версионный
cache ключ включает project root и executable: общий shim в двух проектах
может запускать разные версии. Default deferred и обычный terminal env прежние.

### Проверки и команды

После всей реализации — один affected packet Windows/Ubuntu и Arch native
fixtures/CLI. Package fixtures проверяют argv/no refresh/no upgrade, scopes,
preview/check/cancel/fail/no-op/reuse/privilege boundary; это не real package PASS.
Настоящий Arch stand использует pinned official image digest,2CPU/3GiB, native
profile и общие IDE archives/entry/frontend. Transport/test preparation явно
отделена от fride; baseline/пакеты/source/reports сохраняются. Default/Core,
custom missing path, repeat/preservation и реальные Core workflows проверяются
через существующие native observers, SDK/Mason caches не подставляются.

Дать reproducible container command и native Omarchy команды/checklist; готовые
SDK/ordinary Neovim/config guards — отдельные before/after proofs. Desktop и
Mise/project SDK acceptance отмечаются реально выполненными только на native
Omarchy; отсутствие такой машины не скрывается как Linux PASS.

## Risks / Trade-offs

- Rolling repositories/DB → native failure и штатное обновление вне fride;
  никаких partial refresh или собственного solver.
- Linux binary ABI → actual Arch Core/Terminal probe, при сбое исправлять
  genuine prerequisites/payload, не подменять runtime для теста.
- Нет Wayland/GPU в контейнере → native manual gate с простыми командами.
- Изменение common package runner → Windows/Ubuntu affected regression один раз;
  frozen SDK/old frontend/locks и append-only journals проверяются перед commit.

## Migration Plan

Новые source/installer builds несут provider/catalog; обычный kit upgrade
доставляет maintenance payload и сохраняет environment metadata/settings.
Owner/Mise/system Neovim не мигрируют. Неудачный шаг сохраняет рабочий kit;
повтор после native OS recovery использует обычный bootstrap. Общие SDK/OS
packages не удаляются при удалении частного fride.
