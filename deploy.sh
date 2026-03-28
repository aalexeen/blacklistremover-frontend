#!/usr/bin/env bash
# =============================================================
# deploy.sh — Blacklist Remover production installer
# =============================================================
# Runs LOCALLY on the server. Copy both repos to the server,
# then run this script from the frontend directory.
#
# Usage:
#   ./deploy.sh                  — interactive menu
#   ./deploy.sh full             — build and deploy frontend + backend
#   ./deploy.sh frontend         — deploy frontend only
#   ./deploy.sh backend          — deploy backend only
#   ./deploy.sh setup            — first-time server setup
#   ./deploy.sh configure        — reconfigure ports / paths / env vars
#   ./deploy.sh backup           — create database backup (pg_dump)
#   ./deploy.sh uninstall        — remove application (keeps packages)
#   ./deploy.sh status           — show service and log status
#   ./deploy.sh deps             — check build dependencies
#   ./deploy.sh help
#
# Expected directory layout on the server:
#   ~/
#   ├── blacklistremover-frontend/   ← run deploy.sh from here
#   └── blacklistremover-backend/    ← sibling directory
# =============================================================
set -euo pipefail
IFS=$'\n\t'

# ---------- constants ----------------------------------------
readonly SERVICE_NAME="blacklistremover"
readonly SERVICE_USER="blacklistremover"
readonly DB_NAME="blacklistremover"
readonly SYSTEMD_UNIT="/etc/systemd/system/${SERVICE_NAME}.service"
readonly NGINX_AVAILABLE="/etc/nginx/sites-available/${SERVICE_NAME}"
readonly NGINX_ENABLED="/etc/nginx/sites-enabled/${SERVICE_NAME}"

# ---------- colours (only when stdout is a terminal) ---------
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

# ---------- paths --------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -n "$SCRIPT_DIR" ]] || { echo "ERROR: Failed to determine script directory" >&2; exit 1; }

CONFIG_FILE="${SCRIPT_DIR}/.deploy.conf"
DEFAULT_BACKEND_DIR="${SCRIPT_DIR}/../blacklistremover-backend"

# ---------- logging ------------------------------------------
LOG_FILE="${SCRIPT_DIR}/deploy.log"

info()   { local msg="$*"; echo -e "${CYAN}[INFO]${NC}  ${msg}"; echo "[INFO]  $(date '+%H:%M:%S') ${msg}" >> "$LOG_FILE"; }
ok()     { local msg="$*"; echo -e "${GREEN}[OK]${NC}    ${msg}"; echo "[OK]    $(date '+%H:%M:%S') ${msg}" >> "$LOG_FILE"; }
warn()   { local msg="$*"; echo -e "${YELLOW}[WARN]${NC}  ${msg}"; echo "[WARN]  $(date '+%H:%M:%S') ${msg}" >> "$LOG_FILE"; }
error()  { local msg="$*"; echo -e "${RED}[ERROR]${NC} ${msg}" >&2; echo "[ERROR] $(date '+%H:%M:%S') ${msg}" >> "$LOG_FILE"; }
die()    { error "$*"; exit 1; }
header() { local msg="$*"; echo -e "\n${BOLD}=== ${msg} ===${NC}"; echo "" >> "$LOG_FILE"; echo "=== $(date '+%H:%M:%S') ${msg} ===" >> "$LOG_FILE"; }

# ---------- trap ---------------------------------------------
_on_exit() {
    local code=$?
    if [[ $code -ne 0 ]]; then
        error "Script exited with code ${code}. See ${LOG_FILE} for details."
    fi
}
trap '_on_exit' EXIT

# ---------- lock file (prevent concurrent runs) --------------
readonly LOCK_FILE="/tmp/${SERVICE_NAME}-deploy.lock"

acquire_lock() {
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        die "Another deploy is already running (lock: ${LOCK_FILE}). Aborting."
    fi
    # Release lock on exit
    trap 'flock -u 9; rm -f "${LOCK_FILE}"; _on_exit' EXIT
}

# ---------- rollback -----------------------------------------
# Usage: register_rollback "command to undo this step"
# On ERR the steps are executed in reverse order.
_ROLLBACK_STEPS=()

register_rollback() {
    _ROLLBACK_STEPS+=("$*")
}

