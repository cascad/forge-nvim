# Proposal

## Why

IDE-147: первый Python F5 без venv выбрал сломанный MSYS2 python3.exe из PATH,
хотя python.exe работает. SDK завершился с No module named encodings, debugpy
ждал launcher, затем появились adapter timeout и Press ENTER. В lab с venv
Python/Go/Rust прошли. Прежние Python E2E задавали venv/overrides и пропустили
типичный запуск простого файла с неоднозначным PATH.

## What Changes

- Windows Auto использует python перед python3, как native installer discovery.
  Explicit paths, active/project venv и POSIX порядок сохраняются.
- Current Python file перед запуском DAP асинхронно проверяет выбранный SDK
  существующим runtime_sdk.probe; непригодный SDK отменяет запуск через ABORT.
- Короткое уведомление и полная причина в общих Logs; нет silent SDK replacement,
  установки tools или ожидания adapter timeout.
- Реальные F5 E2E без project venv/override и с explicit broken SDK, включая
  recovery после исправления пути. Исправление доставляется в установленный kit
  только при совпадении его файлов с исходной версией, с backup.

## Capabilities

### New Capabilities

- `python-auto-launch-runtime`: IDE-PY-3 — Auto PATH и проверка Current File SDK.

### Modified Capabilities

Нет. Старые IDE-PY-1/2, launch.json и managed adapter paths сохраняются.

## Impact

forge.python, forge/dap/python и current-file config; native Python E2E,
история/roadmap/guide. SDK/config/PATH пользователя не переписываются.
