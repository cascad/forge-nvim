# Design

## Context

Мотивация и исходный RED — proposal/Why, FIXLOG §146. Pinned nvim-dap-go
сохраняет строку delve.path при setup; native DAP executable.command тоже
ожидает строку. Передавать функцию вместо path как неподдерживаемый трюк нельзя.
GoVersion сейчас ждёт фиксированные 300ms, а version() сам запускает запрос:
это допускает второй процесс и показ неизвестной версии до завершения первого.

## Goals / Non-Goals

**Goals:**
- Отделить чистое чтение metadata от явного асинхронного действия.
- Выбирать Delve по текущему окружению только на публичной границе DAP adapter.
- Проверять реальные процессы и клавиши в native редакторе, не fake SDK output.

**Non-Goals:**
- Менять готовый gopls/root detection, глобально GOTOOLCHAIN/GOENV или установщики.
- Исправлять zsh до nvim, Glance/Outline, вводить свой LSP/adapter backend.
- Менять pins, правила выбора версии Delve или Go build/test/debug configs.

## Decisions

1. Label/version() только читают последний явно полученный cache. До запроса
   label показывает выбранный GOTOOLCHAIN; при отсутствии env — default, потому
   что настоящий Go может брать настройки из GOENV. Мы не читаем его OS paths.
   Фоновый запрос с принудительным local отвергнут: это другая версия, чем SDK
   проекта, и всё ещё лишний subprocess от UI.
2. refresh(callback) запускает ровно один настоящий async Go version на явное
   действие. Callback получает исходные cwd/toolchain; GoVersion уведомляет по
   завершении, без фиксированного таймера. Cache привязан к cwd/GOTOOLCHAIN/
   PATH/GOENV; номер запроса защищает от старых результатов. Это состояние
   существующего helper, не новая система резолверов.
3. nvim-dap-go настраивается штатно с default path. Его публичный adapter
   callback оборачивается один раз: при launch результат копируется, command
   заменяется текущим resolve_dlv_path, прочие поля/port/options сохраняются.
   Исходный upstream closure не мутируется. Сам resolver и version ranking
   остаются прежними. Поддерживаемый callback предпочтительнее private patch
   плагина и неподдерживаемой функции в command.
4. Native E2E изолирует PATH без gopls для metadata-only случая, использует
   настоящий Go с offline future module и отдельно настоящий Delve/breakpoint.
   Поздний ответ версии воспроизводится удержанием доставки уже реального
   завершённого результата, а не заменой CLI/LSP ответа.

## Risks / Trade-offs

- До явного действия label показывает режим, а не автоматически узнанную версию.
  Это явная цена пассивности; GoVersion остаётся доступен и обновляет label.
- Готовый gopls может сам обращаться к Go для языка. Metadata-only assertion
  отделяет его от наших UI/DAP процессов; обычный language regression обязателен.
- Adapter callback должен сохранить port/args и test launch поведение:
  проверить реальные debug/Output/nearest tests на Windows/Ubuntu.
- Mac не доступен в этой сессии: код общий, native gate остаётся открытым.
