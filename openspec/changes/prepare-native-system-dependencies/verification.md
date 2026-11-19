# Проверка IDE-BOOT-52 — 2026-11-19

Статус: реализация OS dependency step проверена на Windows/Ubuntu. Чистые
Default/font/startup/repeat и последующий Go workflow прошли. Rust cold flow
и positive async prepare из редактора ещё открыты; change не архивируется.
Omarchy записана отдельным IDE-143, её установка/acceptance не реализованы.

## Реализация и affected проверки

Native inspector читает release metadata, PATH и read-only `ldconfig -p`.
Windows/macOS не выполняют Linux probes. Arch/Omarchy не направляются в APT;
готовые зависимости переиспользуются, недостающие дают явную причину. Package
catalog содержит OS requirements, не версии SDK. Default Core/Terminal не
включает Rust compiler/linker; `cc`/`ar` проверяются при explicit Rust prepare.
Native APT показывает команды, требует согласия/явной automation policy,
использует --no-upgrade/--no-remove, сохраняет repositories и проверяет итог.
Отмена130, failure/no-op и отсутствие TTY не дают ложного ready/замены kit.

Source-matched developer candidates, без замены старого .tools frontend:

- Windows SHA256 b2a37f260a9e5f9f288949517ac07b1472a4915a0d5e751756c0162765c46ce7.
- Linux SHA256 deec79b29bc216e0320aa7a0227ff45c3566c7644a38a2308d10883e12d74231.
- Native Rust unit: 2 PASS на каждой ОС (distro routing/package names).
- Windows affected batch1795088998786345500: language UI/setup paths и семь
  native suites PASS (system/languages/SDK actions/settings/Nextest/Go policy/UI).
- Ubuntu batch1795089008394062362: прежние affected suites PASS; новый system
  suite сначала обнаружил три ошибки test fixtures. Исправлены Terminal fixture
  scope, PTY ожидание лишнего final review и bootstrap PATH/повторный result.
  Только affected повторы: system-linux-retry.txt и system-linux-final.txt.
  Все 9 system cases в совокупности прошли; исходные неудачи сохранены.
- Windows system suite: 3 применимых PASS, 6 Linux-only SKIP с причинами.
- Итоговый unit+trace: 20 файлов PASS на каждой ОС. Uncovered/manual IDs не
  объявляются автоматическим покрытием. Strict/change trace/syntax/guard
  checkpoint записан в .tests/native-prerequisites; unrelated full E2E не повторялся.

Fixture suite проверяет read-only/no SDK/manager actions, automation/TTY
accept/decline/cancel, provider failure/no-op, parent/sudo env boundary,
library cache >16KiB, repeat reuse и explicit Rust scope. Контролируемые
manager/executable fixtures не считаются реальной установкой пакетов.

## Настоящая чистая Ubuntu

Команда: `python -B tests/diagnostics/check-cold-install.py --artifacts
.tests/cold-install/artifacts --publisher-container <ownID> --keep`.
Evidence: `.tests/cold-install/1795089490408203300`, source archive
84dc6fb871e9c42105913cf2999f7fb58a28ddf3b46e5c8abfba1a1cea0ab5b0.
Pinned Ubuntu24.04, 2CPU/3GiB; kit/profile/source в native owned /tmp,
на F экспортируются только reports/logs. SDK/Mason/plugin caches не копируются.

1. Baseline подтверждает отсутствие Git/Nvim/Go/Rust/Python/Node и SDK caches.
2. Реальные OS packages и Git установлены через показанный native APT шаг.
   Core/Terminal archives, 67 pinned plugins, 2 Core Mason packages подготовлены.
   Font probe, ready marker и первый запуск настоящего fride прошли.
3. После Default Go/rustc/cargo/python3/node/npm и Cargo/Rustup homes отсутствуют.
   Marker различает Core ready и шесть deferred languages.
4. Реальный repeat сохранил обе Mason receipts, plugin pins, user preferences
   и ordinary Neovim guard; SDK всё ещё отсутствуют (repeat-before/after.json).
5. Первые Go/Rust файлы смешанного проекта дали по одному local-only предложению;
   повторы не скачивали SDK (first-languages.json, tracked observer).
6. Явный native `--prepare-language go` установил official Go1.27.4 в обычный
   /root/sdk, подготовил IDE tools и записал ready result/fallback SDK path.
   GOTOOLCHAIN=local; результат prepared-go.json, UI exit0.
7. Настоящий installed fride прошёл Go LSP/diagnostics/navigation/format и
   run/debug breakpoint/eval/output/Tests через существующие observers.
   Host logs actual-go-language.txt / actual-go-runtime.txt; native observed
   reports экспортируются. Никакой подмены config/SDK/tool implementations.

## Внешний блокер и оставшиеся границы

После успешного Go prepare Ubuntu archive перестал отвечать. Попытка поставить
Python только как test harness ничего не скачала; остановлен только проверенный
PID собственного apt-get, не Docker/WSL. Python не является частью Default.
Archive недоступен и из publisher, и с host; финальный bounded probe
archive.ubuntu.com завершился `curl (28) SSL connection timeout`.
Original apt/probe logs сохранены, repositories/mirrors/TLS policy не менялись.

Без доступного APT не выполнен реальный Rust cc/build-essential → rustup →
nextest → installed LSP/format/run/debug/tests. Positive editor async prepare
с reuse также не закрыт native CLI PASS. Эти пункты остаются в tasks и linked
defer-language-environment-setup. Новые SDK/mirror managers ради стенда не создаём.
Mac/Omarchy native, Windows WSL/Bash, GUI/Wayland и публикация — отдельные gates.
После восстановления сети повторяем только оставшийся Rust/async сценарий.

## Сохранение и cleanup

Экспортированы 159 regular reports/logs (126479 bytes), без SDK/runtime/plugin
trees. Exact ID/owner/AutoRemove/resource checks выполнены перед остановкой
своих двух контейнеров, оба --rm удалены. Первый immediate inspect попал между
stop и завершением Docker auto-remove; исходный assertion сохранён, bounded
poll подтвердил удаление. Desktop/WSL и другие containers не затрагивались.
