@echo off
rem ============================================================
rem Launches Neovim with the nvim-ide config from this repository
rem WITHOUT touching the parent shell's environment and WITHOUT
rem copying anything into %LOCALAPPDATA%\nvim*.
rem
rem `setlocal` scopes XDG_CONFIG_HOME + NVIM_APPNAME to this
rem cmd.exe invocation only; the moment it exits, the parent
rem PowerShell/cmd session has no trace of them.
rem
rem Каталоги для этой сборки (изолированы от других конфигов
rem через NVIM_APPNAME, Neovim сам добавляет суффикс к имени):
rem   config : %~dp0nvim-ide\
rem   data   : %LOCALAPPDATA%\nvim-ide-data\
rem   state  : %LOCALAPPDATA%\nvim-ide-data\
rem   cache  : %TEMP%\nvim-ide\
rem
rem История: до 20.05.2026 эта сборка называлась "nvim2", и её state
rem жил в %LOCALAPPDATA%\nvim2-data\. Чтобы не переустанавливать
rem плагины/Mason после переименования, ниже создаётся одноразовый
rem directory junction nvim-ide-data -> nvim2-data при первом запуске
rem (если новая папка ещё не существует, а старая — есть). Junction
rem не копирует данные; nvim2-data остаётся физическим хранилищем.
rem
rem Чтобы снести ВСЁ ради этой сборки — удалить junction/папку
rem %LOCALAPPDATA%\nvim-ide-data\ и %TEMP%\nvim-ide\. Папка nvim-ide\
rem в репо при этом остаётся нетронутой.
rem ============================================================

setlocal

rem One-time migration from the previous "nvim2" name. Safe to leave forever:
rem the block does nothing once the junction (or a real directory) exists.
if not exist "%LOCALAPPDATA%\nvim-ide-data" (
    if exist "%LOCALAPPDATA%\nvim2-data" (
        echo Migrating nvim2-data -^> nvim-ide-data via directory junction...
        mklink /J "%LOCALAPPDATA%\nvim-ide-data" "%LOCALAPPDATA%\nvim2-data"
    )
)

set "XDG_CONFIG_HOME=%~dp0"
rem trim trailing backslash so XDG_CONFIG_HOME doesn't end with one
if "%XDG_CONFIG_HOME:~-1%"=="\" set "XDG_CONFIG_HOME=%XDG_CONFIG_HOME:~0,-1%"

set "NVIM_APPNAME=nvim-ide"

nvim %*

endlocal
