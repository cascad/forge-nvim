# shellcheck shell=bash
# ============================================================
# Общие функции подключения для install-macos.sh и install-linux.sh
# (add-linux-installer-parity, Decision 1; fix-macos-installer, Decision 10):
# раскрытие симлинков, «путь внутри каталога», симлинк с бэкапом и
# подключение wezterm.lua. Одна копия на оба установщика — дефекты Linux
# (FIXLOG §43) были ровно от двух копий одной логики.
#
# Подключается через `.` из каталога установщика ($SCRIPT_DIR/lib). Код
# совместим с bash 3.2 (/bin/bash на macOS).
#
# Контракт вызывающего — функции:
#   step <текст>      заголовок шага;
#   info <текст>      строка вывода;
#   backup_path <p>   убрать занятый путь в бэкап (или остановиться при
#                     FORGE_NVIM_NO_BACKUP=1).
# ============================================================

# Путь с раскрытыми симлинками — и у самого файла, и у каталогов. Без
# realpath / readlink -f: их нет в старых macOS. Предел переходов —
# защита от петли симлинков.
resolve_path() {
  local p="$1" target hops=0
  while [ -L "$p" ] && [ "$hops" -lt 40 ]; do
    target="$(readlink "$p")"
    case "$target" in
      /*) p="$target" ;;
      *) p="$(dirname -- "$p")/$target" ;;
    esac
    hops=$((hops + 1))
  done
  if [ -d "$(dirname -- "$p")" ]; then
    p="$(cd -P -- "$(dirname -- "$p")" && pwd)/$(basename -- "$p")"
  fi
  printf '%s\n' "$p"
}

# Лежит ли путь $1 внутри $2 или совпадает с ним. Оба — раскрытые, с «/»
# на конце при сравнении: /repo-other не лежит внутри /repo.
path_within() {
  case "${1%/}/" in
    "${2%/}/"*) return 0 ;;
  esac
  return 1
}

# Симлинк dst → src с бэкапом. Путь, который уже ведёт в src (абсолютным
# или относительным симлинком, через симлинк на родителя), не трогаем;
# иначе занятый путь целиком — в бэкап (симлинк переносится сам), затем
# симлинк на src. src — абсолютный путь с раскрытыми симлинками.
link_with_backup() {
  local dst="$1" src="$2" label="$3"
  if { [ -e "$dst" ] || [ -L "$dst" ]; } && [ "$(resolve_path "$dst")" = "$src" ]; then
    info "$label already linked: $dst"
    return 0
  fi
  backup_path "$dst"
  mkdir -p "$(dirname -- "$dst")"
  ln -s "$src" "$dst"
  info "Linked $dst -> $src"
}

# <dst_dir>/wezterm.lua → src (WT-LOAD-4, WT-LOAD-13). Уже ведёт в репо —
# в том числе через каталог-симлинк (~/.config/wezterm -> чекаут): не
# трогаем, иначе «бэкап» унёс бы сам файл репо. Каталог-симлинк в никуда —
# в бэкап: mkdir -p на нём падал бы при каждом запуске.
link_wezterm_config() {
  local src="$1" dst_dir="$2"
  local dst="$dst_dir/wezterm.lua"
  if { [ -e "$dst" ] || [ -L "$dst" ]; } && [ "$(resolve_path "$dst")" = "$src" ]; then
    info "WezTerm config already linked: $dst"
    return 0
  fi
  if { [ -e "$dst_dir" ] || [ -L "$dst_dir" ]; } && [ ! -d "$dst_dir" ]; then
    backup_path "$dst_dir"
  fi
  link_with_backup "$dst" "$src" "WezTerm config"
}
