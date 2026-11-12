# Tasks

## 1. Готовность результата shell command

- [x] 1.1 Сохранить первичный Windows FAIL и воспроизвести прежний observer
  на постоянной native delayed-write fixture; source RED должен читать пустой
  файл, без подмены shell/process, root/API/scopes проверены отдельно.
- [x] 1.2 Ждать точного payload с прежним e:wait timeout; Windows cmd и Ubuntu
  bash/sh target PASS, тот же PID/channel/history и штатное завершение;
  Mac/реальный Windows pwsh не объявлять проверенными.
- [x] 1.3 Записать IDE-113 и отдельный повтор IDE-085, FIXLOG/HISTORY/commands,
  результаты общего и выбранного прогонов; проверить prefix guard/diff/strict.

## 2. Интеграция

- [x] 2.1 Завершить исходный общий Windows E2E и Ubuntu regression последних
  panel/DAP/key changes, сохранить первичный FAIL и native source identities;
  не запускать повторный общий Windows без нового обоснования.
- [ ] 2.2 Проверить native Mac и actual Windows pwsh на доступных хостах;
  сохранить результаты, не засчитывать POSIX sentinel вместо реального pwsh.
