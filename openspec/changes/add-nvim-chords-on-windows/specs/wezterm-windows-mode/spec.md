## MODIFIED Requirements

### Requirement: WT-WIN-2 Выход из режима
Терминал SHALL выключать режим WINDOWS по Esc, по Enter и по повторному Ctrl+Shift+Space; нажатая для выхода клавиша MUST NOT доходить до программы.
Платформы: все
История: FIXLOG 2026-08-01 «WezTerm: leader → липкий модальный режим WINDOWS», FIXLOG «WezTerm: режимы WINDOWS и RESIZE модальные», FIXLOG «WezTerm + nvim_forge: сочетания nvim_forge на Windows через подмену клавиш»
Проверка: tests/wezterm/windows-mode.test.lua (windows-mode: выходы из режима) | вручную (windows, macos; результат — в записи FIXLOG «WezTerm: режимы WINDOWS и RESIZE модальные»)

Выход — только Esc и Enter без модификаторов; Esc, Enter и Ctrl+Shift+Space снимают только верхний слой режима (WT-WIN-11). Команды режима и сочетания терминала, которые открывают экран поверх панели, тоже выключают режим, и раньше, чем экран откроется (WT-WIN-19). Ещё WINDOWS и RESIZE гаснут, когда WezTerm заново применяет конфиг к окну: перечитывание конфига (WT-LOAD-14), смена шрифта в окне (WT-STATE-6, WT-STATE-7), смена темы ОС.

#### Scenario: Esc
- **GIVEN** режим WINDOWS включён, в панели nvim в режиме вставки
- **WHEN** пользователь нажимает Esc
- **THEN** режим WINDOWS выключается, ввод снова идёт в nvim
- **AND** nvim этот Esc не получил и остался в режиме вставки

#### Scenario: Enter
- **GIVEN** режим WINDOWS включён, в шелле набрана команда
- **WHEN** пользователь нажимает Enter
- **THEN** режим выключается
- **AND** команда в шелле не выполнена: Enter до шелла не дошёл

#### Scenario: Тумблер
- **GIVEN** режим WINDOWS включён
- **WHEN** пользователь снова нажимает Ctrl+Shift+Space
- **THEN** режим выключается, второй слой режима не создаётся

#### Scenario: Enter с модификатором — не выход
- **GIVEN** режим WINDOWS включён, в панели nvim
- **WHEN** пользователь нажимает Shift+Enter, а на macOS и Linux ещё и Ctrl+Enter
- **THEN** режим остаётся включённым, а сочетание проглатывается: nvim его не получает (WT-WIN-4)
- **AND** Ctrl+Shift+Enter — сочетание терминала: делает сплит (WT-PANE-1), режим остаётся включённым, и его 5 секунд отсчитываются заново (WT-WIN-3)
- **AND** на Windows Ctrl+Enter — сочетание терминала (подмена WT-KEYS-10): режим остаётся включённым, nvim_forge получает свою подменную клавишу, программа без объявления — исходное нажатие

#### Scenario: Перечитывание конфига и смена шрифта
- **GIVEN** режим WINDOWS или RESIZE включён
- **WHEN** пользователь нажимает Ctrl+Shift+R, Ctrl+= или Ctrl+- (на macOS также Cmd+= или Cmd+-), либо сохраняет wezterm.lua в редакторе
- **THEN** режим выключается, бейдж гаснет
- **AND** следующая клавиша уходит в программу
