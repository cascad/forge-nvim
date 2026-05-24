# nvim-ide based Neovim distribution

Minimal, idiomatic Neovim 0.10/0.11+ setup built on `ldelossa/nvim-ide` as
the panel framework. No custom orchestration layer — every plugin is
configured through its own `lazy.nvim` spec and talks to the rest of the
ecosystem through public commands/events.

## Layout

```
nvim-ide/
├── init.lua                  # leader keys, providers, requires
├── lua/
│   ├── config/               # pure-vim configuration (no plugin deps)
│   │   ├── options.lua       # vim options + diagnostic config
│   │   ├── keymaps.lua       # editor keymaps
│   │   ├── autocmds.lua      # highlight on yank, last-loc, q-to-close, ...
│   │   └── lazy.lua          # lazy.nvim bootstrap + import plugins/
│   └── plugins/              # one spec file per concern, leaf-level
│       ├── colorscheme.lua   # tokyonight (moon)
│       ├── ide.lua           # nvim-ide framework + panel keymaps
│       ├── lsp.lua           # mason + nvim-lspconfig + per-server settings
│       ├── completion.lua    # blink.cmp + friendly-snippets
│       ├── treesitter.lua    # nvim-treesitter (+ context, textobjects)
│       ├── telescope.lua     # telescope + fzf-native
│       ├── git.lua           # gitsigns + diffview + neogit + git-conflict
│       ├── dap.lua           # nvim-dap + dap-ui + mason-nvim-dap + adapters
│       ├── test.lua          # neotest + rust/go/python adapters
│       ├── format.lua        # conform.nvim
│       ├── ui.lua            # lualine, bufferline, which-key, noice, trouble
│       ├── editor.lua        # autopairs, surround, comment, todo, flash
│       ├── tasks.lua         # overseer task runner
│       ├── search.lua        # grug-far
│       └── start.lua         # project.nvim + persistence.nvim + alpha
└── README.md
```

## Running

Prefer the bundled launcher from the repo root — no env vars to set
manually, state stays isolated:

```cmd
nvim-ide.cmd
```

Or explicitly, side-by-side without touching the main config:

```powershell
$env:NVIM_APPNAME = "nvim-ide"
$env:XDG_CONFIG_HOME = "<repo-root>"   # папка, в которую склонирован этот репозиторий
nvim
```

> The legacy name of this config was `nvim2`. The launcher creates a
> one-time directory junction `nvim-ide-data → nvim2-data` on first
> run so plugins/Mason data is reused without copying. Once both
> directories exist, the junction step does nothing.

First launch will install everything via `lazy.nvim` + `mason`. Expect
some delay while `rust-analyzer`, `gopls`, etc. are downloaded.

## Panel model (nvim-ide)

Three panels, each owns a *PanelGroup* (a stack of Components):

| Panel       | Group     | Components                                                              |
| ----------- | --------- | ----------------------------------------------------------------------- |
| `left`      | explorer  | Explorer, Outline, BufferList, Bookmarks, CallHierarchy, TerminalBrowser |
| `right`     | git       | Changes, Commits, Branches, Timeline                                    |
| `bottom`    | terminal  | TerminalBrowser                                                         |

By default every group starts with **one** component visible (Explorer
on left, Changes on right). Sibling components are unhidden on demand via
the `<leader>t*` / `<leader>g*` keymaps below — same model as VSCode's
Activity Bar.

## Cheatsheet

### Panel control

| Keys          | Action                                                |
| ------------- | ----------------------------------------------------- |
| `<C-e>`       | Toggle left panel                                     |
| `<C-S-e>`     | Toggle right panel                                    |
| `<leader>e`   | Reveal Explorer (open left panel + focus)             |
| `<leader>tf`  | Left = Files (Explorer)                               |
| `<leader>to`  | Left = Outline                                        |
| `<leader>tb`  | Left = BufferList                                     |
| `<leader>tm`  | Left = Bookmarks                                      |
| `<leader>tc`  | Left = CallHierarchy                                  |
| `<leader>gs`  | Right = Git Changes                                   |
| `<leader>gl`  | Right = Git Commits (log)                             |
| `<leader>gB`  | Right = Git Branches                                  |
| `<leader>gt`  | Right = Git Timeline                                  |
| `<leader>ts`  | Swap panel-group dialog (built-in `:Workspace SwapPanel`) |

