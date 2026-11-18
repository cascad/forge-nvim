# Go для сборки IDE tools

Установщик отдельно спрашивает, разрешить ли штатному Go получить более новый
compiler для сборки IDE tools. По умолчанию **Нет**; выбор действует одну операцию,
проектный SDK и настройки среды сохраняются.

Новый frontend принимает:

```text
fride-setup --source REPO --runtime-path CORE --components go --go-toolchain-download allow
fride-setup --source REPO --runtime-path CORE --components go --go-toolchain-download deny
```

Без терминала отсутствие параметра означает deny. Preview/print-plan/check не
загружают compiler даже при allow. План содержит go_toolchain_download.
Интерактивное подтверждение появляется для Go tools без CLI выбора; Esc отменяет
установку. Root entry передаёт `-GoToolchainDownload allow|deny` на Windows и
`--go-toolchain-download allow|deny` на Linux/macOS. Developer frontend собирается
scripts/build-installer-ui.py; public artifacts этой версии ещё не опубликованы,
полный публичный Default one-liner не объявлен готовым.

Probes/plugins/parsers используют GOTOOLCHAIN=local. Только tools stage получает
auto до Mason initialization. Native Go сам выбирает compiler для go install
package@version, переиспользует готовый либо получает необходимый. Это
[штатный механизм Go](https://go.dev/doc/toolchain), без downloader fride.
Для auto нужен рабочий Go1.21+. GOPROXY/GOSUMDB, GOENV, SDK homes, системный PATH
и profiles не переписываются; go env -w не вызывается. Compiler остаётся в
штатном кеше Go. Runtime проекта не наследует разрешение установки.

При deny сборка закреплённых gopls/gofumpt/golines требует доступный Go1.26+;
готовые инструменты переиспользуются. При allow guard допускает Go1.21+, нужную
пакету версию выбирает Go. Совместимость версии LSP с SDK проекта — отдельная
часть политики версий tools.

Ошибка unavailable/offline/checksum сохраняет native причину и прежний готовый
kit без retry или смены proxy/checksum policy. Общий лог указан в консоли,
tools log — INSTALL/log/setup-tools.log. Marker ready=false первой неуспешной
установки не означает публикацию. При уже захваченной другой policy Mason setup
останавливается с объяснением; закрытый кеш окружения не переписывается.

Native E2E: `python -B tests/install-go-toolchain.test.py` (Linux/macOS: python3).
Нужны подготовленные Neovim/Go/Mason и frontend, SDK не устанавливается.
Результаты и границы fixture package — в
[verification](../openspec/changes/offer-go-build-toolchain-download/verification.md).
