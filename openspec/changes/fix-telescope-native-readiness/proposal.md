# Proposal

## Why

IDE-081: plugins/telescope.lua проверяет наличие cmake, затем скрывает ошибку
загрузки native extension. Test SDK обеих ОС фактически работали на Lua (§144),
loaded-флаг плагина не доказывал native sorting. IDE-BOOT-5 закрепляет optional
ускорение без runtime toolchain; здоровый поиск с клавиатуры остаётся ядром IDE.

## What Changes

- Убрать runtime cond по build tool, определять готовность реальной загрузкой
  закреплённого native extension; сохранять Lua fallback при отсутствии/ошибке.
- Показывать фактический sorter/причину fallback в :checkhealth forge; до
  загрузки Telescope честно показывать отсутствие выбранного runtime режима.
- Добавить явную подготовку native artifact поверх готового editor SDK через
  upstream CMake, включить его в поздний слой Ubuntu image без изменения pins.
- Native E2E готовой библиотеки без CMake, отсутствующей/повреждённой библиотеки,
  реального file/content поиска и native C scoring, health и отсутствия builds.

## Capabilities

### New Capabilities
- `search-sorter`: IDE-BOOT-5, готовность необязательного native sorter и наблюдаемый fallback.

### Modified Capabilities

Нет изменений main specs. Existing change-search-enter-accept сохраняется.

## Impact

Telescope opts/config, forge health, explicit test SDK preparation/Docker,
native E2E/registry и docs/history. Компилятор нужен только для явной сборки;
новых поисковых/LSP/backend реализаций нет. Windows/Ubuntu проверяются native,
macOS/ARM64/GUI остаются отдельными gates.
