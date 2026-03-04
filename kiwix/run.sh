#!/bin/sh
set -e

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
SCRIPT_VERSION="1.1.10"

OPTIONS_FILE="/data/options.json"
BUNDLED_ZIM_DIR="/opt/kiwix/zims"
LIBRARY_FILE="/data/library.xml"
ZIM_LIST_FILE="/tmp/kiwix-zims.txt"
NGINX_CONF_FILE="/tmp/nginx.conf"
BACKEND_PORT="18080"

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
PORT="8080"
USERNAME="$(read_json_string "username" "")"
PASSWORD="$(read_json_string "password" "")"

echo "[Kiwix] ZIM_DIR: ${ZIM_DIR}"
echo "[Kiwix] PORT: ${PORT}"
echo "[Kiwix] SCRIPT_VERSION: ${SCRIPT_VERSION}"

if [ ! -d "${ZIM_DIR}" ]; then
  echo "[Kiwix] Directory ${ZIM_DIR} does not exist. Creating... / Diretorio ${ZIM_DIR} nao existe. Criando..."
  mkdir -p "${ZIM_DIR}"
fi

collect_zim_files() {
  : > "${ZIM_LIST_FILE}"

  if [ -d "${ZIM_DIR}" ]; then
    find "${ZIM_DIR}" -type f -name '*.zim' -print >> "${ZIM_LIST_FILE}" 2>/dev/null || true
  fi

  if [ -d "${BUNDLED_ZIM_DIR}" ]; then
    find "${BUNDLED_ZIM_DIR}" -type f -name '*.zim' -print >> "${ZIM_LIST_FILE}" 2>/dev/null || true
  fi

  if [ -s "${ZIM_LIST_FILE}" ]; then
    sort -u "${ZIM_LIST_FILE}" -o "${ZIM_LIST_FILE}" || true
  fi
}

