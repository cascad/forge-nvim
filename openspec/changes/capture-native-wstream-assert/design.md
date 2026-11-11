# Design

## Context

SDK 0.12.2/Schema2/PDB закреплён; original profile содержит assert, но эмитент неизвестен. В системном LLVM liblldb.dll требует отсутствующий python310.dll. Подготовленный CodeLLDB содержит python312.dll/std library; CLI22.1.4 и lookup wstream_write по PDB проверены. Четыре native call sites требуют фактического стека, а не дополнительного guard наугад.

## Goals / Non-Goals

**Goals:** явный Windows capture `_wassert` в свежем owned процессе; held query handle, image/creation time/current-job membership, bounded wait/detach; controlled assert, normal detach и refusal чужого Job. Raw capture до появления CRT dialog.

**Non-Goals:** менять product config/SDK, отключать assert, диагностировать другие пользовательские процессы, запускать Desktop/WSL или устанавливать системный Python. Capture controlled assert не доказывает исходный caller.

## Decisions

- Использовать уже подготовленный CodeLLDB CLI и embedded Python, HOME/TEMP/log на F:. Запуск из owned Neovim наследует его process Job; scoped error mode применяется только к private launcher process и восстанавливается, user/global settings не меняются.
- LLDB Python worker сначала проверяет private runtime marker/root/token, target image/SHA/creation time и наличие target+host в точном Job fixture. Controller передаёт debugger-потомку DuplicateHandle только с JOB_OBJECT_QUERY, без права termination; foreign recipient отклоняется. Query handles удерживаются до завершения для защиты identity. PID берётся только из свежих RPC/jobpid, не из общего списка или старого crash artifact. Pilot подтвердил, что NULL/current Job выбирает вложенный Job libuv, который не включает ConPTY sibling; это не признак чужого процесса.
- Attach ставит breakpoint `_wassert`, сохраняет actual thread frames/phase и завершает только assertion target после записи capture. При обычном stop request выполняется detach; liveness подтверждается RPC. Selftest вне Job отказывает до attach и проверяет независимый fixture RPC.
- Bounded native TUI trials используют прежний workflow и исходники; parent пишет phase/input count/PIDs. Сначала контролируемая проверка observer, затем attempts по одному profile. Если оригинал не воспроизведён, записать это явно и оставить IDE-097 открытым.

## Risks / Trade-offs

Debugger меняет timing. Positive control/detach проверяют инструмент, а не исправность stream lifecycle. First failure и выбранный SDK сохраняются. Windows-only диагностическая граница явно отделена от общей Lua сборки; native Ubuntu/Mac результаты не заявляются.
