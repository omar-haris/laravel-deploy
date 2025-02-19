#!/bin/bash
# Author: Omar Haris - https://www.linkedin.com/omarharis

# -------------------------
# 0. DEFAULT CONFIGURABLE VARIABLES
# -------------------------
PROJECT_DIR="/var/www/laravel"           
DEPLOY_SCRIPT="/var/www/larave-deploy.sh"

# OS TYPE can be "auto", "debian", or "rhel"
OS_TYPE="auto"

WEB_USER="www-data"
BRANCH="main"
BACKUP_DIR="/var/backups/laravel"
KEEP_BACKUPS=7
GIT_URL=""
ENV_FILE_PATH=""   # Must be provided if GIT_URL is used
PHP_BIN="/usr/bin/php"
COMPOSER_BIN="/usr/local/bin/composer"

ENABLE_BACKUP=true
ENABLE_MAINTENANCE=true
RUN_MIGRATIONS=true
CLEAR_CACHE=true
SET_PERMISSIONS=true
RESTART_SUPERVISOR=true
CHECK_CRON=true
CHECK_CHCON=true
CREATE_STORAGE_LINK=true

# Debug/unsecure modes
DEBUG_MODE=false     
UNSECURE_MODE=false  

# ANSI colors
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

# -------------------------
# HELPER FUNCTIONS
# -------------------------
step() {
    echo -e "\n${CYAN}[Step $1]${RESET} $2"
}

success() {
    echo -e "${GREEN}$1${RESET}"
}

warn() {
    echo -e "${YELLOW}Warning:${RESET} $1"
}

error() {
    echo -e "${RED}Error:${RESET} $1"
}

run_cmd() {
    if [ "$DEBUG_MODE" = true ]; then
        echo "Command: $*"
    fi
    eval "$@"
}

artisan() {
    if [ "$DEBUG_MODE" = true ]; then
        echo "Command: cd \"$PROJECT_DIR\" && $PHP_BIN artisan $*"
    fi
    (cd "$PROJECT_DIR" && $PHP_BIN artisan "$@")
}

detect_service_manager() {
    if command -v systemctl >/dev/null 2>&1; then
        echo "systemctl"
    else
        echo "service"
    fi
}

restart_supervisor_service() {
    local manager
    manager="$(detect_service_manager)"
    case "$manager" in
        systemctl)
            if [ "$DEBUG_MODE" = true ]; then
                echo "Command: sudo supervisorctl reread"
            fi
            sudo supervisorctl reread 2>/dev/null || warn "Supervisor reread failed."
            if [ "$DEBUG_MODE" = true ]; then
                echo "Command: sudo supervisorctl update"
            fi
            sudo supervisorctl update 2>/dev/null || warn "Supervisor update failed."
            if [ "$DEBUG_MODE" = true ]; then
                echo "Command: sudo systemctl restart supervisor"
            fi
            sudo systemctl restart supervisor 2>/dev/null || warn "Failed to restart Supervisor (systemctl)."
            ;;
        service)
            if [ "$DEBUG_MODE" = true ]; then
                echo "Command: sudo supervisorctl reread"
            fi
            sudo supervisorctl reread 2>/dev/null || warn "Supervisor reread failed."
            if [ "$DEBUG_MODE" = true ]; then
                echo "Command: sudo supervisorctl update"
            fi
            sudo supervisorctl update 2>/dev/null || warn "Supervisor update failed."
            if [ "$DEBUG_MODE" = true ]; then
                echo "Command: sudo service supervisor restart"
            fi
            sudo service supervisor restart 2>/dev/null || warn "Failed to restart Supervisor (service)."
            ;;
    esac
}

