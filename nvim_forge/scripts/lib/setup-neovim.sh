# spec: IDE-BOOT-9. Общий explicit setup Mac/Linux; без daily startup hooks.
forge_setup_neovim() (
  local install_path="$1" stage
  case "$install_path" in /*) ;; *) install_path="$PWD/$install_path";; esac
  [ -f "$install_path/init.lua" ] && [ -f "$install_path/scripts/setup-stage.lua" ] || {
    printf 'Installed profile/setup stage not found: %s\n' "$install_path" >&2; exit 1;
  }
  XDG_CONFIG_HOME="$(dirname -- "$install_path")"
  NVIM_APPNAME="$(basename -- "$install_path")"
  export XDG_CONFIG_HOME NVIM_APPNAME
  export FORGE_SETUP_CONFIG="$install_path"
  cd "$HOME"
  for stage in plugins parsers tools; do
    printf '\n==> Preparing %s\n' "$stage"
    local preinit='lua vim.opt.rtp:prepend(vim.env.FORGE_SETUP_CONFIG)'
    if [ "$stage" = tools ]; then preinit="$preinit; require('forge.setup_sdks').prepare()"; fi
    nvim --headless -i NONE --cmd "$preinit" -u "$install_path/init.lua" \
      -l "$install_path/scripts/setup-stage.lua" "$stage" || exit "$?"
  done
)
