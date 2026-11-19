# Проверка IDE-BOOT-52 — 2026-11-19

Статус §293: OS step проверен на Windows/Ubuntu; clean Default/repeat/Go
подтверждены в §292, оставшиеся cold Rust и actual async/cancel/retry завершены
ниже. Все задачи реализации закрыты. Omarchy — отдельный IDE-143, её установка
и acceptance пока не реализованы; native Mac/GUI/publication остаются gates.

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


## §293 — завершение Rust/async и IDE-144

Новый стенд .tests/cold-install/1795094839579981700: та же pinned Ubuntu24.04,
2CPU/3GiB, реальные archives/frontend/root entry, native profile без SDK/cache.
Source f33cd4a1b303f56dc644473ae58a0b004dbcd6476cee5de62e32f0697ef1c596.
Default/font/startup/deferred baseline и первые Go/Rust notices PASS.
archive доступен; security endpoint дал warning APT update, пакетный manager
завершился, repositories/mirrors/TLS policy не менялись.

Явный Rust prepare поставил build-essential, official rustup/Rust1.100.0,
rustfmt/rust-src; следующий шаг official cargo-nextest и Mason tools ready.
Первый UI driver дважды подтвердил redraw одного SDK review и попал в ручной
путь nextest. Original failure сохранён; остановлен exact own frontend PID7093.
Драйвер теперь ждёт завершения активного review. Только Rust prepare retry
прошёл; SDK/version/signatures отражены в reports, повтор не скрывает первый отказ.

Installed LSP/diagnostics/navigation/format и run/debug breakpoint/eval/output/
Tests Rust PASS. Go предыдущего checkpoint не повторялся: это отдельное evidence,
а не утверждение шести языков cold на одной версии source.

Новый actual async observer нашёл продуктовый IDE-144: Rustup executable symlink
rustc раскрывался в rustup. Native prepare успешно писал ready, но hub version
probe отвергал basename и показывал SDK ready=false. SDK resolver теперь
canonicalizes parent и сохраняет имя leaf executable. CLI использует обычный
upstream proxy; basename validation не ослаблена для произвольного rustup файла.

Исправление доставлено через настоящий root bootstrap/archive/upgrade, без
редактирования deployed config. Candidate source
d8ccdd144bc31fd3c34cf171833121c696a9adc9908dcfe34227961a2204384e;
deployed sdk.lua SHA90422e2724775598585159ddc7a26537f923f296c0c5227b4d4d819e7012fe01.
Сохранены4 Mason receipt hashes,67 plugin pins, SDK/nextest paths+versions,
fallback metadata, preferences и ordinary Neovim guard (rust-repeat-before/after).

Actual async menu→Rust→prepare PASS: одна active task, edit/save во время работы,
ready result, cancel через public Overseer Task:stop, освобождение active и
успешный retry; версии/receipts/lock/editor PID прежние. Первые диагностические
попытки с отсутствующим Task:get_status исправлены на public task id; original
failures/report сохранены. До product fix две попытки воспроизвели false SDK
readiness; final actual-async-language-final PASS после штатного upgrade.

Registered tests/e2e/sdk-proxies.test.lua использует настоящий editor/Rustup,
native file symlinks с пробелом в пути, compiler/cargo probes и keyboard hub.
Прямой rustup executable по-прежнему отвергается. Он входит в обычный regression.
Windows: новый case SKIP EPERM (нет права file symlink), language UI4 PASS.
Ubuntu: native proxy case1 и language UI4 PASS. В новом тесте исправлены прямой
вход без recheck и snapshot symlink exclusion; Rustup binary не копируется.

Один final affected packet/OS: Windows batch1795096466773544200, Ubuntu
1795096478324949122. Только failed/affected repeats: Linux1795096700009025899
и1795096920730453859. Unit/trace: Windows19 PASS + affected trace8 PASS после
удаления unregistered diagnostic из строки Проверка; Ubuntu20 файлов PASS.
Native helper остаётся linked acceptance artifact, не unattended registry case.
Все original failures сохранены. Source code после SDK fix больше не менялся.

Regular native evidence:268 files/298231 bytes в .tests/cold-completion/native-records;
SDK/runtime/plugin trees не экспортировались. Exact cold container удаляется
после ID/owner checks; publisher сохраняется для следующего IDE-143, чтобы
переиспользовать уже поднятый стенд. Docker Desktop/WSL не запускались/не менялись.
Native Mac/Omarchy/Wayland/Windows WSL и публикация остаются отдельными gates.