auto_detect_os() {
    if [ "$OS_TYPE" = "auto" ] && [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID_LIKE" =~ "debian" ]] || [[ "$ID" =~ "debian" ]] || [[ "$ID" =~ "ubuntu" ]]; then
            WEB_USER="www-data"
        elif [[ "$ID_LIKE" =~ "rhel" ]] || [[ "$ID_LIKE" =~ "fedora" ]] || [[ "$ID" =~ "centos" ]] || [[ "$ID" =~ "rocky" ]] || [[ "$ID" =~ "almalinux" ]]; then
            WEB_USER="apache"
        else
            WEB_USER="www-data"
        fi
    elif [ "$OS_TYPE" = "debian" ]; then
        WEB_USER="www-data"
    elif [ "$OS_TYPE" = "rhel" ]; then
        WEB_USER="apache"
    fi
}

show_help() {
    clear
    echo "Usage: ./larave-deploy.sh [OPTIONS]"
    echo ""
    echo "This script automates the deployment of a Laravel application. Configuration can come from:"
    echo "  1) A 'laravel-deploy.env' file in the current directory (if present)."
    echo "  2) Environment variables with prefix LARAVEL_DEPLOY_ (e.g. LARAVEL_DEPLOY_PROJECT_DIR)."
    echo "  3) Command-line arguments (highest precedence)."
    echo "If none of these are provided, defaults in the script are used."
    echo ""
    echo "Major Features:"
    echo "  - Git clone/pull, mandatory --env-file for fresh clones"
    echo "  - Cron and SELinux checks"
    echo "  - Debug/unsecure modes (mask or reveal DB password/IP)"
    echo "  - Automatic backups, migrations, Supervisor restarts, etc."
    echo ""
    echo "Options (overriding any defaults/env-file variables):"
    echo "  --git-url=URL               If project dir is empty, clone from this URL"
    echo "  --env-file=PATH             Provide .env for fresh clones (mandatory if --git-url is used)"
    echo "  --debug                     Print commands (masking DB password/IP by default)"
    echo "  --unsecure                  If used with --debug, reveals actual DB password/IP"
    echo ""
    echo "  --no-backup                 Skip code/DB backups"
    echo "  --no-maintenance            Skip enabling maintenance mode"
    echo "  --no-migrate                Skip running DB migrations"
    echo "  --no-cache-clear            Skip clearing/optimizing caches"
    echo "  --no-permissions            Skip setting file/folder permissions"
    echo "  --no-supervisor             Skip restarting Supervisor"
    echo "  --no-storage-link           Skip creating storage symlink"
    echo ""
    echo "  --check-cron                Check if Laravel's cron is configured (default: $CHECK_CRON)"
    echo "  --check-chcon               Check SELinux & apply contexts (default: $CHECK_CHCON)"
    echo ""
    echo "  --os-type=[auto|debian|rhel] OS detection or forced type (default: $OS_TYPE)"
    echo "  --project-dir=PATH          Project directory (default: $PROJECT_DIR)"
    echo "  --web-user=USER             Web server user (default: $WEB_USER)"
    echo "  --branch=BRANCH             Deployment branch (default: $BRANCH)"
    echo "  --backup-dir=PATH           Backup directory (default: $BACKUP_DIR)"
    echo "  --keep-backups=NUMBER       Keep N backups (default: $KEEP_BACKUPS)"
    echo "  --php-bin=PATH              PHP binary path (default: $PHP_BIN)"
    echo "  --composer-bin=PATH         Composer binary path (default: $COMPOSER_BIN)"
    echo ""
    echo "  -h, --help                  Show this help and exit"
    exit 0
}

# -------------------------
# 1. SOURCE laravel-deploy.env IF PRESENT
# -------------------------
if [ -f "./laravel-deploy.env" ]; then
    # This will export variables in laravel-deploy.env into our shell environment
    # (They are typically named LARAVEL_DEPLOY_* for the script to read them.)
    # But the user might also name them exactly e.g. PROJECT_DIR=...
    # We'll just trust they set them properly if they want to override.
    echo "Loading variables from laravel-deploy.env..."
    set -a
    source ./laravel-deploy.env
    set +a
fi

# -------------------------
# 2. OVERRIDE FROM ENV VARIABLES (PREFIX LARAVEL_DEPLOY_)
# -------------------------
PROJECT_DIR="${LARAVEL_DEPLOY_PROJECT_DIR:-$PROJECT_DIR}"
DEPLOY_SCRIPT="${LARAVEL_DEPLOY_DEPLOY_SCRIPT:-$DEPLOY_SCRIPT}"
OS_TYPE="${LARAVEL_DEPLOY_OS_TYPE:-$OS_TYPE}"
WEB_USER="${LARAVEL_DEPLOY_WEB_USER:-$WEB_USER}"
BRANCH="${LARAVEL_DEPLOY_BRANCH:-$BRANCH}"
BACKUP_DIR="${LARAVEL_DEPLOY_BACKUP_DIR:-$BACKUP_DIR}"
KEEP_BACKUPS="${LARAVEL_DEPLOY_KEEP_BACKUPS:-$KEEP_BACKUPS}"
GIT_URL="${LARAVEL_DEPLOY_GIT_URL:-$GIT_URL}"
ENV_FILE_PATH="${LARAVEL_DEPLOY_ENV_FILE_PATH:-$ENV_FILE_PATH}"
PHP_BIN="${LARAVEL_DEPLOY_PHP_BIN:-$PHP_BIN}"
COMPOSER_BIN="${LARAVEL_DEPLOY_COMPOSER_BIN:-$COMPOSER_BIN}"

# Convert "true"/"false" env values into booleans if needed
# We do a naive approach: "true" => $var = true, else if "false" => $var = false, else do nothing
envBool() {
    local val="$1"
    if [ "$val" = "false" ] || [ "$val" = "FALSE" ]; then echo false; else echo true; fi
}

# Overriding booleans, if set
if [ -n "$LARAVEL_DEPLOY_ENABLE_BACKUP" ]; then
    ENABLE_BACKUP=$(envBool "$LARAVEL_DEPLOY_ENABLE_BACKUP")
fi
if [ -n "$LARAVEL_DEPLOY_ENABLE_MAINTENANCE" ]; then
    ENABLE_MAINTENANCE=$(envBool "$LARAVEL_DEPLOY_ENABLE_MAINTENANCE")
fi
if [ -n "$LARAVEL_DEPLOY_RUN_MIGRATIONS" ]; then
    RUN_MIGRATIONS=$(envBool "$LARAVEL_DEPLOY_RUN_MIGRATIONS")
fi
if [ -n "$LARAVEL_DEPLOY_CLEAR_CACHE" ]; then
    CLEAR_CACHE=$(envBool "$LARAVEL_DEPLOY_CLEAR_CACHE")
fi
if [ -n "$LARAVEL_DEPLOY_SET_PERMISSIONS" ]; then
    SET_PERMISSIONS=$(envBool "$LARAVEL_DEPLOY_SET_PERMISSIONS")
fi
if [ -n "$LARAVEL_DEPLOY_RESTART_SUPERVISOR" ]; then
    RESTART_SUPERVISOR=$(envBool "$LARAVEL_DEPLOY_RESTART_SUPERVISOR")
fi
if [ -n "$LARAVEL_DEPLOY_CHECK_CRON" ]; then
    CHECK_CRON=$(envBool "$LARAVEL_DEPLOY_CHECK_CRON")
fi
if [ -n "$LARAVEL_DEPLOY_CHECK_CHCON" ]; then
    CHECK_CHCON=$(envBool "$LARAVEL_DEPLOY_CHECK_CHCON")
fi
if [ -n "$LARAVEL_DEPLOY_CREATE_STORAGE_LINK" ]; then
    CREATE_STORAGE_LINK=$(envBool "$LARAVEL_DEPLOY_CREATE_STORAGE_LINK")
fi
if [ -n "$LARAVEL_DEPLOY_DEBUG_MODE" ]; then
    DEBUG_MODE=$(envBool "$LARAVEL_DEPLOY_DEBUG_MODE")
fi
if [ -n "$LARAVEL_DEPLOY_UNSECURE_MODE" ]; then
    UNSECURE_MODE=$(envBool "$LARAVEL_DEPLOY_UNSECURE_MODE")
fi

# -------------------------
# 3. PARSE SCRIPT ARGUMENTS (Highest Precedence)
# -------------------------
for arg in "$@"; do
  case $arg in
    --debug) DEBUG_MODE=true ;;
    --unsecure) UNSECURE_MODE=true ;;
    --no-backup) ENABLE_BACKUP=false ;;
    --no-maintenance) ENABLE_MAINTENANCE=false ;;
    --no-migrate) RUN_MIGRATIONS=false ;;
    --no-cache-clear) CLEAR_CACHE=false ;;
    --no-permissions) SET_PERMISSIONS=false ;;
    --no-supervisor) RESTART_SUPERVISOR=false ;;
    --no-storage-link) CREATE_STORAGE_LINK=false ;;
    --check-cron) CHECK_CRON=true ;;
    --check-chcon) CHECK_CHCON=true ;;
    --os-type=*) OS_TYPE="${arg#*=}" ;;
    --project-dir=*) PROJECT_DIR="${arg#*=}" ;;
    --git-url=*) GIT_URL="${arg#*=}" ;;
    --env-file=*) ENV_FILE_PATH="${arg#*=}" ;;
    --web-user=*) WEB_USER="${arg#*=}" ;;
    --branch=*) BRANCH="${arg#*=}" ;;
    --backup-dir=*) BACKUP_DIR="${arg#*=}" ;;
    --keep-backups=*) KEEP_BACKUPS="${arg#*=}" ;;
    --php-bin=*) PHP_BIN="${arg#*=}" ;;
    --composer-bin=*) COMPOSER_BIN="${arg#*=}" ;;
    -h|--help) show_help ;;
  esac
