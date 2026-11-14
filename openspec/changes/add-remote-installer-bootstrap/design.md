# Design

## Context

См. proposal.md. Git clone до установки Git создаёт циклическую зависимость.
Legacy Windows/Linux remote clone также выбирает уровень монорепо вместо
nvim_forge. Local-source mode уже выбирает нужный профиль; Mac умеет работать
из полного checkout. Transport можно завершить независимо от package install.

## Goals / Non-Goals

**Goals:** Git-free source delivery, native shell dispatch, bounded staging,
repeat cache и точные коды ошибок. Windows PowerShell5.1; POSIX Bash3.2 syntax.

**Non-Goals:** полный Default/Custom menu в этом change, новый package manager,
отмена прежних platform contracts, публикация release или изменение live IDE.

## Decisions

- Windows ZIP/Invoke-WebRequest, POSIX tar.gz/curl или wget. Default source —
  codeload того же GitHub repo/ref; ArchiveUrl/SourceRoot/InstallPath позволяют
  отдельный localhost stand. Никакого Git или Python для bootstrap runtime.
- Архив сначала в private .bootstrap directory внутри SourceRoot; проверка
  единственного top directory, путей и profile/backend до dispatch. Cache key
  — SHA256 bytes архива. Reuse только после повторной проверки source structure.
  Source остаётся постоянным: Mac config/WezTerm могут ссылаться на него.
- Backend получает local-source и languages default; явный skip deps нужен
  локальному стенду/существующему advanced workflow. Общая Default/Custom
  component policy оформляется следующим шагом, не новым списком внутри entry.
- Stand скачивает сам entry через localhost HTTP, передаёт настоящий архив,
  исполняет shell и fixture backend. Это E2E transport, не установка SDK/IDE.
  Ошибки download/archive/backend проверяются без смены host packages/settings.

## Risks / Trade-offs

Старые installers ещё не ставят всё → новая команда пока development entry,
полная пользовательская готовность IDE-138 не заявляется. Временный Windows
SDK требует готового распространяемого artifact; пользователь не должен
собирать его руками. Mac/Homebrew/CLT и Linux Neovim version — отдельные gaps.
Old source versions сохраняются ради ссылок/backup; одинаковый archive не
размножается. Опубликованные команды возможны после native complete install.
