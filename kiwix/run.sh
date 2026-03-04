#!/bin/sh
set -eu

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

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
DEFAULT_ZIM="$(read_json_string "default_zim" "")"
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
echo "[Kiwix] DEFAULT_ZIM: ${DEFAULT_ZIM}"
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

detect_kiwix_serve_bin() {
  if command -v kiwix-serve >/dev/null 2>&1; then
    command -v kiwix-serve
    return 0
  fi

  for candidate in /usr/local/bin/kiwix-serve /usr/bin/kiwix-serve /bin/kiwix-serve; do
    if [ -x "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  for dir in /usr /opt /app /bin; do
    [ -d "${dir}" ] || continue
    candidate="$(find "${dir}" -type f -name 'kiwix-serve*' -perm -111 2>/dev/null | head -n 1 || true)"
    if [ -n "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

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

KIWIX_SERVE_BIN="$(detect_kiwix_serve_bin || true)"

if [ -z "${KIWIX_SERVE_BIN}" ]; then
  echo "[Kiwix] ERROR: kiwix-serve binary not found. PATH=${PATH}"
  ls -l /usr/local/bin 2>/dev/null || true
  ls -l /usr/bin 2>/dev/null || true
  ls -l /bin 2>/dev/null || true
  sleep 30
  exit 1
fi

set -- "${KIWIX_SERVE_BIN}" --port="${PORT}"
selected_zim_count=0

if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
  if "${KIWIX_SERVE_BIN}" --help 2>&1 | grep -q -- "--username"; then
    set -- "$@" "--username=${USERNAME}" "--password=${PASSWORD}"
  else
    echo "[Kiwix] This kiwix-serve version does not support --username/--password. / Esta versao do kiwix-serve nao suporta --username/--password."
  fi
fi

while IFS= read -r dir; do
  [ -d "${dir}" ] || continue
  for zim in "${dir}"/*.zim; do
    [ -e "${zim}" ] || continue
    if [ -n "${DEFAULT_ZIM}" ]; then
      base="$(basename "${zim}")"
      if [ "${base}" = "${DEFAULT_ZIM}" ]; then
        set -- "$@" "${zim}"
        selected_zim_count=$((selected_zim_count + 1))
      fi
    else
      set -- "$@" "${zim}"
      selected_zim_count=$((selected_zim_count + 1))
    fi
  done
done <<EOF
$(iter_candidate_dirs)
EOF

if [ -n "${DEFAULT_ZIM}" ] && [ "${selected_zim_count}" -eq 0 ]; then
  echo "[Kiwix] ERROR: default_zim='${DEFAULT_ZIM}' nao encontrado nos diretorios selecionados."
  sleep 20
  exit 1
fi

echo "[Kiwix] Starting: $* / Iniciando: $*"
exec "$@"
