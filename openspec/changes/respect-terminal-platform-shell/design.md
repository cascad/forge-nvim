# Design

## Context

plugins/terminal.lua выбирает shell при чтении Lazy spec. Комментарий
обещает Windows-only pwsh preference; выражение проверяет лишь executable.
config/options.lua намеренно не меняет глобальный shell ради одного backend.
ToggleTerm использует opts.shell и настоящий termopen; общий registry/controls
управляет окнами, а не shell/job argv. Main specs описывают WezTerm shell,
это другая граница; nvim capability вводится отдельно.

## Goals / Non-Goals

**Goals:** сохранить POSIX vim.o.shell при наличии optional pwsh, сохранить
Windows preference/fallback и actual terminal process/output при hide/reopen.

**Non-Goals:** менять global shell/shellcmdflag, угадывать shell по файлу
проекта, переиспользовать WezTerm launcher policy, выбирать shell динамически
для уже живого job, добавлять shell wrapper/platform framework или новый
terminal UX, SDK/pins/setup/Docker lifecycle. Mac/GUI не объявляются PASS.

## Decisions

- Оставить OS-boundary в существующей конфигурации Terminal: pwsh preference
  зависит от win32 и executable('pwsh'); иначе vim.o.shell. Нового модуля
  для одного выражения не нужно. Остальные opts/keys/registry неизменны.
- E2E готовит PATH/SHELL до запуска редактора: Lazy opts вычисляются при
  чтении spec, менять shell после VeryLazy для проверки этого бага поздно.
- POSIX regression использует настоящий bash и private executable pwsh shim
  в PATH. Shim фиксирует свой запуск и исполняет sh; source должен реально
  выбрать неверный shell, не только отличаться Lua-таблицей. Fallback без
  pwsh использует sh. Shell command пишет файл, чтобы echo ввода в PTY не
  засчитывалось за выполненную команду.
- Extensionless pwsh fixture закреплён eol=lf в .gitattributes: иначе
  Windows checkout с autocrlf способен сломать POSIX shebang в bind mount.
- Windows preference запускает настоящий доступный pwsh; fallback использует
  private PATH без него и реальный cmd. Изменяется только окружение child.
  Не имитировать другую ОС через подмену vim.fn.has или backend функций.
- Тест проверяет public ToggleTerm config, file side effects и живой job/
  PID/channel/buffer, q/Space w T и последующую команду. Каждая платформа
  явно SKIP чужие сценарии. Source immutable2fb9f8d, Windows/Ubuntu serial.

## Risks / Trade-offs

- PATH нельзя менять на host → private env/prepare, sys tools/absolute Git
  доступны child; SDK executable передаётся абсолютным путём.
- PTY echo может выглядеть как output → actual file markers обязательны.
- pwsh не находится через exepath на конкретной Windows-машине → preference
  case явно SKIP, fallback остаётся реальным. Store alias не доказывает
  отсутствие установленного PowerShell; доступный actual exe можно добавить
  в PATH только процесса теста, без изменения host PATH/setup.
- Source FAIL не должен теряться из-за cleanup → primary error первым,
  native exit/scope artifacts отдельно. Не менять deadline ради PASS.
