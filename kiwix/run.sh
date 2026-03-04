#!/bin/sh
set -e

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
SCRIPT_VERSION="1.1.24"

OPTIONS_FILE="/data/options.json"
BUNDLED_ZIM_DIR="/opt/kiwix/zims"
ZIM_LIST_FILE="/tmp/kiwix-zims.txt"
NGINX_CONF_FILE="/tmp/nginx.conf"
INDEX_FILE="/tmp/index.html"
BACKEND_PORT="18080"
INGRESS_PREFIX=""

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

echo "[Kiwix] SCRIPT_VERSION: ${SCRIPT_VERSION}"
echo "[Kiwix] Runtime UID:GID: $(id -u):$(id -g)"
echo "[Kiwix] ZIM_DIR: ${ZIM_DIR}"
echo "[Kiwix] PORT: ${PORT}"

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

detect_ingress_prefix() {
  if [ -n "${HOSTNAME:-}" ] && printf '%s' "${HOSTNAME}" | grep -q "-"; then
    printf '/api/hassio_ingress/%s' "$(printf '%s' "${HOSTNAME}" | tr '-' '_')"
    return 0
  fi

  if [ -n "${HOSTNAME:-}" ]; then
    addon_slug="${HOSTNAME#addon_}"
    if [ "${addon_slug}" != "${HOSTNAME}" ] && [ -n "${addon_slug}" ]; then
      printf '/api/hassio_ingress/%s' "${addon_slug}"
      return 0
    fi
  fi

  for candidate in "${INGRESS_ENTRY:-}" "${INGRESS_PATH:-}" "${HASSIO_INGRESS:-}" "${HASSIO_INGRESS_ENTRY:-}" "${ADDON_INGRESS:-}"; do
    if [ -n "${candidate}" ]; then
      case "${candidate}" in
        /api/hassio_ingress/*)
          printf '%s' "${candidate%/}"
          return 0
          ;;
        api/hassio_ingress/*)
          printf '/%s' "${candidate%/}"
          return 0
          ;;
      esac
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
  log_format ingress '\$remote_addr - \$remote_user [\$time_local] "\$request" \$status \$body_bytes_sent "\$http_referer" "\$http_user_agent" ingress="\$http_x_ingress_path"';
  access_log /dev/stdout ingress;

  server {
    listen ${PORT};
    server_name _;
    allow 172.30.32.2;
    deny all;

    location = / {
      default_type text/html;
      root /tmp;
      try_files /index.html =404;
    }

    location / {
      set \$ingress_path "${INGRESS_PREFIX}";
      if (\$http_x_ingress_path != "") {
        set \$ingress_path \$http_x_ingress_path;
      }

      proxy_http_version 1.1;
      proxy_set_header Connection "";
      proxy_set_header Accept-Encoding "";
      proxy_set_header Host \$host;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_set_header X-Forwarded-Prefix \$ingress_path;
      proxy_pass http://127.0.0.1:${BACKEND_PORT};
      proxy_redirect ~^/viewer#(.+)\$ \$ingress_path/content/\$1;
      proxy_redirect ~^https?://[^/]+/viewer#(.+)\$ \$ingress_path/content/\$1;
      proxy_redirect ~^https?://[^/]+(/.*)\$ \$ingress_path\$1;
      proxy_redirect ~^(/.*)\$ \$ingress_path\$1;
      proxy_buffering off;

      sub_filter_once off;
      sub_filter_types *;
      sub_filter 'type="root" href=""' 'type="root" href="\$ingress_path"';
      sub_filter "type='root' href=''" "type='root' href='\$ingress_path'";
      sub_filter 'href="/' 'href="\$ingress_path/';
      sub_filter "href='/" "href='\$ingress_path/";
      sub_filter 'src="/' 'src="\$ingress_path/';
      sub_filter "src='/" "src='\$ingress_path/";
      sub_filter 'action="/' 'action="\$ingress_path/';
      sub_filter "action='/" "action='\$ingress_path/";
      sub_filter 'content="/' 'content="\$ingress_path/';
      sub_filter "content='/" "content='\$ingress_path/";
      sub_filter 'url(/' 'url(\$ingress_path/';
    }
  }
}
EOF
}

write_index_html() {
  cat > "${INDEX_FILE}" <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Kiwix Offline Library</title>
  <style>
    :root { --bg:#111827; --card:#1f2937; --text:#f9fafb; --muted:#9ca3af; --btn:#0891b2; }
    * { box-sizing: border-box; }
    body { margin:0; font-family: Arial, sans-serif; background: linear-gradient(135deg,#0f172a,#111827); color: var(--text); }
    .wrap { max-width: 1100px; margin: 0 auto; padding: 20px; }
    h1 { margin: 0 0 8px; font-size: 28px; }
    p { margin: 0 0 18px; color: var(--muted); }
    .grid { display: grid; grid-template-columns: repeat(auto-fill,minmax(280px,1fr)); gap: 12px; }
    .card { background: var(--card); border: 1px solid #374151; border-radius: 10px; padding: 14px; }
    .name { font-size: 14px; word-break: break-word; margin-bottom: 10px; }
    .btn { display:inline-block; text-decoration:none; background: var(--btn); color:#fff; padding:8px 12px; border-radius:8px; font-weight:700; }
    .empty { padding: 14px; background:#7f1d1d; border-radius:10px; border:1px solid #991b1b; }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>Kiwix Offline Library</h1>
    <p>Click a ZIM to open content directly (without viewer iframe).</p>
    <div class="grid">
EOF

  if [ -s "${ZIM_LIST_FILE}" ]; then
    while IFS= read -r zim; do
      [ -n "${zim}" ] || continue
      base="$(basename "${zim}")"
      book="${base%.zim}"
      safe_name="$(printf '%s' "${base}" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
      cat >> "${INDEX_FILE}" <<EOF
      <div class="card">
        <div class="name">${safe_name}</div>
        <a class="btn" href="content/${book}">Open</a>
      </div>
EOF
    done < "${ZIM_LIST_FILE}"
  else
    cat >> "${INDEX_FILE}" <<'EOF'
      <div class="empty">No .zim files found.</div>
EOF
  fi

  cat >> "${INDEX_FILE}" <<'EOF'
    </div>
  </div>
</body>
</html>
EOF
}

while :; do
  if has_any_zim; then
    break
  fi

  echo "[Kiwix] No .zim found in ${ZIM_DIR}. Waiting 30s... / Nenhum .zim encontrado em ${ZIM_DIR}. Aguardando 30s..."
  sleep 30
done

KIWIX_SERVE_BIN="$(detect_kiwix_serve_bin || true)"
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
echo "[Kiwix] Found nginx at: ${NGINX_BIN}"

INGRESS_PREFIX="$(detect_ingress_prefix || true)"
if [ -n "${INGRESS_PREFIX}" ]; then
  echo "[Kiwix] INGRESS_PREFIX: ${INGRESS_PREFIX}"
else
  echo "[Kiwix] WARNING: Could not detect ingress prefix; using header-only fallback."
  echo "[Kiwix] Debug ingress hostname='${HOSTNAME:-}' INGRESS_ENTRY='${INGRESS_ENTRY:-}' INGRESS_PATH='${INGRESS_PATH:-}' HASSIO_INGRESS='${HASSIO_INGRESS:-}'"
fi

set -- "${KIWIX_SERVE_BIN}" --port="${BACKEND_PORT}" --verbose

if [ -n "${USERNAME}" ] && [ -n "${PASSWORD}" ]; then
  if "${KIWIX_SERVE_BIN}" --help 2>&1 | grep -q -- "--username"; then
    set -- "$@" "--username=${USERNAME}" "--password=${PASSWORD}"
  else
    echo "[Kiwix] WARNING: This kiwix-serve version does not support --username/--password."
  fi
fi

zim_count=0
while IFS= read -r zim; do
  [ -n "${zim}" ] || continue
  if [ ! -r "${zim}" ]; then
    echo "[Kiwix] WARNING: ZIM file is not readable and will be skipped: ${zim}"
    continue
  fi

  if [ ! -s "${zim}" ]; then
    echo "[Kiwix] WARNING: ZIM file is empty and will be skipped: ${zim}"
    continue
  fi

  set -- "$@" "${zim}"
  zim_count=$((zim_count + 1))
  echo "[Kiwix] Added ZIM ${zim_count}: ${zim}"
done < "${ZIM_LIST_FILE}"

if [ "${zim_count}" -eq 0 ]; then
  echo "[Kiwix] ERROR: No readable .zim files found."
  sleep 30
  exit 1
fi

write_index_html

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

ps -o user=,pid=,args= -p "${KIWIX_PID}" 2>/dev/null | sed 's/^/[Kiwix] Backend process: /' || true

write_nginx_conf
echo "[Kiwix] Starting ingress proxy: ${NGINX_BIN} -c ${NGINX_CONF_FILE} (listen ${PORT} -> backend ${BACKEND_PORT})"
exec "${NGINX_BIN}" -c "${NGINX_CONF_FILE}" -g "daemon off;"
