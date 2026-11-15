# Verification

## Результат

IDE-BOOT-19: SDK actions работают в native PTY, existing locations сохраняются
как fallback после caller PATH и переиспользуются на upgrade. Shared Node SDK
skip снимает Python/JS/Bash и пересчитывает closure. Install требует отдельного
confirm, failure/exit0-no-SDK возвращают к выбору. Cancel сохраняет старый kit,
SDK package остаётся standalone. NonTTY/preview/check-sdks без SDK installs.

| Среда | SDK menu | Старые controls |
|---|---|---|
| Windows |11 PASS27.891s; затем3 адресных cases PASS14.840s (усилен shared skip/WinGet alias, добавлен cancel-after-install); всего12 selectors |readiness11 PASS19.090s; delivery16 PASS69.416s; UI12 PASS/1 EPERM FAIL27.995s, после file-lock fix case10 PASS18.254s |
| Ubuntu24.04 |12 PASS7.872s |readiness10 PASS/1 platform skip6.480s; delivery16 PASS14.599s; UI13 PASS5.855s |
| Mac / реальные OS installs |Не запускались, native owner gates |Не выдаются за проверенные |

Source SDK menu RED: old frontend SDK preflight exits2 вместо menu; Windows1
FAIL12.252s и Ubuntu аналогичный native failure, raw сохранён.

IDE-BOOT-20: Windows native handle без FILE_SHARE_DELETE воспроизводит EPERM
на staged runtime. Source1 FAIL15.285s; после bounded helper2 PASS21.236s:
transient release продолжает публикацию, persistent lock даёт nonzero и
сохраняет old runtime/bin/owner и работоспособный launcher. Исходный holder
UI control не снят; тот же staging успешно переименовался после прогона.
Нет изменений SDK binaries/ACL, закрытия чужих процессов или retries на POSIX.

## Артефакты

.tests/sdk-actions-*.txt, host .tests/ubuntu/sdk-actions-*.txt; внутри
install-isolation/<id>: UI raw frames, package.tsv, SDK checks/final JSON,
sdk-install logs, result plan/sdk-paths.txt, priority.json и lock.json.
Native fixture manager никогда не вызывает настоящий winget/apt/brew.
Реальные Neovim/frontend/PTY/HTTP/venv; fixture SDK/version/package callbacks
не подменяют full language/package integration acceptance.

Windows UI latest SHA bc744c54188d41d37fe408331473e26307510ec40845d3c892f511a1d165d26a;
Linux SHA1e2bafb82f1ea9812cb06c65219fe9d4b27b851a11afeca7f8ca52a529e24aee.
Offline locked builds из существующего Rust SDK/vendor, без SDK download.

## Границы

Package manager должен существовать; bootstrap отсутствующего менеджера —
следующий clean-machine пункт. Stock version policy, не project-version picker;
basic CLI readiness, npm entrypoint presence. SDK раньше в PATH сохраняет
приоритет; broken entry не маскируется fallback. SDK packages, подтверждённые
до отмены IDE, остаются в системе. Native Mac, UAC/sudo, реальные packages и
полный release catalog/one-liner остаются owner/release gates.
Frozen24 paths и raw/staged journal prefixes — .tests/sdk-actions-audit.json.
