# Проверка — Windows, 2026-11-12

Один последовательный прогон: rust-language9 PASS + dap-launch-routes1 PASS,
0 FAIL/0 SKIP. В IDE-DAP-7 реальный Cargo workspace содержит alpha_worker и
beta_worker с общей library. Cancel не создаёт marker/session; второй запуск
выбирает BETA, program basename beta_worker.exe, marker BETA, breakpoint/eval42
и stdout RUST_CHOICE_BETA42. Нет substitute metadata/DAP/UI.

Прежние default/alternate/project launch, LSP/format и nextest/debug tests
также прошли. Native10 profiles: root0/signal0/APIerrors[]/own scopes empty.
Captured dap.lua совпадает с runtime, fixture/test bytes сохранены;
profile11436853664100 содержит marker BETA и исходники.

Evidence: .tests/rust-choice-{rust-language,dap-launch-routes}.txt,
rust-choice-result.json, rust-choice-audit.json. OpenSpec strict PASS.
Runtime patch13 добавленных/9 удалённых строк, без новых зависимостей.
Это новая возможность выбора; source RED не заявляется.

Ubuntu/macOS/physical GUI/full suite не запускались. Не изменены Cargo
build policy, examples flags, SDK, pins и старые test-infra drafts.
Пользовательские WF-01..12 записаны в основном плане; частичное покрытие
не объявляется закрытием всего workflow. Перед commit — diff/prefix guards.
