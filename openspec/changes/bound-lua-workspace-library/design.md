# Design

## Context

См. proposal/FIXLOG260. Закреплённый nvim-lspconfig lsp/lua_ls.lua рекомендует on_init + VIMRUNTIME, предупреждая о runtimepath library. Используем этот штатный механизм.

## Goals / Non-Goals

Устранить доказанный лишний preload, сохранить Neovim API и project settings.
Не менять LuaLS/Neodev/pins/SDK, не добавлять новый сервер/library resolver,
не обещать20s для произвольного большого пользовательского проекта.

## Decisions

- В существующий vim.lsp.config lua_ls добавить on_init: корень workspace_folders[1].name, native fs_stat для двух project config names; если есть — вернуть без library injection. Иначе library={vim.env.VIMRUNTIME}.
- Удалить unconditional nvim_get_runtime_file('',true). Нет отдельного discovery/cache/условного Windows кода.
- Существующий installed Core observer проверяет actual project settings/diagnostic/edit/save/restart. Отдельные library controls используют тот же настоящий client и config, не fake LSP.

## Risks / Trade-offs

- Неявные plugin API types больше не индексируются в каждом Lua проекте → нужные project libraries явно задаются пользователем в .luarc; default сохраняет Neovim runtime API.
- Native Ubuntu Core input пока не assembled → подготовить только текущие реальные IDE inputs в existing bounded container; если их нет, пометить native gate, не подменять сервер.

## Migration Plan

Изменение применяется при restart LuaLS/редактора. Обычный startup ничего не устанавливает. No baseline sync/archive.