_do_rollback() {
    [[ ${#_ROLLBACK_STEPS[@]} -eq 0 ]] && return 0
    warn "Rolling back changes..."
    for (( i=${#_ROLLBACK_STEPS[@]}-1; i>=0; i-- )); do
        info "  Rollback: ${_ROLLBACK_STEPS[$i]}"
        eval "${_ROLLBACK_STEPS[$i]}" || warn "  Rollback step failed — continuing"
    done
    _ROLLBACK_STEPS=()
}

# ---------- user input helpers -------------------------------
prompt() {
    local var="$1" desc="$2" default="${3:-}"
    local input
    if [[ -n "$default" ]]; then
        echo -ne "${BOLD}${desc}${NC} [${default}]: "
    else
        echo -ne "${BOLD}${desc}${NC}: "
    fi
    read -r input || { echo; exit 1; }
    [[ -z "$input" && -n "$default" ]] && input="$default"
    printf -v "$var" '%s' "$input"
}

prompt_secret() {
    local var="$1" desc="$2" default="${3:-}"
    local input
    while true; do
        if [[ -n "$default" ]]; then
            echo -ne "${BOLD}${desc}${NC} (hidden) [leave blank to keep current]: "
        else
            echo -ne "${BOLD}${desc}${NC} (hidden): "
        fi
        read -rs input || { echo; exit 1; }
        echo
        if [[ -z "$input" && -n "$default" ]]; then
            input="$default"
            break
        fi
        if [[ -z "$input" ]]; then
            warn "Value cannot be empty. Please try again."
            continue
        fi
        break
    done
    printf -v "$var" '%s' "$input"
}

confirm() {
    echo -ne "${BOLD}${1}${NC} [y/N]: "
    local r
    read -r r || { echo; exit 1; }
    [[ "$r" =~ ^[Yy]$ ]]
}

# ---------- config load/save ---------------------------------
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local perms
        perms="$(stat -c %a "$CONFIG_FILE" 2>/dev/null || echo "000")"
        if [[ "$perms" != "600" ]]; then
            warn "Config file permissions are ${perms}, expected 600. Fixing..."
            chmod 600 "$CONFIG_FILE"
        fi
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
}

_save_config() {
    # Write to temp file first, then move atomically
    local tmp
    tmp="$(mktemp "${SCRIPT_DIR}/.deploy.conf.XXXXXX")"
    cat > "$tmp" <<EOF
# Blacklist Remover deploy config — generated $(date)
# Do NOT commit this file — contains secrets.

BACKEND_DIR="${BACKEND_DIR:-}"

DEPLOY_DIR="${DEPLOY_DIR:-/opt/blacklistremover}"
FRONTEND_DIR="${FRONTEND_DIR:-/var/www/blacklistremover}"

# Ports
APP_BACKEND_PORT="${APP_BACKEND_PORT:-8080}"  # Spring Boot on localhost
APP_PUBLIC_PORT="${APP_PUBLIC_PORT:-80}"       # Nginx external port

DB_URL="${DB_URL:-jdbc:postgresql://localhost:5432/blacklistremover}"
DB_USERNAME="${DB_USERNAME:-}"
DB_PASSWORD="${DB_PASSWORD:-}"

WLC1_SSH_HOST="${WLC1_SSH_HOST:-}"
WLC1_SSH_PORT="${WLC1_SSH_PORT:-22}"
WLC2_SSH_HOST="${WLC2_SSH_HOST:-}"
WLC2_SSH_PORT="${WLC2_SSH_PORT:-22}"
WLC_USERNAME="${WLC_USERNAME:-}"
WLC_PASSWORD="${WLC_PASSWORD:-}"
WLC_ENABLE_PASSWORD="${WLC_ENABLE_PASSWORD:-}"
EOF
    chmod 600 "$tmp"
    mv "$tmp" "$CONFIG_FILE"
    ok "Config saved to ${CONFIG_FILE}"
}

# Wrap save_config to suppress xtrace (DEBUG=1) around secret values
save_config() {
    set +x
    _save_config
    [[ "${DEBUG:-0}" == "1" ]] && set -x || true
}

# ---------- config validation --------------------------------
check_config() {
    local missing=()
    [[ -z "${DB_PASSWORD:-}" ]] && missing+=("DB_PASSWORD")
    [[ -z "${DB_USERNAME:-}" ]] && missing+=("DB_USERNAME")
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing configuration: ${missing[*]}"
        error "Run: ./deploy.sh configure"
        return 1
    fi
    return 0
}

# ---------- port helpers -------------------------------------
# Returns 0 if port is free, 1 if busy.
port_is_free() {
    local port="$1"
    [[ -n "$port" ]] || return 0
    ss -tlnp 2>/dev/null | grep -qE ":${port}\b" && return 1 || return 0
}

# Interactive port prompt with occupancy check.
# Usage: prompt_port <var> <description> <default>
prompt_port() {
    local var="$1" desc="$2" default="${3:-}"
    local port reason

    while true; do
        prompt port "$desc" "$default"

        if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
            warn "Invalid port '${port}'. Must be 1–65535."
            default="$port"
            continue
        fi

        if ! port_is_free "$port"; then
            reason="$(ss -tlnp 2>/dev/null | grep -E ":${port}\b" | awk '{print $NF}' | head -1 || true)"
            warn "Port ${port} is already in use${reason:+ by: ${reason}}"
            if confirm "  Use port ${port} anyway (not recommended)?"; then
                break
            else
                info "Choose a different port."
                default="$port"
                continue
            fi
        fi

        ok "Port ${port} is free"
        break
    done

    printf -v "$var" '%s' "$port"
}

# ---------- write file helper --------------------------------
# Atomically writes content to a system path with correct permissions
# from the start — no race window between create and chmod.
# Usage: write_file <content> <dest_path> <mode> <owner>
write_file() {
    local content="$1" dest="$2" mode="${3:-644}" owner="${4:-root:root}"
    local tmp
    tmp="$(mktemp)"
    printf '%s\n' "$content" > "$tmp"
    # install sets mode before placing the file — no race condition
    sudo install -m "$mode" -o "${owner%%:*}" -g "${owner##*:}" "$tmp" "$dest"
    rm -f "$tmp"
}

# ---------- postgres helpers ---------------------------------
pg_user_exists() {
    local user="$1"
    local result
    result="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname=\$\$${user}\$\$" 2>/dev/null || true)"
    [[ "$result" == "1" ]]
}

pg_db_exists() {
    local result
    result="$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" 2>/dev/null || true)"
    [[ "$result" == "1" ]]
}

# Pipe SQL via stdin to avoid credentials appearing in process list.
pg_exec() {
    local sql="$1"
    echo "$sql" | sudo -u postgres psql
}

# ---------- package install helper ---------------------------
# Checks if a binary is installed. If found — shows version and
# asks to reinstall or skip. If not found — installs immediately.
# Usage: check_and_install <display_name> <version_cmd> <apt_packages>
check_and_install() {
    local name="$1" ver_cmd="$2" pkg="$3"
    local current_ver
    current_ver="$(eval "$ver_cmd" 2>/dev/null || true)"
    if [[ -n "$current_ver" ]]; then
        ok "${name} already installed: ${current_ver}"
        if confirm "  Reinstall / upgrade ${name}?"; then
            info "Installing ${pkg} ..."
            # shellcheck disable=SC2086
            sudo apt-get install -y $pkg
            ok "${name} updated"
        else
            info "Skipping ${name}"
        fi
    else
        info "${name} not found — installing ${pkg} ..."
        # shellcheck disable=SC2086
        sudo apt-get install -y $pkg
        ok "${name} installed"
    fi
}

# ---------- setup service dirs -------------------------------
# Usage: setup_dir <path> <owner> <mode>
setup_dir() {
    local path="$1" owner="$2" mode="$3"
    sudo mkdir -p "$path"
    sudo chown "$owner" "$path"
    sudo chmod "$mode" "$path"
    ok "Directory ${path} (owner: ${owner}, mode: ${mode})"
}

# ---------- configure ----------------------------------------
do_configure() {
    header "Local paths"
    local default_backend
    default_backend="$(realpath "${BACKEND_DIR:-${DEFAULT_BACKEND_DIR}}" 2>/dev/null || echo "${DEFAULT_BACKEND_DIR}")"
    prompt BACKEND_DIR "Path to blacklistremover-backend" "${default_backend}"
    if [[ ! -f "${BACKEND_DIR}/pom.xml" ]]; then
        warn "pom.xml not found at '${BACKEND_DIR}' — double-check before deploying backend"
    else
        ok "Backend found at '${BACKEND_DIR}'"
    fi

    header "Deploy paths (on this server)"
    prompt DEPLOY_DIR   "Backend deploy directory"  "${DEPLOY_DIR:-/opt/blacklistremover}"
    prompt FRONTEND_DIR "Frontend deploy directory" "${FRONTEND_DIR:-/var/www/blacklistremover}"

    header "Ports"
    info "  Backend port  — Spring Boot listens on localhost, Nginx proxies /api/ to it"
    prompt_port APP_BACKEND_PORT \
        "Backend internal port (Spring Boot)" \
        "${APP_BACKEND_PORT:-8080}"

    info "  Public port   — Nginx listens on this port, accessible from outside"
    prompt_port APP_PUBLIC_PORT \
        "Public port (Nginx external, e.g. 80 or 8888)" \
        "${APP_PUBLIC_PORT:-80}"

    header "Database"
    prompt        DB_URL      "JDBC URL"    "${DB_URL:-jdbc:postgresql://localhost:5432/blacklistremover}"
    prompt        DB_USERNAME "DB username" "${DB_USERNAME:-blacklist_user}"
    prompt_secret DB_PASSWORD "DB password" "${DB_PASSWORD:-}"

    header "WLC SSH (controller 1)"
    prompt WLC1_SSH_HOST "WLC1 host" "${WLC1_SSH_HOST:-}"
    prompt WLC1_SSH_PORT "WLC1 port" "${WLC1_SSH_PORT:-22}"

    header "WLC SSH (controller 2)"
    prompt WLC2_SSH_HOST "WLC2 host" "${WLC2_SSH_HOST:-}"
    prompt WLC2_SSH_PORT "WLC2 port" "${WLC2_SSH_PORT:-22}"

    header "WLC credentials (shared)"
    prompt        WLC_USERNAME        "WLC username"        "${WLC_USERNAME:-}"
    prompt_secret WLC_PASSWORD        "WLC password"        "${WLC_PASSWORD:-}"
    prompt_secret WLC_ENABLE_PASSWORD "WLC enable password" "${WLC_ENABLE_PASSWORD:-}"

    save_config
}

# ---------- first-time server setup --------------------------
# Service user: dedicated system account 'blacklistremover'
#   - no login shell, no home directory
#   - owns DEPLOY_DIR, .env, app.jar
#   - Nginx (www-data) reads only static files in FRONTEND_DIR
do_setup() {
    check_config

    # Require sudo upfront — fail fast before doing any work
    sudo -v || die "This script requires sudo privileges."

    header "Checking and installing dependencies"
    sudo apt-get update -qq

    check_and_install \
        "Java 24" \
        "java -version 2>&1 | head -1" \
        "openjdk-24-jdk"

    check_and_install \
        "PostgreSQL" \
        "psql --version 2>/dev/null | head -1" \
        "postgresql postgresql-contrib"

    check_and_install \
        "Nginx" \
        "nginx -v 2>&1 | head -1" \
        "nginx"

    check_and_install \
        "Maven" \
        "mvn -version 2>/dev/null | head -1" \
        "maven"

    check_and_install \
        "Node.js / npm" \
        "node --version 2>/dev/null" \
        "nodejs npm"

    header "Creating service user"
    if id "$SERVICE_USER" >/dev/null 2>&1; then
        ok "User '${SERVICE_USER}' already exists"
    else
        sudo useradd -r -s /usr/sbin/nologin -M "$SERVICE_USER"
        ok "User '${SERVICE_USER}' created"
    fi

    header "PostgreSQL: user and database"
    local db_user="${DB_USERNAME}"

    if pg_user_exists "$db_user"; then
        ok "DB user '${db_user}' already exists"
        if confirm "  Update password for '${db_user}'?"; then
            pg_exec "ALTER USER \"${db_user}\" WITH PASSWORD '${DB_PASSWORD}';"
            ok "Password updated"
        else
            info "Keeping existing password"
        fi
    else
        info "Creating DB user '${db_user}' ..."
        pg_exec "CREATE USER \"${db_user}\" WITH PASSWORD '${DB_PASSWORD}';"
        ok "DB user '${db_user}' created"
    fi

    if pg_db_exists; then
        ok "Database '${DB_NAME}' already exists — skipping creation"
        warn "Existing data will NOT be touched. Liquibase handles schema migrations on first start."
    else
        info "Creating database '${DB_NAME}' owned by '${db_user}' ..."
        pg_exec "CREATE DATABASE \"${DB_NAME}\" OWNER \"${db_user}\";"
        ok "Database '${DB_NAME}' created"
    fi

    header "Creating backend deploy directory"
    setup_dir "${DEPLOY_DIR}" "${SERVICE_USER}:${SERVICE_USER}" "750"

    header "Writing .env"
    write_file \
"DB_URL=${DB_URL}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}
WLC1_SSH_HOST=${WLC1_SSH_HOST:-}
WLC1_SSH_PORT=${WLC1_SSH_PORT:-22}
WLC2_SSH_HOST=${WLC2_SSH_HOST:-}
WLC2_SSH_PORT=${WLC2_SSH_PORT:-22}
WLC_USERNAME=${WLC_USERNAME:-}
WLC_PASSWORD=${WLC_PASSWORD:-}
WLC_ENABLE_PASSWORD=${WLC_ENABLE_PASSWORD:-}" \
        "${DEPLOY_DIR}/.env" "600" "${SERVICE_USER}:${SERVICE_USER}"
    ok ".env written"

    local backend_port="${APP_BACKEND_PORT:-8080}"
    local public_port="${APP_PUBLIC_PORT:-80}"

    header "Installing systemd unit"
    write_file \
"[Unit]
Description=Blacklist Remover Backend
After=network.target postgresql.service

[Service]
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${DEPLOY_DIR}
EnvironmentFile=${DEPLOY_DIR}/.env
Environment=JAVA_HOME=/usr/lib/jvm/java-24-openjdk-amd64
ExecStart=/usr/lib/jvm/java-24-openjdk-amd64/bin/java -jar ${DEPLOY_DIR}/app.jar --server.port=${backend_port}
SuccessExitStatus=143
Restart=on-failure
RestartSec=10
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target" \
        "$SYSTEMD_UNIT" "644" "root:root"
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    ok "Systemd unit installed and enabled (backend port: ${backend_port})"

    header "Configuring Nginx"
    setup_dir "${FRONTEND_DIR}" "www-data:www-data" "755"

    # Check if default site conflicts on the chosen public port
    if [[ -f /etc/nginx/sites-enabled/default ]]; then
        warn "Nginx 'default' site is enabled and may conflict on port ${public_port}."
        if confirm "  Disable the 'default' site?"; then
            sudo rm -f /etc/nginx/sites-enabled/default
            ok "Default site disabled"
        else
            warn "Keeping default site — ensure it does not listen on port ${public_port}"
        fi
    fi

    write_file \
"server {
    listen ${public_port};
    server_name _;

    root ${FRONTEND_DIR};
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://localhost:${backend_port}/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 60s;
    }
}" \
        "$NGINX_AVAILABLE" "644" "root:root"
    sudo ln -sf "$NGINX_AVAILABLE" "$NGINX_ENABLED"
    sudo nginx -t || die "Nginx config validation failed — check ${NGINX_AVAILABLE}"
    sudo systemctl reload nginx
    ok "Nginx configured (public port: ${public_port} → backend: ${backend_port})"

    ok "Setup complete. Run './deploy.sh full' to build and deploy the application."
}

# ---------- resolve backend dir ------------------------------
resolve_backend_dir() {
    local backend_dir="${BACKEND_DIR:-}"
    if [[ -z "$backend_dir" ]]; then
        backend_dir="$(realpath "${DEFAULT_BACKEND_DIR}" 2>/dev/null || echo "${DEFAULT_BACKEND_DIR}")"
    fi
    if [[ ! -f "${backend_dir}/pom.xml" ]]; then
        warn "Backend not found at: ${backend_dir}"
        prompt backend_dir "Enter path to blacklistremover-backend" ""
        backend_dir="$(realpath "$backend_dir")"
        [[ -f "${backend_dir}/pom.xml" ]] || die "pom.xml not found at '${backend_dir}'. Aborting."
        BACKEND_DIR="$backend_dir"
        save_config
    fi
    echo "$backend_dir"
}

# ---------- health check -------------------------------------
# Polls the backend HTTP health endpoint until it responds or times out.
wait_for_backend() {
    local port="${APP_BACKEND_PORT:-8080}"
    local url="http://localhost:${port}/actuator/health"
    local retries=12 interval=5

    info "Waiting for backend to respond on port ${port} (up to $((retries * interval))s)..."
    for (( i=1; i<=retries; i++ )); do
        if curl -sf "$url" >/dev/null 2>&1; then
            ok "Backend is healthy"
            return 0
        fi
        # Fall back to systemctl check if actuator is not available
        if sudo systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
            if (( i >= 3 )); then
                # Give Spring Boot a bit more time to bind the port after systemd reports active
                ok "Service is active (actuator endpoint not available — using systemctl)"
                return 0
            fi
        fi
        info "  attempt ${i}/${retries} — waiting ${interval}s..."
        sleep "$interval"
    done
    die "Backend did not become healthy in time. Check: sudo journalctl -u ${SERVICE_NAME} -n 50"
}

# ---------- deploy backend -----------------------------------
do_deploy_backend() {
    check_config
    acquire_lock
    sudo -v || die "This script requires sudo privileges."

    [[ -f "$SYSTEMD_UNIT" ]] || die "Service not set up. Run './deploy.sh setup' first."
    [[ -d "$DEPLOY_DIR" ]]   || die "Deploy directory not found. Run './deploy.sh setup' first."

    header "Building backend"
    local backend_dir
    backend_dir="$(resolve_backend_dir)"
    info "Using backend: ${backend_dir}"

    local mvn_cmd
    if [[ -x "${backend_dir}/mvnw" ]]; then
        mvn_cmd="./mvnw"
    elif command -v mvn &>/dev/null; then
        mvn_cmd="mvn"
    else
        die "Neither mvnw nor mvn found. Run './deploy.sh setup' to install Maven."
    fi

    # config.properties is in .gitignore — create empty file if missing
    local config_props="${backend_dir}/src/main/resources/config.properties"
    if [[ ! -f "$config_props" ]]; then
        touch "$config_props"
        info "Created empty config.properties (was missing from repo)"
    fi

    # Ensure the correct Java is used for the build — Maven picks up JAVA_HOME
    # Prefer Java 23, fall back to 21, then whatever is default
    local java_home_build
    java_home_build="$(ls -d /usr/lib/jvm/java-24-openjdk-* 2>/dev/null | head -1 || true)"
    if [[ -z "$java_home_build" ]]; then
        java_home_build="$(ls -d /usr/lib/jvm/java-21-openjdk-* 2>/dev/null | head -1 || true)"
    fi
    if [[ -n "$java_home_build" ]]; then
        export JAVA_HOME="$java_home_build"
        info "Using JAVA_HOME: ${JAVA_HOME}"
    else
        warn "Java 24/21 not found in /usr/lib/jvm — build may fail if default Java is too old"
    fi

    info "Running: ${mvn_cmd} clean package -DskipTests"
    (cd "$backend_dir" && $mvn_cmd clean package -DskipTests -q)
    ok "Build successful"

    local jar
    jar="$(ls -t "${backend_dir}/target/"*.jar 2>/dev/null | grep -v 'original' | head -1 || true)"
    [[ -n "$jar" ]] || die "No JAR file found in ${backend_dir}/target/"
    info "JAR: ${jar}"

    header "Installing JAR"
    # Back up old JAR so we can roll back if new one fails to start
    if [[ -f "${DEPLOY_DIR}/app.jar" ]]; then
        sudo cp "${DEPLOY_DIR}/app.jar" "${DEPLOY_DIR}/app.jar.bak"
        register_rollback "sudo cp '${DEPLOY_DIR}/app.jar.bak' '${DEPLOY_DIR}/app.jar' && sudo systemctl restart '${SERVICE_NAME}'"
    fi

    sudo install -m 640 -o "$SERVICE_USER" -g "$SERVICE_USER" "$jar" "${DEPLOY_DIR}/app.jar"
    [[ -f "${DEPLOY_DIR}/app.jar" ]] || die "Failed to install JAR to ${DEPLOY_DIR}/app.jar"
    ok "JAR installed to ${DEPLOY_DIR}/app.jar"

    header "Restarting backend service"
    register_rollback "sudo systemctl restart '${SERVICE_NAME}'"
    sudo systemctl restart "$SERVICE_NAME"

    wait_for_backend

    # Deploy succeeded — clear rollback stack
    _ROLLBACK_STEPS=()
    sudo rm -f "${DEPLOY_DIR}/app.jar.bak"
}

# ---------- deploy frontend ----------------------------------
do_deploy_frontend() {
    check_config
    acquire_lock
    sudo -v || die "This script requires sudo privileges."

    [[ -f "$NGINX_AVAILABLE" ]] || die "Nginx site not configured. Run './deploy.sh setup' first."

    header "Building frontend"
    [[ -f "${SCRIPT_DIR}/package.json" ]] || die "package.json not found in ${SCRIPT_DIR}"

    # Use production vite config (no dev server / proxy section)
    local vite_orig="${SCRIPT_DIR}/vite.config.js"
    local vite_prod="${SCRIPT_DIR}/vite.config.prod.js"
    local vite_backup="${SCRIPT_DIR}/vite.config.js.bak"
    if [[ -f "$vite_prod" ]]; then
        info "Swapping vite.config.js → vite.config.prod.js for build"
        cp "$vite_orig" "$vite_backup"
        cp "$vite_prod" "$vite_orig"
        register_rollback "cp '${vite_backup}' '${vite_orig}'; rm -f '${vite_backup}'"
    else
        warn "vite.config.prod.js not found — building with default vite.config.js"
    fi

    info "Running: npm install"
    (cd "$SCRIPT_DIR" && npm install)
    info "Running: npm run build"
    (cd "$SCRIPT_DIR" && npm run build)

    # Restore original vite config
    if [[ -f "$vite_backup" ]]; then
        cp "$vite_backup" "$vite_orig"
        rm -f "$vite_backup"
        ok "vite.config.js restored"
    fi

    [[ -d "${SCRIPT_DIR}/dist" ]] || die "Build failed — dist/ directory not found"
    ok "Build successful"

    header "Installing frontend"
    setup_dir "${FRONTEND_DIR}" "www-data:www-data" "755"
    # Remove stale files before installing new build
    sudo find "${FRONTEND_DIR}" -mindepth 1 -delete 2>/dev/null || true
    sudo cp -r "${SCRIPT_DIR}/dist/." "${FRONTEND_DIR}/"
    sudo chown -R www-data:www-data "${FRONTEND_DIR}"
    ok "Frontend installed to ${FRONTEND_DIR}"

    header "Reloading Nginx"
    sudo nginx -t || die "Nginx config validation failed"
    sudo systemctl reload nginx
    ok "Nginx reloaded"
}

# ---------- full deploy --------------------------------------
do_full_deploy() {
    check_config
    acquire_lock
    sudo -v || die "This script requires sudo privileges."
    do_deploy_backend
    do_deploy_frontend
    local public_port="${APP_PUBLIC_PORT:-80}"
    ok "Deploy complete. App is live at http://localhost:${public_port}"
}

# ---------- backup db ----------------------------------------
do_backup() {
    if ! pg_db_exists; then
        warn "Database '${DB_NAME}' not found — nothing to back up."
        return 1
    fi

    local backup_file="${DB_NAME}_backup_$(date +%Y%m%d_%H%M%S).sql"
    local backup_path="${SCRIPT_DIR}/${backup_file}"
    info "Dumping database '${DB_NAME}' to ${backup_path} ..."

    # Use temp file with restricted permissions from the start
    local tmp
    tmp="$(mktemp)"
    chmod 600 "$tmp"

    if sudo -u postgres pg_dump "$DB_NAME" > "$tmp"; then
        mv "$tmp" "$backup_path"
        chmod 600 "$backup_path"
        ok "Backup saved: ${backup_path}"
        return 0
    else
        rm -f "$tmp"
        error "pg_dump failed. Backup was NOT created."
        return 1
    fi
}

# ---------- status -------------------------------------------
do_status() {
    header "Service status"
    sudo systemctl status "$SERVICE_NAME" --no-pager || true
    header "Nginx status"
    sudo systemctl status nginx --no-pager || true
    header "Last 20 backend log lines"
    sudo journalctl -u "$SERVICE_NAME" -n 20 --no-pager || true
}

# ---------- dependencies check -------------------------------
check_dependencies() {
    header "Checking build dependencies"
    local fail_count=0
    for cmd in npm node java; do
        if command -v "$cmd" &>/dev/null; then
            ok "$cmd — $(command -v "$cmd")"
        else
            warn "$cmd — not found"
            (( fail_count++ ))
        fi
    done
    local backend_dir="${BACKEND_DIR:-${DEFAULT_BACKEND_DIR}}"
    if [[ -x "${backend_dir}/mvnw" ]]; then
        ok "mvnw — found in ${backend_dir}"
    elif command -v mvn &>/dev/null; then
        ok "mvn — $(mvn -version 2>/dev/null | head -1) (mvnw not found, will use system mvn)"
    else
        warn "mvnw not found at '${backend_dir}/mvnw' and mvn not installed"
        (( fail_count++ ))
    fi
    [[ $fail_count -gt 0 ]] && warn "${fail_count} tool(s) missing — some steps may fail"
    return 0
}

# ---------- uninstall ----------------------------------------
# Removes everything installed by setup/deploy.
# Does NOT remove packages (Java, Nginx, PostgreSQL).
do_uninstall() {
    sudo -v || die "This script requires sudo privileges."

    echo
    warn "This will permanently remove the Blacklist Remover application:"
    echo "  • systemd service  ${SERVICE_NAME}"
    echo "  • backend files    ${DEPLOY_DIR:-/opt/blacklistremover}"
    echo "  • frontend files   ${FRONTEND_DIR:-/var/www/blacklistremover}"
    echo "  • nginx site       ${NGINX_AVAILABLE} + ${NGINX_ENABLED}"
    echo "  • system user      ${SERVICE_USER}"
    echo "  • database         ${DB_NAME}  (separate confirmation)"
    echo "  • db user          ${DB_USERNAME:-blacklist_user}  (separate confirmation)"
    echo
    warn "Installed packages (Java, Nginx, PostgreSQL) will NOT be removed."
    echo
    confirm "Proceed with uninstall?" || { info "Aborted."; return 0; }

    header "Stopping and disabling service"
    if sudo systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        sudo systemctl stop "$SERVICE_NAME"
        ok "Service stopped"
    else
        info "Service is not running — skipping"
    fi
    if sudo systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        sudo systemctl disable "$SERVICE_NAME"
        ok "Service disabled"
    else
        info "Service is not enabled — skipping"
    fi
    if [[ -f "$SYSTEMD_UNIT" ]]; then
        sudo rm -f "$SYSTEMD_UNIT"
        sudo systemctl daemon-reload
        ok "Unit file removed"
    else
        info "Unit file not found — skipping"
    fi

    header "Removing backend files"
    local deploy_dir="${DEPLOY_DIR:-/opt/blacklistremover}"
    if [[ -d "$deploy_dir" ]]; then
        sudo rm -rf "$deploy_dir"
        ok "Removed ${deploy_dir}"
    else
        info "${deploy_dir} not found — skipping"
    fi

    header "Removing frontend files"
    local frontend_dir="${FRONTEND_DIR:-/var/www/blacklistremover}"
    if [[ -d "$frontend_dir" ]]; then
        sudo rm -rf "$frontend_dir"
        ok "Removed ${frontend_dir}"
    else
        info "${frontend_dir} not found — skipping"
    fi

    header "Removing Nginx site"
    sudo rm -f "$NGINX_ENABLED" "$NGINX_AVAILABLE"
    if sudo nginx -t >/dev/null 2>&1; then
        sudo systemctl reload nginx
        ok "Nginx site removed and reloaded"
    else
        warn "Nginx config test failed after removing site — check manually"
    fi

    header "Removing system user"
    if id "$SERVICE_USER" >/dev/null 2>&1; then
        sudo userdel "$SERVICE_USER"
        ok "User '${SERVICE_USER}' removed"
    else
        info "User '${SERVICE_USER}' not found — skipping"
    fi

    header "PostgreSQL cleanup"
    local db_user="${DB_USERNAME:-blacklist_user}"

    if ! pg_db_exists; then
        info "Database '${DB_NAME}' not found — skipping"
    else
        warn "The following will permanently delete ALL application data."
        echo "  • database: ${DB_NAME}"
        echo "  • db user:  ${db_user}"
        echo

        if confirm "  Create a backup before dropping?"; then
            do_backup || {
                confirm "  Continue dropping the database WITHOUT a backup?" || {
                    info "Aborted. Database and user kept."
                    return 0
                }
            }
        fi

        if confirm "  Drop database '${DB_NAME}' and user '${db_user}'?"; then
            pg_exec "DROP DATABASE \"${DB_NAME}\";"
            ok "Database '${DB_NAME}' dropped"

            if pg_user_exists "$db_user"; then
                pg_exec "DROP USER \"${db_user}\";"
                ok "DB user '${db_user}' dropped"
            else
                info "DB user '${db_user}' not found — skipping"
            fi
        else
            info "Database and user kept."
        fi
    fi

    echo
    ok "Uninstall complete. Packages (Java, Nginx, PostgreSQL) were not touched."
}

# ---------- help ---------------------------------------------
show_help() {
    echo -e "${BOLD}Blacklist Remover — deploy script${NC}"
    echo
    echo "Usage: ./deploy.sh [command]"
    echo
    echo "Commands:"
    echo "  (none)       Interactive menu"
    echo "  configure    Set paths, ports, env variables"
    echo "  setup        First-time setup (packages, DB, nginx, systemd)"
    echo "  full         Build and deploy frontend + backend"
    echo "  frontend     Build and deploy frontend only"
    echo "  backend      Build and deploy backend only"
    echo "  status       Show service and log status"
    echo "  backup       Create database backup (pg_dump)"
    echo "  uninstall    Remove application (keeps packages)"
    echo "  deps         Check build dependencies"
    echo "  help         Show this help"
    echo
    echo "Config:  ${CONFIG_FILE}"
    echo "Log:     ${LOG_FILE}"
    echo
    echo "Note: requires sudo privileges."
}

# ---------- menu ---------------------------------------------
menu() {
    while true; do
        echo
        echo -e "${BOLD}Blacklist Remover — Deploy Menu${NC}"
        echo -e "  Backend port: ${CYAN}${APP_BACKEND_PORT:-8080}${NC}   Public port: ${CYAN}${APP_PUBLIC_PORT:-80}${NC}"
        echo -e "  Deploy dir:   ${CYAN}${DEPLOY_DIR:-/opt/blacklistremover}${NC}"
        echo
        echo "  1) Configure (paths, ports, env vars)"
        echo "  2) First-time setup"
        echo "  3) Full deploy (frontend + backend)"
        echo "  4) Deploy frontend only"
        echo "  5) Deploy backend only"
        echo "  6) Status & logs"
        echo "  7) Backup database"
        echo "  8) Check build dependencies"
        echo "  9) Uninstall"
        echo "  q) Quit"
        echo
        echo -ne "${BOLD}Choice:${NC} "
        local choice
        read -r choice || break
        case "$choice" in
            1) do_configure ;;
            2) do_setup ;;
            3) do_full_deploy ;;
            4) do_deploy_frontend ;;
            5) do_deploy_backend ;;
            6) do_status ;;
            7) do_backup ;;
            8) check_dependencies ;;
            9) do_uninstall ;;
            q|Q) break ;;
            *) warn "Unknown option: $choice" ;;
        esac
    done
}

# ---------- entry point --------------------------------------
# Enable xtrace for debug mode — secrets are protected via set +x in save_config
[[ "${DEBUG:-0}" == "1" ]] && set -x

# Log file header for each run
echo "" >> "$LOG_FILE"
echo "========== $(date) — $0 ${*:-menu} ==========" >> "$LOG_FILE"

load_config

ACTION="${1:-menu}"
shift || true

case "$ACTION" in
    configure)   do_configure ;;
    setup)       do_setup ;;
    full)        do_full_deploy ;;
    frontend)    do_deploy_frontend ;;
    backend)     do_deploy_backend ;;
    status)      do_status ;;
    backup)      do_backup ;;
    uninstall)   do_uninstall ;;
    deps)        check_dependencies ;;
    help|--help|-h) show_help ;;
    menu)        menu ;;
    *)           error "Unknown command: $ACTION"; show_help; exit 1 ;;
esac
