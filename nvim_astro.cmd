@echo off
rem ============================================================
rem Launches Neovim with the nvim_astro config from this repository
rem WITHOUT touching the parent shell's environment and WITHOUT
rem copying anything into %LOCALAPPDATA%\nvim*.
rem
rem `setlocal` scopes XDG_CONFIG_HOME + NVIM_APPNAME to this
rem cmd.exe invocation only; the moment it exits, the parent
rem PowerShell/cmd session has no trace of them.
rem
rem Каталоги для этой сборки (изолированы от других конфигов
rem через NVIM_APPNAME, Neovim сам добавляет суффикс к имени):
rem   config : %~dp0nvim_astro\
rem   data   : %LOCALAPPDATA%\nvim_astro-data\
rem   state  : %LOCALAPPDATA%\nvim_astro-data\
rem   cache  : %TEMP%\nvim_astro\
rem
rem Чтобы снести ВСЁ ради этой сборки — удалить папку
rem %LOCALAPPDATA%\nvim_astro-data\ и %TEMP%\nvim_astro\.
rem Папка nvim_astro\ в репо при этом остаётся нетронутой.
rem ============================================================

setlocal
set "XDG_CONFIG_HOME=%~dp0"
rem trim trailing backslash so XDG_CONFIG_HOME doesn't end with one
if "%XDG_CONFIG_HOME:~-1%"=="\" set "XDG_CONFIG_HOME=%XDG_CONFIG_HOME:~0,-1%"

set "NVIM_APPNAME=nvim_astro"

nvim %*

endlocal