done

# Now let's do OS auto-detect if the user hasn't set a different web user
if [[ ! "$@" =~ --web-user= ]]; then
    auto_detect_os
fi

echo -e "${GREEN}Starting deployment...${RESET}"
echo "--------------------------------------------------------------------------------"
echo "ALL SETTINGS AFTER env-file / ENV-VARS / CLI MERGE:"
echo "--------------------------------------------------------------------------------"
echo "  DEBUG_MODE              = $DEBUG_MODE"
echo "  UNSECURE_MODE           = $UNSECURE_MODE"
echo "  OS_TYPE                 = $OS_TYPE"
echo "  WEB_USER                = $WEB_USER"
echo "  BRANCH                  = $BRANCH"
echo "  PROJECT_DIR             = $PROJECT_DIR"
echo "  GIT_URL                 = ${GIT_URL:-'(none)'}"
echo "  ENV_FILE_PATH           = ${ENV_FILE_PATH:-'(none)'}"
echo "  BACKUP_DIR              = $BACKUP_DIR"
echo "  KEEP_BACKUPS            = $KEEP_BACKUPS"
echo "  PHP_BIN                 = $PHP_BIN"
echo "  COMPOSER_BIN            = $COMPOSER_BIN"
echo ""
echo "  ENABLE_BACKUP           = $ENABLE_BACKUP"
echo "  ENABLE_MAINTENANCE      = $ENABLE_MAINTENANCE"
echo "  RUN_MIGRATIONS          = $RUN_MIGRATIONS"
echo "  CLEAR_CACHE             = $CLEAR_CACHE"
echo "  SET_PERMISSIONS         = $SET_PERMISSIONS"
echo "  RESTART_SUPERVISOR      = $RESTART_SUPERVISOR"
echo "  CHECK_CRON              = $CHECK_CRON"
echo "  CHECK_CHCON             = $CHECK_CHCON"
echo "  CREATE_STORAGE_LINK     = $CREATE_STORAGE_LINK"
echo "--------------------------------------------------------------------------------"

