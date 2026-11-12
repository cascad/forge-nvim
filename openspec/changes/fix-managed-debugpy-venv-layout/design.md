# Design

## Context

Project adapter уже использует debugpy_adapter_in_env, managed fallback ниже
строит Windows Scripts paths напрямую. Project Python и adapter Python имеют
разные зависимости и назначение. Existing python_project ставит tools в project
venv, поэтому не изолирует эту ветку. IDE-119 пока статическое наблюдение.

## Goals / Non-Goals

**Goals:** real native managed debug без debugpy в project venv, прежние
overrides/приоритет, project interpreter, output и session lifetime.
**Non-Goals:** общий tools framework, слияние roots/interpreters, установка
на старте, LSP замена, SDK/backports/quit policy и неявное управление Docker.

## Decisions

- Сначала permanent source E2E: отдельный project venv с dependency приложения
  и managed venv с настоящим debugpy из проверенного offline wheel. PATH не
  содержит adapter, project venv не может import debugpy; private profile.
- Четыре варианта: managed launcher; launcher отсутствует, managed Python;
  explicit adapter; explicit adapter Python. В explicit controls global
  path отличается от env path, managed среда тоже готова.
- Наблюдать реальный uv.spawn argv, breakpoint/eval42, stdout project prefix
  и завершение. Не подменять resolver/upvalues/dap.run, не считать DAP pause
  подтверждением доставки независимого stdout. LSP в этом узком DAP fixture
  отключён public API; language E2E проверяет его отдельно.
- Native venv/pip подготовка до старта child, no-index/verified wheels и
  profile-local temp/cache; исходники SDK/user environments не меняются.
- До patch сохранить неизменённый source7673dd3 для native replay. При
  недоступном Linux engine Windows source/target проверяет сохранение
  поведения, Unix source RED/target остаётся отдельным обязательным gate
  перед закрытием IDE-119. Это изменение порядка работы, не сокращение scope.
  Existing venv helper переиспользовать для project/Mason; одинаковый
  executable primitive не выносить ради нескольких строк.

## Risks / Trade-offs

- Windows control PASS не доказывает Unix fallback. Linux engine сейчас
  недоступен; source/target Ubuntu и Mac остаются отдельными gates.
- Подготовка PATH должна исключить реальный adapter из всех inherited dirs;
  child exepath и отсутствие project adapter проверяются перед F5.
- Ненулевой native exit/unknown scope не скрывать; конфиг/test/fixture,
  logs/selected paths сохранять до cleanup. Source/target bytes сравнивать.
