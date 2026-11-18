# Verification — 2026-11-18

## Actual installed kit

Новый runtime режим existing check-installed-languages.py запускает программы/
Neotest через настоящий Default config/runtime. SDK/IDE packages не fixtures.
Pytest явно ставится offline в project venv из готовых wheels; Jest зависимости
копируются в sample project. Это обычные test dependencies проекта.

## Initial observer corrections

Windows1795021148030794400 (223.76s), Ubuntu1795021147210439842 (158.79s):
ошибки самого observer. DAP frame/config могут содержать functions, не передаваемые
RPC; сохраняются только scalar fields. Rust evaluate нужен context=watch, а не
REPL command. У Neotest нет state.results; используются публичные status_counts/
output_panel. Node имеет один default и стартует без picker.

Следующий affected packet Windows1795021398534799100/Ubuntu1795021374297111198:
Go полностью PASS11.95s/6.45s. Rust повторно останавливался внутри println! macro;
fixture получил отдельную executable line перед macro. Python marker переносился
в узкой terminal panel: сравнивается logical text без soft line breaks. Jest
должен быть объявлен в package.json, одного node_modules недостаточно. Это test
corrections, config/DAP/adapters продукта не менялись.

## Latest evidence

| Язык | Windows case / секунды | Ubuntu case / секунды | Результат |
|---|---|---|---|
| Go | 1795021398534799100 /11.95 | 1795021374297111198 /6.45 | DAP breakpoint/eval42/continue/output + Neotest/output PASS |
| Python | 1795021637269502600 /3.88 | 1795021646219251251 /2.12 | То же PASS |
| Node | 1795021648604025400 /7.04 | 1795021651022978569 /2.48 | То же PASS |
| Rust | 1795021572505905300 | 1795021583051946952 | DAP PASS, Tests FAIL |

Only failed Rust/Python/Node cases повторялись, Go не повторялся. Windows foreach
redirection diagnostic command записал вывод в exec session22349, а отдельный `>`
после цикла дал shell ERROR; сами Python/Node child processes exit0 и reports
сохранены. Это shell invocation defect, не отказ продукта и не потеря evidence.

Rust Default не имеет nextest: native `cargo nextest --version` fail-fast controls
Windows1795021897789713600/Ubuntu1795021906588619233. С готовым nextest0.9.151,
добавленным только в PATH test stand, controls Windows1795021899751500900/
Ubuntu1795021907230132461 запускают native runner, но root-level answer_test в
main.rs пропускается. Pinned neotest-rust для main.rs/lib.rs file run задаёт
filter /^tests::/; actual nextest сообщает0 tests/1 skipped. Это отдельный
product bug, а не повод объявить Rust matrix зелёной или менять тест на mod tests.

Владелец2026-11-18 выбрал обычный CARGO_HOME/bin для nextest, official upstream,
reuse/preserve existing version и custom path. Доставка/проверка nextest и root
file filter будут product change; этот test-only change их не исправляет.

## Bounds

Raw reports/process logs/cleanup/screens сохранены в Windows stand §285 и
host `.tests/ubuntu/default-acceptance/linux-x64/fride-default-f3fzzdaq/installed-workflows`.
Все исправления этой фазы только в diagnostics. Общий full не повторялся;
Mac/WSL/cold SDK/publication остаются gates. Rust Tests пока FAIL.

Export первоначально пытался скопировать и временные project venv: Windows
отказал в создании Linux symlink. Повтор copytree reports упёрся в chmod metadata
на bind mount. Итог —249 regular reports/logs через copyfile без projects/chmod.
Две команды удаления неполного host project export отклонены automatic review
(`blocked by policy`); остаток в F evidence не удалён и отмечен для очистки.
Свой preparation container пока нужен для следующего product fix; запись commands195
о его removal описывала предполагаемый cleanup, он ещё не выполнен.