has_any_zim() {
  collect_zim_files
  [ -s "${ZIM_LIST_FILE}" ]
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

detect_kiwix_manage_bin() {
  if command -v kiwix-manage >/dev/null 2>&1; then
    command -v kiwix-manage
    return 0
  fi

  for candidate in /usr/local/bin/kiwix-manage /usr/bin/kiwix-manage /bin/kiwix-manage; do
    if [ -x "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

build_library_xml() {
  kiwix_manage_bin="$1"
  rm -f "${LIBRARY_FILE}"
  library_add_successes=0
  library_add_failures=0

  while IFS= read -r zim; do
    [ -n "${zim}" ] || continue
    if "${kiwix_manage_bin}" "${LIBRARY_FILE}" add "${zim}" >/dev/null 2>&1; then
      library_add_successes=$((library_add_successes + 1))
    else
      library_add_failures=$((library_add_failures + 1))
      echo "[Kiwix] WARNING: Failed to add ZIM to library: ${zim}"
    fi
  done < "${ZIM_LIST_FILE}"

  echo "[Kiwix] Library add summary: success=${library_add_successes} failed=${library_add_failures}"
}

library_has_entries() {
  [ -s "${LIBRARY_FILE}" ] || return 1
  grep -Eq "<(entry|book)\\b" "${LIBRARY_FILE}" 2>/dev/null
}

detect_nginx_bin() {
  if command -v nginx >/dev/null 2>&1; then
    command -v nginx
    return 0
  fi

  for candidate in /usr/sbin/nginx /usr/bin/nginx /sbin/nginx /bin/nginx; do
    if [ -x "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

write_nginx_conf() {
  cat > "${NGINX_CONF_FILE}" <<EOF
worker_processes 1;
error_log /dev/stdout info;
pid /tmp/nginx.pid;

events {
  worker_connections 1024;
}

http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  sendfile on;
  access_log /dev/stdout;

  server {
    listen ${PORT};
    server_name _;

    location / {
      set \$ingress_path \$http_x_ingress_path;

      proxy_http_version 1.1;
      proxy_set_header Connection "";
      proxy_set_header Host \$host;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_pass http://127.0.0.1:${BACKEND_PORT};
      proxy_redirect ~^(/.*)\$ \$ingress_path\$1;
      proxy_buffering off;

      sub_filter_once off;
      sub_filter_types text/html text/css application/javascript;
      sub_filter 'href="/' 'href="\$ingress_path/';
      sub_filter 'src="/' 'src="\$ingress_path/';
      sub_filter 'action="/' 'action="\$ingress_path/';
      sub_filter 'content="/' 'content="\$ingress_path/';
      sub_filter 'url(/' 'url(\$ingress_path/';
    }
  }
}
EOF
}

# Wait for at least one .zim file (mounted or bundled) before starting kiwix-serve.
# Aguarda pelo menos um arquivo .zim (montado ou embutido) antes de iniciar o kiwix-serve.
while :; do
  if has_any_zim; then
    break
  fi

  echo "[Kiwix] No .zim found in ${ZIM_DIR}. Waiting 30s... / Nenhum .zim encontrado em ${ZIM_DIR}. Aguardando 30s..."
  sleep 30
done

KIWIX_SERVE_BIN="$(detect_kiwix_serve_bin || true)"
KIWIX_MANAGE_BIN="$(detect_kiwix_manage_bin || true)"
NGINX_BIN="$(detect_nginx_bin || true)"

if [ -z "${KIWIX_SERVE_BIN}" ]; then
  echo "[Kiwix] ERROR: kiwix-serve binary not found. PATH=${PATH}"
  ls -l /usr/local/bin 2>/dev/null || true
  ls -l /usr/bin 2>/dev/null || true
  ls -l /bin 2>/dev/null || true
  sleep 30
  exit 1
fi

if [ -z "${NGINX_BIN}" ]; then
  echo "[Kiwix] ERROR: nginx binary not found. PATH=${PATH}"
  ls -l /usr/sbin 2>/dev/null || true
  ls -l /usr/bin 2>/dev/null || true
  sleep 30
  exit 1
fi

echo "[Kiwix] Found kiwix-serve at: ${KIWIX_SERVE_BIN}"
if [ -n "${KIWIX_MANAGE_BIN}" ]; then
  echo "[Kiwix] Found kiwix-manage at: ${KIWIX_MANAGE_BIN}"
else
  echo "[Kiwix] WARNING: kiwix-manage not found."
fi
echo "[Kiwix] Found nginx at: ${NGINX_BIN}"

set -- "${KIWIX_SERVE_BIN}" --port="${BACKEND_PORT}"

if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
  if "${KIWIX_SERVE_BIN}" --help 2>&1 | grep -q -- "--username"; then
    set -- "$@" "--username=${USERNAME}" "--password=${PASSWORD}"
  else
    echo "[Kiwix] This kiwix-serve version does not support --username/--password. / Esta versao do kiwix-serve nao suporta --username/--password."
  fi
fi

if [ -n "${KIWIX_MANAGE_BIN}" ]; then
  build_library_xml "${KIWIX_MANAGE_BIN}"

  if [ "${library_add_successes}" -gt 0 ] && library_has_entries; then
    set -- "$@" --library "${LIBRARY_FILE}"
  else
    echo "[Kiwix] WARNING: library.xml is empty or invalid, falling back to direct ZIM list mode."
    while IFS= read -r zim; do
      [ -n "${zim}" ] || continue
      set -- "$@" "${zim}"
    done < "${ZIM_LIST_FILE}"
  fi
else
  echo "[Kiwix] WARNING: kiwix-manage not found, using direct ZIM list mode."
  while IFS= read -r zim; do
    [ -n "${zim}" ] || continue
    set -- "$@" "${zim}"
  done < "${ZIM_LIST_FILE}"
fi

echo "[Kiwix] Starting backend: $* / Iniciando backend: $*"
"$@" &
KIWIX_PID="$!"

sleep 1
if ! kill -0 "${KIWIX_PID}" 2>/dev/null; then
  echo "[Kiwix] ERROR: kiwix-serve backend exited early."
  wait "${KIWIX_PID}" || true
  sleep 30
  exit 1
fi

write_nginx_conf
echo "[Kiwix] Starting ingress proxy: ${NGINX_BIN} -c ${NGINX_CONF_FILE} (listen ${PORT} -> backend ${BACKEND_PORT})"
exec "${NGINX_BIN}" -c "${NGINX_CONF_FILE}" -g "daemon off;"
