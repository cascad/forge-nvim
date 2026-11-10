# Design

## Context

См. proposal.md и WINDOWS_PROCESS_DIAGNOSTICS. Docker caller неизвестен. Proc.c pinned revision 4b35336f6f850ce68a230716401cdaa21bdb6a25 и installed SDK остаются прежними.

## Goals / Non-Goals

**Goals:** воспроизводимое conditional доказательство native traversal и проверка небольшого creation-time guard prototype; read-only аудит реальных process records.

**Non-Goals:** естественный PID reuse через массовый churn, доказательство caller двух Docker событий, изменение SDK/production, полный Neovim E2E или новый process manager.

## Decisions

- Read-only Python probe использует Toolhelp и query-only handles/GetProcessTimes, не импортирует termination APIs. Kernel records отмечаются отдельно; неполные metadata не объявляются stale edge.
- Native harness компилирует точный fragment proc.c, сравнивает source SHA с pinned checkout. Snapshot ограничен тремя собственными workers под anonymous Job Object; root создаёт настоящего child, older worker создаётся раньше root.
- В stale case одна parent edge в snapshot заменена на root PID; это модель documented stale PPID, не изменение системного metadata. Native OpenProcess/TerminateProcess wrappers допускают только три held собственных PID. Creation times и завершение — настоящие Win32 API.
- Guard prototype применяется только к частной копии fragment: descendants разрешены лишь при успешных time queries и child creation >= parent creation. Положительный case обязателен, иначе «никого не завершаем» ошибочно выглядел бы fix.
- Четыре cases: valid edge, stale edge, child time query failure, root time query failure. API failures инъектируются только внутри fixture. Workers ограничены 60 s и закрываются Job Object при любом исходе.

## Risks / Trade-offs

- Controlled snapshot не доказывает реальный PID reuse/Neovim caller → явно сохранять mode, source hash, modified edge и native lifecycle; Docker attribution остаётся открытой.
- Компилятор/worker crash → create suspended, assign Job до resume, bound wait и local report; чужие PID не допускаются native wrapper.
- Windows-only ABI → Linux/macOS CLI явно сообщает ограничение; production других ОС не затрагивается.