# Mandatory .env if GIT_URL is used
if [ -n "$GIT_URL" ]; then
    if [ -z "$ENV_FILE_PATH" ]; then
        error "You used --git-url but no --env-file was provided. A .env is mandatory for fresh clone."
        exit 1
    fi
    if [ ! -f "$ENV_FILE_PATH" ]; then
        error "The specified --env-file does not exist: $ENV_FILE_PATH"
        exit 1
    fi
fi

# Variables for final summary
code_backup_path=""
db_backup_path=""
GIT_COMMIT_ID=""
GIT_COMMIT_MESSAGE=""

# ---------------
# The rest of the script is the same logic as before
# Steps: 1) cron check, 2) SELinux, 3) clone, 4) symlink, 5) backup, etc...
# ---------------

# (Omitting re-commenting all steps for brevity - same as prior version)

# -------------------------
# 1. CHECK CRON JOB
# -------------------------
if [ "$CHECK_CRON" = true ]; then
    step "1" "Checking Laravel cron job..."
    if [ "$DEBUG_MODE" = true ]; then
        echo "Command: crontab -l | grep 'artisan schedule:run'"
    fi
    CRON_STATUS=$(crontab -l 2>/dev/null | grep "artisan schedule:run" || true)
    if [ -z "$CRON_STATUS" ]; then
        error "Scheduler not configured! Please add: * * * * * $PHP_BIN $PROJECT_DIR/artisan schedule:run >> /dev/null 2>&1"
    else
        success "Laravel scheduler is configured."
    fi
else
    step "1" "Skipping cron check..."
fi

# -------------------------
# 2. CHECK & APPLY SELinux
# -------------------------
if [ "$CHECK_CHCON" = true ]; then
    step "2" "Checking SELinux contexts..."
    if [ "$DEBUG_MODE" = true ]; then
        echo "Command: which semanage && which restorecon"
    fi
    if command -v semanage >/dev/null 2>&1 && command -v restorecon >/dev/null 2>&1; then
        if [ "$DEBUG_MODE" = true ]; then
            echo "Command: sudo semanage fcontext -a -t httpd_sys_rw_content_t \"$PROJECT_DIR/storage(/.*)?\""
            echo "Command: sudo semanage fcontext -a -t httpd_sys_rw_content_t \"$PROJECT_DIR/bootstrap/cache(/.*)?\""
            echo "Command: sudo restorecon -R \"$PROJECT_DIR/storage\" \"$PROJECT_DIR/bootstrap/cache\""
        fi
        sudo semanage fcontext -a -t httpd_sys_rw_content_t "$PROJECT_DIR/storage(/.*)?" 2>/dev/null || warn "semanage fcontext failed."
        sudo semanage fcontext -a -t httpd_sys_rw_content_t "$PROJECT_DIR/bootstrap/cache(/.*)?" 2>/dev/null || warn "semanage fcontext failed."
        sudo restorecon -R "$PROJECT_DIR/storage" "$PROJECT_DIR/bootstrap/cache" 2>/dev/null || warn "restorecon failed."
        success "SELinux contexts applied."
    else
        error "SELinux tools (semanage, restorecon) not found/disabled. Skipping."
    fi
else
    step "2" "Skipping SELinux context check..."
fi

