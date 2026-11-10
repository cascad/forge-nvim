# Design

## Context

IDE-091 и SDK исправлены отдельно. IDE-090 пока не воспроизведена повторно. Насыщенный файловый observer однажды остановился на history assertion, а лёгкий observer дал6 циклов без отказа. Нужно сохранять неуспех и уменьшить влияние observer.

## Goals / Non-Goals

Цель — получить причины, этап, native keys/actions и сырые stdout snapshots. Не увеличиваем таймауты, не меняем assertions или UI, не объявляем любой соседний баг причиной IDE-090, не перезапускаем Desktop/WSL.

## Decisions

- Helper сохраняет существующие чтения before/after/session и последний достигнутый этап через xpcall/finally; ошибка повторно выбрасывается после записи. Существующий success output-policy.jsonl сохраняется.
- Опциональный FORGE_OUTPUT_TRACE=1 устанавливает test-only observer до запуска debug: on_key, лёгкие Win events и wrappers уже загруженных публичных функций. Ограниченный буфер в памяти, сброс после попытки; режимы plugins не загружаются раньше срока ради capture. Отдельно записывается число байт, принятое nvim_input.
- Не вызываем ide.state.current из observer: он refresh-ит слоты и меняет исследуемое состояние. Снимки читают реальные окна/буферы через API.
- Native E2E проверяет capture в реальном Rust/CodeLLDB; более подробная трасса является observer run, отсутствие бага под ней не доказывает исправление.

## Open Questions

Причина исходного sidebar failure и возможное влияние padding/resize на history assertion; решаем по сохранённым before/after. Ubuntu/Mac доступны только при реальном запуске.
