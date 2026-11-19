# Проверка IDE-BOOT-53

2026-11-19. Arch CLI и настоящая Omarchy — разные gates. Native desktop O1-O8
пока не пройдены. Изменение не объявляется полностью завершённым/архивным.

## Продуктовый результат

- Native pacman по release metadata, missing-only transaction/recheck, без
  sync/upgrade/AUR. Git/Node/Python fallback и common sudo boundary; APT и
  Windows/macOS recipes сохраняются.
- При наличии Mise на Arch explicit SDK prepare использует native project
  versions/options, без config/defaults/trust edits; без Mise старые providers.
- Read-only SDK probes используют project cwd, child-only Mise auto-install off;
  version/error cache разделён по root+executable. IDE-145.
- Native commands/checklist и pinned Arch stand с автоматическим собственным
  publisher; Docker Desktop/WSL не запускаются и не перенастраиваются.

## Итоговый affected packet

Один packet после реализации, далее только failed/affected cases. Полный
unrelated regression не запускался. Package fixtures — controlled native
processes, не доказательство real OS packages; Core cold и actual Mise отдельно.

| Среда | System dependencies | SDK actions | Arch cases | Editor | Quick |
|---|---:|---:|---:|---:|---:|
| Windows | 3 PASS / 6 Linux SKIP | 12 PASS / 1 Linux SKIP | 10 Arch SKIP | 4 language PASS / proxy SKIP EPERM | 20 файлов PASS |
| Ubuntu | 9 PASS | 13 PASS | 10 Arch SKIP | 4 language + 1 proxy PASS | 20 файлов PASS |
| Arch | 9 PASS | 13 PASS aggregate после affected06 | 10 PASS aggregate после affected01/07/10 | actual Mise / Core отдельно | 20 файлов PASS |

Actual Mise: official Node24.11.0 installed by native CLI, config и executable
сохранены при reuse. Python — настоящий local venv, зарегистрированный через
public mise link; native shim, отсутствующая версия второго проекта и отдельный
cache. Никаких downloads при readiness. Controlled Mise worker проверен для
Go/Rust/Python/Node: configured/default, failure/no-op/reuse и отсутствие pacman.

Legacy33dd22d SDK modules в owned fixture source дают точный RED
`Missing SDK should be reported`; current source PASS. Старый SDK probe
терял project cwd, cache был общим по executable. Product kit не подменялся.

## Исправления новых тестов

Arch fixture source перенесён с RO mount в native writable checkout. Новые
assertions исправлены под реальные Plan/pacman fields; run_process получил
optional cwd. Mise link создаёт shim сам; Python prefix сравнивается по
реальному directory, не его alias. Diagnostic result получил отдельное имя,
чтобы driver process report его не перезаписывал. Первые ошибки сохранены;
не объявляются багами продукта. Windows5 stderr runner исправлен на pwsh;
первые native command wrappers не являются проваленным продуктовым сценарием.

## Чистая установка

Первый actual Arch Core checkpoint b7db29f0/source81f53cf9:
Default/Terminal/font/startup без SDK, Core5 rounds, Custom missing path,
repeat/preservation ordinary Neovim/Mise/settings/pins/receipts — PASS (§294).
Core observer теперь различает current/history ERROR; native контроль хранит
старую ошибку и не приписывает её новой сессии.

Текущий clean replay с frontend9664c9b1/source5daa7574 через simple entrypoint
PASS (336.6 с): Default/Terminal/font/startup без SDK, Core5 rounds, Custom
missing path, repeat и native report/quick20 PASS. Inputs, baseline и результаты
сохранены в `.tests/omarchy/final-cold`; export61 regular records/135822 bytes.
После no-SDK Default harness явно создаёт обычный Python venv для проверки
сохранности SDK при Custom/repeat; SDK/cache в Default не подставляются.
До/после совпали67 plugin pins,2 Mason receipts, preferences/fallback,
Python executable/version/prefix/pyvenv.cfg; ordinary Neovim/Mise guards PASS.
Автоматически созданные target/publisher удалены. Desktop остаётся not checked.

## Артефакты и ограничения

- Windows frontend c7d8b10e, Linux frontend9664c9b1: native release builds,
  source manifests в `.tests/omarchy/frontend/windows-x64` и
  `.tests/ubuntu/omarchy/frontend/linux-x64`.
- `.tests/omarchy/windows-*`, `.tests/ubuntu/omarchy/ubuntu-*`, Arch output в
  `.tests/omarchy/arch-1795099801339130200`; отдельные source RED/affected logs.
- Native records без SDK/plugin payloads: arch-fixtures-records.tar.gz
  (863 файла/2262882 bytes), ubuntu-fixtures-records.tar.gz
  (477 файлов/1567656 bytes); exact old fixture/publisher containers удалены.
- macOS, настоящая Omarchy/Wayland/GPU/clipboard/physical hotkeys не запускались.
  [Native checklist](../../../tests/manual/omarchy.md). Публичная доставка всех
  платформ остаётся отдельным общим этапом.
