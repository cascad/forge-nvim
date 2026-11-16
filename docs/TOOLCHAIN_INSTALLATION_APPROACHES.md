# Установка и обновление языковых инструментов

Черновик для обсуждения. Работа остановлена по просьбе владельца 2026-11-16.
Завтра продолжить этот документ; схему установки до обсуждения не менять.

## Что нужно описать

Для Go, Rust, Python, JS/Node.js, Bash и SQL: отдельно SDK/окружение проекта,
LSP, отладчик, форматтеры, линтеры и тестовые runners; способы установки и
обновления на Windows/macOS/Ubuntu, зависимости и принятые подходы редакторов.

## Уже установленные факты

- Противопоставление «готовые инструменты или Mason» слишком грубое. Mason
  использует разные providers: готовые assets, npm, pip и сборку через Go.
- Go-расширение VS Code вызывает go install и в окружении установки задаёт
  GOTOOLCHAIN=auto. Go может штатно скачать компилятор для этой операции.
- В нашем explicit setup сейчас GOTOOLCHAIN=local и проверка Go1.26+ для
  сборки pinned Go tools. Это текущее поведение, не согласованная будущая схема.
- Нужно разделять Go для сборки gopls, Go для работы с проектом и версию языка
  проекта. Один успешный пример с Go1.23.3 не доказывает полную совместимость.
- Rust-расширение VS Code поставляет rust-analyzer. Rustup управляет SDK и
  компонентами; выбор проекта задаётся в том числе rust-toolchain.toml.
- Python: окружение проекта и окружение debugpy могут быть разными. Наш Pyright
  требует Node; его нельзя незаметно выдавать за часть Python SDK.
- JS/TS: VS Code использует tsserver через встроенное расширение; Neovim может
  использовать typescript-language-server. Это разные интеграции одной экосистемы.
- Bash: language server требует Node; ShellCheck/shfmt и Bash debugger отдельны.
  Для нашего Bash debug на Windows используется WSL2.
- SQL: общего SDK нет. Нужны выбранная СУБД/подключение, подходящий сервер языка,
  форматтер и средства выполнения запросов. Наш patched sqls — отдельный случай.

## Источники для продолжения

- [VS Code Go установка tools](https://github.com/golang/vscode-go/blob/master/extension/src/goInstallTools.ts)
- [VS Code Go окружение установки](https://github.com/golang/vscode-go/blob/master/extension/src/goEnv.ts)
- [Go toolchains и автоматический выбор](https://go.dev/doc/toolchain)
- [Gopls и совместимость версий](https://go.dev/gopls/)
- [Mason](https://github.com/mason-org/mason.nvim)
- [Rustup и выбор SDK](https://rust-lang.github.io/rustup/overrides.html)
- [Установка rust-analyzer](https://rust-analyzer.github.io/book/installation.html)
- [Python окружения VS Code](https://code.visualstudio.com/docs/python/environments)
- [Pyright](https://github.com/microsoft/pyright/blob/main/docs/installation.md)
- [Debugpy и окружение проекта](https://github.com/mfussenegger/nvim-dap-python#debugpy)
- [TypeScript language server](https://github.com/typescript-language-server/typescript-language-server)
- [JS debugger](https://github.com/microsoft/vscode-js-debug)
- [Bash language server](https://github.com/bash-lsp/bash-language-server)
- [Bash debugger](https://github.com/rogalmic/vscode-bash-debug)
- [SQLTools и драйверы](https://github.com/mtxr/vscode-sqltools)
- [SQLs](https://github.com/sqls-server/sqls)
- [Sqruff](https://github.com/quarylabs/sqruff)

## Точка продолжения

Дополнить документ практическими процедурами по каждому языку и ОС,
сравнением обновлений/совместимости и текущим состоянием fride. Затем обсудить
общую модель с владельцем. Свои пакеты всех tools, обновление SDK и смена
политики GOTOOLCHAIN пока не выбраны и не реализуются.
