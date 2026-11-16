## MODIFIED Requirements

### Requirement: WT-LOAD-1 Один файл конфига в репо, подключается ссылкой
В режиме подключения из checkout конфиг терминала SHALL быть одним файлом `wezterm.lua` в корне репо, общим для Windows, macOS и Linux, и WezTerm MUST читать его на месте — через переменную окружения (WT-LOAD-3) или симлинк (WT-LOAD-4, WT-LOAD-13), без копии в домашнем каталоге.
Платформы: все
История: FIXLOG §19, §43

#### Scenario: правка в репо — это и есть системный конфиг
- **GIVEN** конфиг подключён одним из способов WT-LOAD-3, WT-LOAD-4, WT-LOAD-13
- **WHEN** в репо меняется `wezterm.lua`
- **THEN** WezTerm применяет изменение после перечитывания (WT-LOAD-14), синхронизировать или копировать ничего не нужно
- **AND** ни установщики, ни инструкции в шапке файла не копируют его в домашний каталог

Для отдельного установленного fride Terminal SHALL использовать snapshot того же
файла внутри kit через явный --config-file; system/user config не заменяется.

#### Scenario: Установленный fride Terminal
- **GIVEN** Terminal установлен отдельно внутри fride kit
- **WHEN** запускается fride-terminal
- **THEN** WezTerm получает явный config-file из kit
- **AND** пользовательское подключение WT-LOAD-3/4/13 остаётся прежним
