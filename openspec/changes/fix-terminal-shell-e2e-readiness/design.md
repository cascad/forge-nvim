# Design

## Context

См. proposal. Shell создаёт файл перенаправления до записи; observer проверяет
только filereadable, а cleanup после assertion обрывает ещё выполняющуюся команду.

## Goals / Non-Goals

**Goals:** ожидание законченного результата и постоянный native regression
границы empty-file → payload для cmd/pwsh/bash/sh.
**Non-Goals:** менять shell policy, renderer/focus/DAP, native SDK или quit
deadline. Причина отдельного IDE-085 этим изменением не устанавливается.

## Decisions

- Fixture запускается настоящей командой в текущем PTY: установленный Neovim
  создаёт пустой файл, ждёт одну секунду, пишет payload и выводит marker.
  Neovim уже обязателен для набора; новый интерпретатор или shell sleep не нужен.
- Сначала повторить с этой fixture прежнее ожидание существования файла (RED),
  затем ждать точного payload. Время ожидания e:wait прежнее, никаких retries
  целого сценария или изменений production code.
- Сохранять bytes наблюдения и fixture/test source. Проверять тот же shell PID,
  channel, history, редактирование, native exit/API/scopes; failure не скрывать.
- Отвергнут фиксированный sleep в observer: он не проверяет завершение команды.

## Risks / Trade-offs

- Quoting отличается у pwsh → использовать явный call operator для pwsh и
  абсолютные контролируемые пути; те же native E2E на Windows/Ubuntu.
- Новый child увеличивает fixture на секунду → только тестовый процесс,
  ограниченное ожидание и existing own process scope.
- Mac/реальный Windows pwsh отсутствуют → оставить непроверенные границы явными.
