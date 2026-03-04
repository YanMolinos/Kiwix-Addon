#!/bin/sh
set -eu

OPTIONS_FILE="/data/options.json"
BUNDLED_ZIM_DIR="/opt/kiwix/zims"

read_json_string() {
  key="$1"
  default="$2"

  if [ ! -f "${OPTIONS_FILE}" ]; then
    printf '%s' "${default}"
    return
  fi

  value="$(tr -d '\r\n' < "${OPTIONS_FILE}" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p")"
  if [ -z "${value}" ]; then
    value="${default}"
  fi
  printf '%s' "${value}"
}

ZIM_DIR="$(read_json_string "zim_dir" "/share/kiwix")"
LANGUAGE="$(read_json_string "language" "all")"
PORT="8080"
USERNAME="$(read_json_string "username" "")"
PASSWORD="$(read_json_string "password" "")"

LANGUAGE="$(printf '%s' "${LANGUAGE}" | tr '[:upper:]' '[:lower:]')"
case "${LANGUAGE}" in
  all|pt|en) ;;
  *)
    echo "[Kiwix] Invalid language '${LANGUAGE}'. Using 'all'. / Idioma invalido '${LANGUAGE}'. Usando 'all'."
    LANGUAGE="all"
    ;;
esac

echo "[Kiwix] ZIM_DIR: ${ZIM_DIR}"
echo "[Kiwix] LANGUAGE: ${LANGUAGE}"
echo "[Kiwix] PORT: ${PORT}"

if [ ! -d "${ZIM_DIR}" ]; then
  echo "[Kiwix] Directory ${ZIM_DIR} does not exist. Creating... / Diretorio ${ZIM_DIR} nao existe. Criando..."
  mkdir -p "${ZIM_DIR}"
fi

if [ "${LANGUAGE}" = "all" ] || [ "${LANGUAGE}" = "pt" ]; then
  mkdir -p "${ZIM_DIR}/pt"
fi

if [ "${LANGUAGE}" = "all" ] || [ "${LANGUAGE}" = "en" ]; then
  mkdir -p "${ZIM_DIR}/en"
fi

iter_candidate_dirs() {
  case "${LANGUAGE}" in
    pt)
      printf '%s\n' "${ZIM_DIR}/pt"
      printf '%s\n' "${BUNDLED_ZIM_DIR}/pt"
      ;;
    en)
      printf '%s\n' "${ZIM_DIR}/en"
      printf '%s\n' "${BUNDLED_ZIM_DIR}/en"
      ;;
    all)
      printf '%s\n' "${ZIM_DIR}/pt"
      printf '%s\n' "${ZIM_DIR}/en"
      printf '%s\n' "${ZIM_DIR}"
      printf '%s\n' "${BUNDLED_ZIM_DIR}/pt"
      printf '%s\n' "${BUNDLED_ZIM_DIR}/en"
      printf '%s\n' "${BUNDLED_ZIM_DIR}"
      ;;
  esac
}

has_any_zim() {
  while IFS= read -r dir; do
    [ -d "${dir}" ] || continue
    for zim in "${dir}"/*.zim; do
      [ -e "${zim}" ] && return 0
    done
  done <<EOF
$(iter_candidate_dirs)
EOF
  return 1
}

# Wait for at least one .zim file (mounted or bundled) before starting kiwix-serve.
# Aguarda pelo menos um arquivo .zim (montado ou embutido) antes de iniciar o kiwix-serve.
while :; do
  if has_any_zim; then
    break
  fi

  echo "[Kiwix] No .zim found for language=${LANGUAGE}. Waiting 30s... / Nenhum .zim encontrado para language=${LANGUAGE}. Aguardando 30s..."
  sleep 30
done

set -- kiwix-serve --address=0.0.0.0 --port="${PORT}"

if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
  if kiwix-serve --help 2>&1 | grep -q -- "--username"; then
    set -- "$@" "--username=${USERNAME}" "--password=${PASSWORD}"
  else
    echo "[Kiwix] This kiwix-serve version does not support --username/--password. / Esta versao do kiwix-serve nao suporta --username/--password."
  fi
fi

while IFS= read -r dir; do
  [ -d "${dir}" ] || continue
  for zim in "${dir}"/*.zim; do
    [ -e "${zim}" ] || continue
    set -- "$@" "${zim}"
  done
done <<EOF
$(iter_candidate_dirs)
EOF

echo "[Kiwix] Starting: $* / Iniciando: $*"
exec "$@"
