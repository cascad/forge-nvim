# Design

## Context

См. proposal.md. `state` хранит выбранные ID, registry знает реальную видимость.
Windows final source: 13 отказов и 1 control настоящего editor E2E, включая
CodeLLDB/PTY двух вкладок. Компенсационный
close в controls закрывает лишь текущую панель и не помогает layout/toggle.

## Goals / Non-Goals

**Goals:** один владелец явных переходов, существующий реестр backend,
подхват штатных окон без нового состояния или event loop.

**Non-Goals:** новое API/менеджер окон, перенос геометрии из Edgy,
перепись DAP lifecycle, выбор/создание code window, удаление legacy cleanup
не зарегистрированных popup/session buffers, изменение current-view q терминала.

## Decisions

- Refresh сохраняет выбранный видимый ID; иначе находит видимый по registry.
  Несколько штатных окон одного слота сводятся к одному только явным Show;
  пассивный current() не закрывает окна. При неоднозначности порядок ID уже
  определён registry.list. last_shown сохраняет выбранное для toggle.
- Закрытие слота проходит по видимым зарегистрированным компонентам. Точечный
  hide закрывает только свой backend и очищает лишь собственный intent.
  Show принимает открытый target и закрывает остальных; layout использует
  те же операции. Прямое повторное закрытие из controls удаляется.
- Neo-tree close получает явный source. DAP Terminal open/close ограничиваются
  текущей вкладкой как его is_open; процессы/PTY остаются у backend.
- Activities используют state для зарегистрированных компонентов; fallback
  для legacy/popups сохраняется там, где контракт шире registry.
  Отказ: единая таблица всех FT и перенос guard/main/layout в новый manager.

## Risks / Trade-offs

- Поздние backend callbacks → прежние requested/source guards и Outline E2E.
- Закрытие соседней вкладки → настоящий tab boundary E2E, explicit source close.
- Потеря работы → paused Go/Rust DAP и live terminal E2E, без mocks backend.
- Больше visibility checks при переходе → конечный существующий registry,
  без периодического опроса и без установки tools.
