# Хотелки и идеи на будущее

Не плагины ради плагинов — а конкретные UX-боли и желания. Когда
дозреет до реализации — переносим из «Open» в «Done» с ссылкой на
коммит/файл.

---

## Open

(пока пусто)

---

## Done

### 1. Recent projects picker

**Реализовано:** `lua/plugins/editor.lua` → `ahmedkhalf/project.nvim`
+ telescope-extension.

**Биндинги:**
* `<leader>fp` — Files: recent projects (внутри группы Files)
* `<leader>op` — Open: recent project (alias для VS Code-style привычки)
* Команда: `:Telescope projects`

**Что делает:**
* Автодетект project root по маркерам: `.git`, `Cargo.toml`, `go.mod`,
  `pyproject.toml`, `package.json`, `setup.py`, `.project-root`,
  `Makefile`.
* History всех посещённых проектов хранится в
  `%LocalAppData%\nvim-data\project_nvim\projects_history`.
* При выборе из picker'а — меняет глобальный cwd; Telescope/neo-tree/
  все pickers сразу работают в новой папке.

**Не реализовано (намеренно):**
* `<C-S-o>` (как в VS Code) — в большинстве TUI неотличим от `<C-o>`
  без Kitty Keyboard Protocol / CSI u. Когда мигрируем на терминал с
  поддержкой (WezTerm/Kitty с extended keys), можно добавить.
* Авто-сохранение сессии текущего проекта перед сменой — пока ручками
  через `<leader>qd` (don't save) / `<leader>qs` (load) из persistence.

**Удалить из проектов:** в picker'е выделить запись и нажать `d`.
