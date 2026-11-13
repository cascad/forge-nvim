# Design

## Context

См. proposal. Штатный bash-debug0.3.9 использует Windows Node→wsl.exe,
переводит cwd/program/source paths сам. WSL default Ubuntu уже Running2,
Bash5.2/cat/mkfifo/rm/pkill есть; Linux Node в WSL не требуется. Native
Linux/macOS запускают тот же Node adapter и Bash4+ непосредственно.

## Goals / Non-Goals

Готовый DAP, default file и launch.json, общие панели/клавиши/output. Без
собственного interpreter/bridge/path remapping протокола, установки WSL,
смены distro, debugger nearest для Bats и обещания Mac без натурной проверки.

## Decisions

- Явный preparer получает неизменённый VSIX0.3.9, SHA256
  7fc154642bf3fcfa27a903fd44235bc902d93e737939c7b411ece6fe10f5f458.
  Existing F: archive можно повторно использовать offline; ordinary startup
  не скачивает adapter и не запускает WSL. Node используется через forge.node.
- Малый forge.bash_debug отвечает за entrypoint (explicit override/Mason),
  defaults и adapter registration. Public enrich_config заполняет отсутствующие
  поля launch.json, пользовательские поля сохраняются. Node adapter detached=false.
- Windows использует default WSL distro как официальный adapter. В Linux-форму
  переводятся лишь default пути bundled bashdb; cwd/program/source переводит
  сам adapter. Ограничение upstream: /mnt/<drive>, пользовательские pathBashdb/
  pathBashdbLib доступны в launch.json. UNC/custom mounts отдельно.
- Source Ubuntu5716518719042: debugConsole workflow прошёл, но bundle
  dbg-main.sh/source.sh пытается заново открыть /dev/stdin у Node child pipe
  и пишет ENXIO. Default terminalKind=integrated + console=integratedTerminal
  используют существующий native DAP PTY/Output; собственный backend patch
  не добавляется. Явный debugConsole сохраняется как opt-in с известным
  upstream ограничением stdin. Bash4+ и
  Unix tools проверяет официальный backend при launch, не при загрузке IDE.
- Windows public initialize_timeout_sec=30 учитывает WSL launch. Первый
  source8021920639600 показал native4s warning без trace, точная фаза/длительность
  того запуска неизвестна; cold machine/distro startup этим не объявляется PASS.
- Проверяем breakpoint/scopes/evaluate/output/continue/repeat/stop и явную
  launch.json конфигурацию. Windows WSL children проверяются отдельно от Win job:
  native adapter должен завершить принадлежащие ему processes/FIFOs.

## Risks / Trade-offs

- Старый готовый adapter → no source patches; несовместимость сохраняется
  как FAIL/блокер, не пишем новый backend.
- Mac системный Bash3.2 → нужен Bash4+ с явным pathBash; Mac не объявляем PASS.
- Windows использует текущую default WSL distro → документируем, не меняем
  пользовательские системные настройки. Тесты используют уже Running Ubuntu.

## Migration Plan

Явно подготовить adapter/Mason, затем обычный F5; rollback удаляет регистрацию
и defaults, Bash run/tests продолжают использовать прежний native host.
