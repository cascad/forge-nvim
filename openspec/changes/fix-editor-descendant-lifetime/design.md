# Design

## Context

Симптом и artifact — proposal.md. RPC transport использует `vim.system`;
`editor_process.stop` сохраняет primary error, сначала просит qa!, затем
посылает сигналы только основному child. `editor_runtime.remove` проверяет
владение и повторяет удаление 5 s. Повтор cleanup не устраняет живого orphan.
Последнее исправление SQL сохранено в eeae06c; его драйвер — source baseline.

## Goals / Non-Goals

**Goals:** управлять сроком жизни собственных процессов на системной границе,
оставить общий editor/process код переносимым, сохранить первичную ошибку и
проверяемое завершение ресурсов до удаления runtime.

**Non-Goals:** менять установленный пользовательский Neovim, выключать
rust-analyzer/clippy, вводить фонового глобального cleaner, перезапускать
Docker/WSL, исправлять независимые IDE-073/074 или считать retry их решением.

## Decisions

1. Новый test-only модуль process scope предоставляет подготовку запуска,
   attach и идемпотентное завершение. Выбор Windows/POSIX находится здесь;
   editor_rpc/editor_process вызывают общий интерфейс. Владение основано на
   собственном OS scope, а не имени executable или текущем снимке PID tree.
   Снимок процессов пропускает orphan после смерти родителя и подвержен reuse.
2. Windows: анонимный Job Object через LuaJIT FFI, без нового SDK/helper build.
   `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`, без breakaway; сохраняется handle,
   `QueryInformationJobObject` показывает active count. После выхода главного
   child оставшиеся участники завершаются через этот job, ожидается ноль active
   processes, затем handle закрывается. Kill-on-close дополнительно защищает
   от выхода самого runner. Уже существующий внешний job не заменяется:
   Windows 8+ поддерживает nested jobs; отказ attach становится launch FAIL.
3. Между spawn и assign есть гонка: простого немедленного attach недостаточно.
   Первый `--cmd` запускаемого Neovim ждёт уникальный release marker с deadline,
   ещё до observer/user init. Только после успешного assign родитель разрешает
   продолжение. Gate не устанавливает tools, не запускает фоновых процессов;
   его failure сохраняется в startup artifacts, own child и scope закрываются.
4. POSIX: `vim.system` с `detach=true` создаёт отдельную session/process group
   до исполнения child. Сохраняется PGID собственного запуска; после qa! scope
   посылает TERM этой группе, ждёт, затем при необходимости KILL. SIGSTOP/RPC
   failure остаются FAIL даже после успешного освобождения ресурсов. Сигналы
   группе runner или произвольным PID запрещены.
5. Отдельная POSIX session намеренно отделившегося backend не входит в PGID.
   Это явная граница process-group механизма, не обещание sandbox всех daemon.
   Применимые native LSP/DAP/Tests проверяются настоящими integration E2E;
   если их worker отделяется, до закрытия platform gate требуется дополнительное
   владение этим worker через его собственный lifecycle handle. Пропуск такого
   случая или успешный одиночный retry не считаются исправлением.
6. Stop сохраняет прежний verdict main child, но отдельно журналирует backend,
   число/наличие оставшихся участников, действия, ошибки и elapsed time scope.
   Scope закрывается и при уже завершившемся root, startup/RPC failure и при
   повторном stop. Ошибка scope не подменяет первичную ошибку и не превращается
   в успешный cleanup. Удаление runtime сохраняет прежние проверки marker/path.
7. Регресс использует настоящий Neovim и независимый worker, удерживающий
   реальный файл; intermediate parent завершается раньше editor. Контрольный
   чужой child вне scope продолжает работать. Рабочие процессы спят/ждут
   события, не создают CPU нагрузку. Source eeae06c driver на том же тесте
   должен показать оставшийся worker/file lock; baseline cleanup завершает
   только заранее подтверждённый собственный worker, сохранив RED verdict.
8. Нужны два уровня evidence: малые native process E2E с orphan/early exit/
   повторным stop/чужим child и настоящий editor runtime плюс полный Rust suite
   с работающим rust-analyzer/clippy/CodeLLDB. Один искусственный holder не
   доказывает совместимость scope с настоящими backend и nested ConPTY jobs.

## Risks / Trade-offs

- Неверная FFI ABI/права job → проверять официальные структуры/API и реальные
  native E2E; ни один отказ attach не скрывается fallback.
- Пропущенный процесс до assign → первый startup barrier, тест запуска из init.
- DAP/ConPTY вложенные jobs → настоящий F5 и debug test в Rust regression.
- SIGKILL root/потеря RPC reply → scope cleanup выполняется независимо от RPC.
- POSIX zombie/отделившаяся session → реальные platform artifacts; не считать
  отсутствие файла достаточным доказательством отсутствия живого worker.
- PID reuse в baseline cleanup → сохранить ownership до остановки и применять
  только подтверждённый process handle/группу, не общий поиск по имени.
- Недоступный Ubuntu engine/Mac → их tasks остаются открытыми; текущий Windows
  результат не называется универсальным PASS.

## Migration Plan

Сначала постоянный RED baseline eeae06c, затем process scope и focused GREEN,
после них editor-runtime/process и полный Rust. Проверить SQL/common panels,
unit/trace/strict и историю. Windows шаг можно коммитить отдельно с точными
границами; Ubuntu/macOS закрываются после native запусков. Откат test-only
изменений возвращает прежний driver, не меняя установленную IDE/плагины.

## Sources

- [Microsoft Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects)
- [Extended limits](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_extended_limit_information)
- [Job accounting](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_accounting_information)
- [libuv process/session](https://docs.libuv.org/en/latest/guide/processes.html)
- Локальная документация выбранного Neovim: `runtime/doc/lua.txt`, `vim.system` detach.
