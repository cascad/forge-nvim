# Design

## Context

SDK menu и native package recipes уже существуют. Ошибка отсутствующего менеджера сейчас неотличима от прочих InvalidInput. SDK discovery после установки умеет читать Windows registry paths; Mac стандартные Homebrew bin ещё не учитываются. SDK нельзя упаковывать внутрь IDE или ставить без выбора пользователя.

## Goals / Non-Goals

**Goals:** отдельное предложение отсутствующего менеджера, повторная проверка результата, отдельное SDK confirmation, переиспользование стандартных путей и native PTY регресс.

**Non-Goals:** собственный пакетный менеджер/SDK manager, ремонт APT/WSL/Docker, настройка shell profile, публикация release inventory, настоящая установка SDK на машине агента. Полный macOS acceptance выполняется владельцем.

## Decisions

- Отдельный небольшой `sdk_bootstrap` составляет native Recipe только при ErrorKind::NotFound. Существующий manager с ошибкой не переустанавливается. Общий runner сохраняет stdout/stderr и exit в собственный лог.
- Windows: официальный Microsoft.WinGet.Client из PSGallery в CurrentUser, отсутствующий NuGet provider также CurrentUser. Уже установленный модуль переиспользуется. Repair-WinGetPackageManager без AllUsers и prerelease. Не менять доверие репозитория или execution policy системы.
- macOS: официальный Homebrew/install script по фиксированному commit e5b3c5834e3932c8aaa42deef4794076c9b0cbf0, загрузка curl по HTTPS с проверкой ошибки перед запуском штатным bash. Сохраняется интерактивность официального установщика, включая sudo/CLT. Его stdout/stderr попадают в общий лог. Версия manager не равна зафиксированным версиям будущих formulae.
- Повторный discovery использует PATH, WindowsApps alias или /opt/homebrew/bin, /usr/local/bin. В metadata kit сохраняются только проверенные SDK directories, а не manager/profile configuration.
- E2E использует native fixture PowerShell/bash, который пишет trace и создаёт fixture manager в отдельном stand. Настоящие host SDK/package managers не вызываются. Native Mac flow есть в том же тесте, его выполнение здесь не заявляется.

## Risks / Trade-offs

- Bootstrap требует сети и штатных привилегий; ошибки возвращаются пользователю вместе с логом, без скрытых обходов.
- Homebrew/PSGallery/GitHub и формулы меняются независимо. Pin installer script делает команду воспроизводимой, но не фиксирует все пакеты менеджера.
- Повреждённый существующий manager и unsupported macOS/Windows versions требуют действий владельца; exit0 сам по себе не доказывает готовность.
