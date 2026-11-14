# spec: IDE-BOOT-10. Bash3.2, без Python/JSON parser до установки.
FORGE_PROFILE_TABLE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)/components.tsv"
forge_profile_has() { case ",$1," in *,"$2",*) return 0;; *) return 1;; esac; }
forge_select_profile() {
  local profile="$1" selected="$2" explicit="$3" id label deps tools parsers key rest index=0 i found changed
  local ids=() labels=()
  while IFS=$'\t' read -r id label deps tools parsers; do
    if [ "$label" != '-' ]; then ids[${#ids[@]}]="$id"; labels[${#labels[@]}]="$label"; fi
  done < "$FORGE_PROFILE_TABLE"
  if [ "$explicit" != 1 ]; then
    selected="$(IFS=,; printf '%s' "${ids[*]}")"
    if [ "$profile" = custom ]; then
      if ! { exec 3<>/dev/tty; } 2>/dev/null; then
        printf 'Interactive terminal required for Custom; use --components.\n' >&2; return 1
      fi
      while :; do
        printf '\033[2J\033[HSelect components: arrows/j/k, Space, Enter; Esc/q cancels\n' >&3
        for ((i=0;i<${#ids[@]};i++)); do
          key=' '; rest=' '; [ "$i" -ne "$index" ] || key='>'
          if forge_profile_has "$selected" "${ids[$i]}"; then rest=x; fi
          printf '%s [%s] %s\n' "$key" "$rest" "${labels[$i]}" >&3
        done
        IFS= read -r -s -n 1 key <&3 || return 1
        case "$key" in
          '') break;;
          q) printf 'Installation cancelled.\n' >&2; exec 3>&-; return 1;;
          $'\033')
            rest=''; IFS= read -r -s -n 2 -t 1 rest <&3 || :
            case "$rest" in '[A') key=k;; '[B') key=j;; *) printf 'Installation cancelled.\n' >&2; exec 3>&-; return 1;; esac;;
        esac
        case "$key" in
          j) index=$(((index+1)%${#ids[@]}));;
          k) index=$(((index+${#ids[@]}-1)%${#ids[@]}));;
          ' ')
            id="${ids[$index]}"
            if [ "$id" != core ]; then
              if forge_profile_has "$selected" "$id"; then
                rest=''; for label in "${ids[@]}"; do
                  if [ "$label" != "$id" ] && forge_profile_has "$selected" "$label"; then rest="${rest:+$rest,}$label"; fi
                done; selected="$rest"
              else selected="${selected:+$selected,}$id"; fi
            fi;;
        esac
      done
      exec 3>&-
    fi
  fi
  selected="${selected:+$selected,}core"
  local requested IFS=,
  for requested in $selected; do
    found=0
    while IFS=$'\t' read -r id label deps tools parsers; do [ "$id" != "$requested" ] || found=1; done < "$FORGE_PROFILE_TABLE"
    [ "$found" = 1 ] || { printf 'Unknown component: %s\n' "$requested" >&2; return 1; }
  done
  changed=1
  while [ "$changed" = 1 ]; do
    changed=0
    while IFS=$'\t' read -r id label deps tools parsers; do
      if forge_profile_has "$selected" "$id" && [ "$deps" != '-' ]; then
        for requested in $deps; do
          if ! forge_profile_has "$selected" "$requested"; then selected="$selected,$requested"; changed=1; fi
        done
      fi
    done < "$FORGE_PROFILE_TABLE"
  done
  rest=''
  while IFS=$'\t' read -r id label deps tools parsers; do
    if forge_profile_has "$selected" "$id"; then rest="${rest:+$rest,}$id"; fi
  done < "$FORGE_PROFILE_TABLE"
  printf '%s\n' "$rest"
}
forge_component_enabled() {
  if [ -n "${FORGE_NVIM_COMPONENTS:-}" ]; then forge_profile_has "$FORGE_NVIM_COMPONENTS" "$1"; return; fi
  case "$1" in core|terminal) return 0;; go|go-runtime|rust|python) [ "${WITH_LANGUAGES:-0}" = 1 ];; *) return 1;; esac
}
