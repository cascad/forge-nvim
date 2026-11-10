# Tasks

## 1. Клавиатурный Peek

- [x] 1.1 Добавить native peek-navigation E2E и Go fixture для закрытия, references, Enter/splits, типов/реализаций и фокуса; получить RED q/E21 на исходном config Windows.
- [x] 1.2 Удалить mappings override; проверить все сценарии нового E2E на Windows с настоящим gopls и неизменными исходниками.
- [x] 1.3 Обновить клавиши Peek в docs/tests/roadmap, записать FIXLOG с `Спека: IDE-PANEL-9 (FIX)`, HISTORY и команды; проверить Git diff и append-only историю.

## 2. Интеграция

- [x] 2.1 Прогнать peek-navigation, go-language, editor и outline на Windows/Ubuntu последовательно; проверить native artifacts/логи и повтор исходной project диагностики.
- [x] 2.2 Выполнить unit/trace, strict OpenSpec validation и review diff; сохранить результаты и закоммитить проверенный шаг.
- [ ] 2.3 Прогнать те же native сценарии на macOS, сохранить результат; до фактического прогона gate открыт, change не архивируется.