# -------------------------
# 3. CLONE GIT REPO
# -------------------------
if [ -n "$GIT_URL" ]; then
    step "3" "Preparing project directory for clone if needed..."
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "  - Directory $PROJECT_DIR does not exist. Creating..."
        run_cmd mkdir -p "$PROJECT_DIR" || { error "Failed to mkdir: $PROJECT_DIR"; exit 1; }
    fi
    if [ -z "$(ls -A "$PROJECT_DIR" 2>/dev/null)" ]; then
        echo "  - Directory is empty. Cloning from $GIT_URL..."
        run_cmd git clone "$GIT_URL" "$PROJECT_DIR" || { error "Failed to clone $GIT_URL"; exit 1; }
        success "Repository cloned successfully."
        echo "  - Copying .env from $ENV_FILE_PATH"
        run_cmd cp "$ENV_FILE_PATH" "$PROJECT_DIR/.env" || { error "Failed copying .env"; exit 1; }
        success ".env file in place."
    else
        echo "  - $PROJECT_DIR is not empty."
        if [ ! -d "$PROJECT_DIR/.git" ]; then
            warn "Directory is not a Git repo. If that's intentional, ignore."
        else
            echo "  - Existing Git repo; normal Git steps apply."
        fi
    fi
else
    step "3" "No Git URL; skipping clone."
fi

# -------------------------
# 4. STORAGE SYMLINK
# -------------------------
if [ "$CREATE_STORAGE_LINK" = true ]; then
    step "4" "Checking storage symlink..."
    if [ ! -L "$PROJECT_DIR/public/storage" ]; then
        echo "  - Symlink not found. Creating..."
        artisan storage:link || warn "Failed to create symlink."
        success "Symlink created."
    else
        link_target="$(readlink "$PROJECT_DIR/public/storage")"
        echo "  - Symlink exists: $link_target"
    fi
else
    step "4" "Skipping storage symlink..."
fi

