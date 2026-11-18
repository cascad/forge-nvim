# Proposal

## Why

IDE-TEST-10 regression из §273 включает install-core-acceptance.test.py, но
scripts/test-batch.py формирует для него bare argv. Скрипту нужны --kit/--profile
либо --editor-deps/--runtime; без них полный прогон неизбежно падает на argparse.

## What Changes

- Явно описать подготовленные Core inputs в плане: installed kit/profile либо
  native source inputs. Сформировать правильные аргументы существующего suite.
- Показать missing inputs в dry plan, а actual batch остановить до любых тестов
  с exit2 и отчётом, не скрывая suite и не скачивая входы автоматически.
- Добавить быстрый CLI regression и docs/history; editor E2E не повторять.

## Capabilities

### New Capabilities

- `regression-core-inputs`: IDE-TEST-11 — Core prerequisites полного batch.

### Modified Capabilities

Нет IDE main specs; расширяется контракт текущего batch без изменения suite.

## Impact

test-batch.py, batch unit, TESTING_WORKFLOW/roadmap/история. Frontend SDK/Core
ordering — отдельный ожидающий решения владельца вопрос, сюда не входит.