Inside any component:
- `?` — help for that component (lists its own keymaps)
- `+` / `-` / `=` — maximize / minimize / equalize
- `q` — hide component (we remapped from default `H` to free `<S-h>`)
- `X` — close component (remove from stack until panel swap)

### Files / search

| Keys           | Action                              |
| -------------- | ----------------------------------- |
| `<C-p>`        | Find file (Telescope)               |
| `<C-S-p>`      | Command palette (Telescope commands) |
| `<leader>ff`   | Find file                           |
| `<leader>fr`   | Recent files                        |
| `<leader>fg`   | Live grep                           |
| `<leader>fb`   | Buffers                             |
| `<leader>fp`   | Recent projects (project.nvim)      |
| `<leader>fT`   | TODO comments                       |
| `<leader>sg`   | grug-far find/replace               |
| `<leader>ss`   | Live grep                           |
| `<leader>sw`   | Grep word under cursor              |

### LSP (buffer-local on LspAttach)

| Keys           | Action                              |
| -------------- | ----------------------------------- |
| `gd` / `gD`    | Definition / Declaration            |
| `gr` / `gi`    | References / Implementation         |
| `gy`           | Type definition                     |
| `K`            | Hover doc                           |
| `gK`           | Signature help                      |
| `<leader>ln`   | Rename                              |
| `<leader>la`   | Code action (normal + visual)       |
| `<leader>lf`   | Format buffer                       |
| `<leader>lo`   | Aerial outline                      |
| `]d` / `[d`    | Next / prev diagnostic              |

### Git

| Keys           | Action                              |
| -------------- | ----------------------------------- |
| `]h` / `[h`    | Next / prev hunk                    |
| `<leader>ghs`  | Stage hunk (normal/visual)          |
| `<leader>ghr`  | Reset hunk                          |
| `<leader>ghp`  | Preview hunk                        |
| `<leader>ghb`  | Blame line                          |
| `<leader>gdd`  | Diffview open                       |
| `<leader>gdf`  | File history (current file)         |
| `<leader>gg`   | Neogit (tab)                        |

### Debug (DAP)

| Keys           | Action                              |
| -------------- | ----------------------------------- |
| `<leader>db`   | Toggle breakpoint                   |
| `<leader>dc`   | Continue / start                    |
| `<leader>di`   | Step into                           |
| `<leader>do`   | Step over                           |
| `<leader>dO`   | Step out                            |
| `<leader>du`   | Toggle DAP UI                       |
| `<leader>dr`   | Toggle REPL                         |
| `<leader>dt`   | Terminate                           |

### Tests (Neotest)

| Keys           | Action                              |
| -------------- | ----------------------------------- |
| `<leader>rt`   | Run nearest test                    |
| `<leader>rf`   | Run all tests in file               |
| `<leader>rs`   | Run suite                           |
| `<leader>rd`   | Debug nearest (via DAP)             |
| `<leader>rS`   | Toggle summary panel                |
| `<leader>ro`   | Output (floating)                   |
| `]r` / `[r`    | Next / prev failed                  |

### Tasks (Overseer)

| Keys           | Action                              |
| -------------- | ----------------------------------- |
| `<leader>rr`   | Run task                            |
| `<leader>rT`   | Toggle task list                    |
| `<leader>rb`   | Build (default task)                |

### Sessions / projects

| Keys           | Action                              |
| -------------- | ----------------------------------- |
| `<leader>op`   | Recent projects picker              |
| `<leader>qs`   | Restore session for cwd             |
| `<leader>ql`   | Restore last session                |
| `<leader>qd`   | Don't save current session          |

## Customization

Each plugin file is self-contained. To change a behaviour, edit the
matching spec and reload (`:Lazy reload <plugin>`) — no need to touch
anything else. Cross-file references are limited to:

- `plugins/ide.lua` sets `_G.IDEShow(name)` (used by panel keymaps).
- `plugins/lsp.lua` reads capabilities from `blink.cmp`.

That's it. There is no custom "workspace controller" / "start manager" /
"keymap registry" — each concern is delegated to its plugin.