# -------------------------
# 5. BACKUP CODE & DB
# -------------------------
if [ "$ENABLE_BACKUP" = true ]; then
    step "5" "Creating backup..."
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CURRENT_BACKUP_DIR="$BACKUP_DIR/$TIMESTAMP"
    echo "  - Creating $CURRENT_BACKUP_DIR"
    run_cmd sudo mkdir -p "$CURRENT_BACKUP_DIR" || warn "Failed mkdir backup."
    run_cmd sudo chown "$USER":"$USER" "$CURRENT_BACKUP_DIR" || warn "Failed chown backup."
    echo "  - Backing up code..."
    if [ "$DEBUG_MODE" = true ]; then
        echo "Command: tar -czf \"$CURRENT_BACKUP_DIR/code.tar.gz\" --exclude='.git' --exclude='node_modules' --exclude='vendor' -C \"$PROJECT_DIR\" ."
    fi
    tar -czf "$CURRENT_BACKUP_DIR/code.tar.gz" \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='vendor' \
        -C "$PROJECT_DIR" . 2>/dev/null || warn "Code backup failed."
    code_backup_path="$CURRENT_BACKUP_DIR/code.tar.gz"
    echo "  - Removing old backups..."
    if [ "$DEBUG_MODE" = true ]; then
        echo "Command: ( cd \"$BACKUP_DIR\" && ls -dt ./*/ | tail -n +$((KEEP_BACKUPS+1)) | xargs -r sudo rm -rf )"
    fi
    ( cd "$BACKUP_DIR" && ls -dt ./*/ | tail -n +$((KEEP_BACKUPS+1)) | xargs -r sudo rm -rf ) 2>/dev/null || warn "Old backups removal failed."
    
    # DB backup
    if [ -f "$PROJECT_DIR/.env" ]; then
        DB_CONNECTION=$(grep -E "^DB_CONNECTION=" "$PROJECT_DIR/.env" | cut -d= -f2)
        DB_HOST=$(grep -E "^DB_HOST=" "$PROJECT_DIR/.env" | cut -d= -f2)
        DB_DATABASE=$(grep -E "^DB_DATABASE=" "$PROJECT_DIR/.env" | cut -d= -f2)
        DB_USERNAME=$(grep -E "^DB_USERNAME=" "$PROJECT_DIR/.env" | cut -d= -f2)
        DB_PASSWORD=$(grep -E "^DB_PASSWORD=" "$PROJECT_DIR/.env" | cut -d= -f2)
        echo "  - Backing up DB: $DB_CONNECTION => $DB_DATABASE"
        if [ "$UNSECURE_MODE" = true ] && [ "$DEBUG_MODE" = true ]; then
            masked_host="$DB_HOST"
            masked_pass="$DB_PASSWORD"
        else
            masked_host="***"
            masked_pass="******"
        fi
        case "$DB_CONNECTION" in
            mysql)
                if [ -f ~/.my.cnf ]; then
                    if [ "$DEBUG_MODE" = true ]; then
                        echo "Command: mysqldump --defaults-extra-file=~/.my.cnf --host=\"$masked_host\" \"$DB_DATABASE\" | gzip > \"$CURRENT_BACKUP_DIR/db.sql.gz\""
                    fi
                    mysqldump --defaults-extra-file=~/.my.cnf --host="$DB_HOST" "$DB_DATABASE" \
                    | gzip > "$CURRENT_BACKUP_DIR/db.sql.gz" 2>/dev/null || warn "MySQL backup failed."
                    db_backup_path="$CURRENT_BACKUP_DIR/db.sql.gz"
                else
                    if [ "$DEBUG_MODE" = true ]; then
                        echo "Command: env MYSQL_PWD=$masked_pass mysqldump --host=\"$masked_host\" --user=\"$DB_USERNAME\" \"$DB_DATABASE\" | gzip > \"$CURRENT_BACKUP_DIR/db.sql.gz\""
                    fi
                    env MYSQL_PWD="$DB_PASSWORD" mysqldump --host="$DB_HOST" --user="$DB_USERNAME" "$DB_DATABASE" \
                    | gzip > "$CURRENT_BACKUP_DIR/db.sql.gz" 2>/dev/null || warn "MySQL backup failed."
                    db_backup_path="$CURRENT_BACKUP_DIR/db.sql.gz"
                fi
                ;;
            pgsql)
                if [ "$DEBUG_MODE" = true ]; then
                    echo "Command: PGPASSWORD=$masked_pass pg_dump --host=\"$masked_host\" --username=\"$DB_USERNAME\" \"$DB_DATABASE\" | gzip > \"$CURRENT_BACKUP_DIR/db.sql.gz\""
                fi
                PGPASSWORD="$DB_PASSWORD" pg_dump --host="$DB_HOST" --username="$DB_USERNAME" "$DB_DATABASE" \
                | gzip > "$CURRENT_BACKUP_DIR/db.sql.gz" 2>/dev/null || warn "PostgreSQL backup failed."
                db_backup_path="$CURRENT_BACKUP_DIR/db.sql.gz"
                ;;
            *)
                echo "  - Unsupported DB: $DB_CONNECTION. Skipping DB backup."
                ;;
        esac
    else
        echo "  - No .env found; skipping DB backup."
    fi
    success "Backup done: $CURRENT_BACKUP_DIR"
else
    step "5" "Skipping backups..."
fi

# -------------------------
# 6. ENSURE STORAGE FOLDER STRUCTURE
# -------------------------
step "6" "Ensuring storage structure..."
STORAGE_DIRS=( "storage/app" "storage/app/private" "storage/app/public" "storage/logs" "storage/framework" "storage/framework/cache" "storage/framework/cache/data" "storage/framework/sessions" "storage/framework/testing" "storage/framework/views" )
for dir in "${STORAGE_DIRS[@]}"; do
    if [ "$DEBUG_MODE" = true ]; then
        echo "Command: mkdir -p \"$PROJECT_DIR/$dir\" && touch \"$PROJECT_DIR/$dir/.gitignore\""
    fi
    mkdir -p "$PROJECT_DIR/$dir" 2>/dev/null || warn "Failed creating $dir"
    touch "$PROJECT_DIR/$dir/.gitignore" 2>/dev/null || warn "Failed .gitignore in $dir"
done
if [ "$DEBUG_MODE" = true ]; then
    echo "Command: touch $PROJECT_DIR/storage/logs/laravel.log && touch $PROJECT_DIR/storage/logs/worker.log"
fi
touch "$PROJECT_DIR/storage/logs/laravel.log" 2>/dev/null || warn "Failed laravel.log"
touch "$PROJECT_DIR/storage/logs/worker.log" 2>/dev/null || warn "Failed worker.log"
success "Storage verified."

# -------------------------
# 7. FILE PERMISSIONS
# -------------------------
if [ "$SET_PERMISSIONS" = true ]; then
    step "7" "Setting ownership/permissions..."
    if [ "$DEBUG_MODE" = true ]; then
        echo "Command: sudo chown -R \"$WEB_USER\":\"$WEB_USER\" \"$PROJECT_DIR\""
        echo "Command: chmod -R 755 \"$PROJECT_DIR\""
        echo "Command: chmod -R 775 \"$PROJECT_DIR/storage\" \"$PROJECT_DIR/bootstrap/cache\""
        echo "Command: chmod -R 775 \"$PROJECT_DIR/storage/logs\""
        echo "Command: sudo chown -R \"$WEB_USER\":\"$WEB_USER\" \"$PROJECT_DIR/storage/logs\""
    fi
    sudo chown -R "$WEB_USER":"$WEB_USER" "$PROJECT_DIR" 2>/dev/null || warn "Failed chown $PROJECT_DIR"
    chmod -R 755 "$PROJECT_DIR" 2>/dev/null || warn "Failed chmod 755"
    chmod -R 775 "$PROJECT_DIR/storage" "$PROJECT_DIR/bootstrap/cache" 2>/dev/null || warn "Failed chmod 775 on storage/cache"
    chmod -R 775 "$PROJECT_DIR/storage/logs" 2>/dev/null || warn "Failed chmod 775 on logs"
    sudo chown -R "$WEB_USER":"$WEB_USER" "$PROJECT_DIR/storage/logs" 2>/dev/null || warn "Failed chown on logs"
    success "Permissions set."
else
    step "7" "Skipping permissions..."
fi

# -------------------------
# 8. MAINTENANCE MODE
# -------------------------
if [ "$ENABLE_MAINTENANCE" = true ]; then
    step "8" "Enabling maintenance mode..."
    artisan down --quiet || warn "Failed artisan down."
    success "Maintenance mode on."
else
    step "8" "Skipping maintenance mode..."
fi

# -------------------------
# 9. GIT CHECKOUT & COMPOSER
# -------------------------
step "9" "Git fetch/checkout & Composer..."
if [ -d "$PROJECT_DIR/.git" ]; then
    echo "  - Found .git, pulling from branch $BRANCH..."
    if [ "$DEBUG_MODE" = true ]; then
        echo "Command: git -C \"$PROJECT_DIR\" fetch --all --quiet"
        echo "Command: git -C \"$PROJECT_DIR\" checkout \"$BRANCH\" --quiet"
        echo "Command: git -C \"$PROJECT_DIR\" reset --hard \"origin/$BRANCH\" --quiet"
    fi
    git -C "$PROJECT_DIR" fetch --all --quiet 2>/dev/null || warn "git fetch fail."
    git -C "$PROJECT_DIR" checkout "$BRANCH" --quiet 2>/dev/null || warn "git checkout fail."
    git -C "$PROJECT_DIR" reset --hard "origin/$BRANCH" --quiet 2>/dev/null || warn "git reset fail."
    GIT_COMMIT_ID=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "(unknown)")
    GIT_COMMIT_MESSAGE=$(git -C "$PROJECT_DIR" log -1 --pretty=%B 2>/dev/null || echo "(unknown)")
else
    echo "  - No .git found; skipping pull."
fi
if [ -f "$PROJECT_DIR/composer.json" ]; then
    echo "  - composer install..."
    if [ "$DEBUG_MODE" = true ]; then
        echo "Command: $COMPOSER_BIN install --no-dev --no-interaction --prefer-dist --optimize-autoloader --quiet --working-dir \"$PROJECT_DIR\""
    fi
    $COMPOSER_BIN install --no-dev --no-interaction --prefer-dist --optimize-autoloader --quiet --working-dir "$PROJECT_DIR" || warn "composer install fail."
fi
success "Git & Composer done."

# -------------------------
# 10. DATABASE MIGRATIONS
# -------------------------
if [ "$RUN_MIGRATIONS" = true ]; then
    step "10" "Running migrations..."
    artisan migrate --force --seed --quiet || { error "Migrations failed."; exit 1; }
    success "Migrations ok."
else
    step "10" "Skipping migrations..."
fi

# -------------------------
# 11. CACHE CLEAR & OPTIMIZE
# -------------------------
if [ "$CLEAR_CACHE" = true ]; then
    step "11" "Cache clearing/optimizing..."
    artisan optimize:clear --quiet || warn "Failed optimize:clear"
    artisan optimize --quiet || warn "Failed optimize"
    success "Cache done."
else
    step "11" "Skipping cache..."
fi

# -------------------------
# 12. RESTART SUPERVISOR
# -------------------------
if [ "$RESTART_SUPERVISOR" = true ]; then
    step "12" "Supervisor restart..."
    restart_supervisor_service
    success "Supervisor restarted."
else
    step "12" "Skipping Supervisor..."
fi

# -------------------------
# 13. DISABLE MAINTENANCE
# -------------------------
if [ "$ENABLE_MAINTENANCE" = true ]; then
    step "13" "Disabling maintenance..."
    artisan up --quiet || { error "artisan up fail."; exit 1; }
    success "Maintenance off."
fi

# -------------------------
# GATHER FINAL INFO
# -------------------------
PHP_VERSION="$($PHP_BIN -v 2>/dev/null | head -n 1 | awk '{print $1" "$2}')"
[ -z "$PHP_VERSION" ] && PHP_VERSION="(unknown)"

DB_VERSION="(not applicable)"
if [ -f "$PROJECT_DIR/.env" ]; then
    DB_CONNECTION=$(grep -E "^DB_CONNECTION=" "$PROJECT_DIR/.env" | cut -d= -f2)
    DB_HOST=$(grep -E "^DB_HOST=" "$PROJECT_DIR/.env" | cut -d= -f2)
    DB_DATABASE=$(grep -E "^DB_DATABASE=" "$PROJECT_DIR/.env" | cut -d= -f2)
    DB_USERNAME=$(grep -E "^DB_USERNAME=" "$PROJECT_DIR/.env" | cut -d= -f2)
    DB_PASSWORD=$(grep -E "^DB_PASSWORD=" "$PROJECT_DIR/.env" | cut -d= -f2)
    case "$DB_CONNECTION" in
        mysql)
            if command -v mysql >/dev/null 2>&1; then
                temp_ver=$(MYSQL_PWD="$DB_PASSWORD" mysql -N -B -h "$DB_HOST" -u "$DB_USERNAME" -D "$DB_DATABASE" -e "SELECT VERSION();" 2>/dev/null)
                [ -n "$temp_ver" ] && DB_VERSION="MySQL/MariaDB: $temp_ver" || DB_VERSION="(couldn't connect / unknown)"
            else
                DB_VERSION="(mysql client not found)"
            fi
            ;;
        pgsql)
            if command -v psql >/dev/null 2>&1; then
                temp_ver=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_DATABASE" -t -c "SELECT version();" 2>/dev/null | tr -d '[:space:]')
                [ -n "$temp_ver" ] && DB_VERSION="PostgreSQL: $temp_ver" || DB_VERSION="(couldn't connect / unknown)"
            else
                DB_VERSION="(psql client not found)"
            fi
            ;;
    esac
fi

DISK_LINE="$(df -h "$PROJECT_DIR" 2>/dev/null | tail -1)"
DISK_MOUNT="$(echo "$DISK_LINE" | awk '{print $6}')"
TOTAL_DISK="$(echo "$DISK_LINE" | awk '{print $2}')"
USED_DISK="$(echo "$DISK_LINE" | awk '{print $3}')"
AVAIL_DISK="$(echo "$DISK_LINE" | awk '{print $4}')"
[ -z "$DISK_MOUNT" ] && DISK_MOUNT="(unknown)"

# -------------------------
# FINAL SUMMARY
# -------------------------
echo -e "\n${GREEN}✅ Deployment completed successfully!${RESET}"
echo "--------------------------------------------------------"
echo "Deployment Summary:"
echo "--------------------------------------------------------"
echo "  DEBUG_MODE          : $DEBUG_MODE"
echo "  UNSECURE_MODE       : $UNSECURE_MODE"
echo "  OS_TYPE             : $OS_TYPE"
echo "  WEB_USER            : $WEB_USER"
echo "  PROJECT_DIR         : $PROJECT_DIR"
echo "  GIT_URL             : ${GIT_URL:-'(none)'}"
echo "  ENV_FILE_PATH       : ${ENV_FILE_PATH:-'(none)'}"
echo "  BRANCH              : $BRANCH"

if [ -n "$GIT_COMMIT_ID" ]; then
    echo "  Last Commit ID      : $GIT_COMMIT_ID"
    echo "  Last Commit Msg     : $GIT_COMMIT_MESSAGE"
else
    echo "  Last Commit ID      : (no .git or unknown)"
    echo "  Last Commit Msg     : (no .git or unknown)"
fi

if [ "$ENABLE_BACKUP" = true ]; then
    echo "  Code Backup         : ${code_backup_path:-'(skipped or failed)'}"
    if [ -n "$db_backup_path" ]; then
        echo "  DB Backup           : $db_backup_path"
    else
        echo "  DB Backup           : (not performed or unsupported DB)"
    fi
else
    echo "  Code Backup         : (disabled)"
    echo "  DB Backup           : (disabled)"
fi

echo ""
echo "  PHP Version         : ${PHP_VERSION:-'(unknown)'}"
echo "  DB Version          : ${DB_VERSION:-'(unknown)'}"
if [ -n "$DISK_MOUNT" ] && [ -n "$TOTAL_DISK" ]; then
    echo "  Disk Usage          : $USED_DISK / $TOTAL_DISK (Free: $AVAIL_DISK) on $DISK_MOUNT"
else
    echo "  Disk Usage          : (unavailable)"
fi

echo ""
echo "  ENABLE_BACKUP       : $ENABLE_BACKUP"
echo "  ENABLE_MAINTENANCE  : $ENABLE_MAINTENANCE"
echo "  RUN_MIGRATIONS      : $RUN_MIGRATIONS"
echo "  CLEAR_CACHE         : $CLEAR_CACHE"
echo "  SET_PERMISSIONS     : $SET_PERMISSIONS"
echo "  RESTART_SUPERVISOR  : $RESTART_SUPERVISOR"
echo "  CHECK_CRON          : $CHECK_CRON"
echo "  CHECK_CHCON         : $CHECK_CHCON"
echo "  CREATE_STORAGE_LINK : $CREATE_STORAGE_LINK"
echo "--------------------------------------------------------"
exit 0
