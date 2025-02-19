# laravel-deploy.sh

Automate the deployment of Laravel applications with this simple and flexible shell script. Designed for seamless **Continuous Deployment (CD)** on Linux servers.

## Supported Linux Distributions

This script is compatible with all modern Linux distributions, including:

```text
Ubuntu, Debian, Rocky Linux, AlmaLinux, CentOS, RHEL
```

## Getting Started

### 1️⃣ Clone This Repository

```bash
git clone https://github.com/omar-haris/laravel-deploy.git
cd laravel-deploy
```

### 2️⃣ Make the Script Executable

```bash
chmod +x laravel-deploy.sh
```

### 3️⃣ Run the Script

```bash
./laravel-deploy.sh
```

That’s it! The script will execute the deployment process and display a summary upon completion.

## Deployment Options

### Existing Project Deployment

```bash
./laravel-deploy.sh \
  --project-dir=/var/www/laravel \
  --branch=main
```


### New Project Deployment

```bash
./laravel-deploy.sh \
  --git-url=https://github.com/your/repo.git \
  --env-file=laravel-config-file-if-a-repo-used-no-need-if-dir-already-exists.env \
  --project-dir=/var/www/laravel \
  --branch=main
```

### Debug Mode

```bash
# Mask sensitive information (default)
./laravel-deploy.sh --debug

# Show actual credentials (use with caution!)
./laravel-deploy.sh --debug --unsecure
```

## Available Options

```bash
Usage: ./laravel-deploy.sh [OPTIONS]

  --git-url=URL               Clone from this URL if the project directory is empty
  --env-file=PATH             Provide .env file for fresh clones (required with --git-url)
  --debug                     Print commands (masks DB password/IP by default)
  --unsecure                  Reveal actual DB password/IP (use with --debug)
  
  --no-backup                 Skip backup of code and database
  --no-maintenance            Skip enabling maintenance mode
  --no-migrate                Skip running database migrations
  --no-cache-clear            Skip cache clearing and optimization
  --no-permissions            Skip setting file/folder permissions
  --no-supervisor             Skip restarting Supervisor
  --no-storage-link           Skip creating storage symlink
  
  --check-cron                Verify Laravel's cron configuration (default: true)
  --check-chcon               Check SELinux & apply contexts (default: true)
  
  --os-type=[auto|debian|rhel] Auto-detect or specify OS type (default: auto)
  --project-dir=PATH          Define the project directory (default: /var/www/laravel)
  --web-user=USER             Set the web server user (default: www-data)
  --branch=BRANCH             Specify deployment branch (default: main)
  --backup-dir=PATH           Set backup directory (default: /var/backups/laravel)
  --keep-backups=NUMBER       Number of backups to retain (default: 7)
  --php-bin=PATH              Specify PHP binary path (default: /usr/bin/php)
  --composer-bin=PATH         Define Composer binary path (default: /usr/local/bin/composer)

  -h, --help                  Display help message and exit
```

## Deployment Summary Output

Upon successful deployment, a summary report will be displayed:

```bash
--------------------------------------------------------
Deployment Summary:
--------------------------------------------------------
  DEBUG_MODE          : false
  UNSECURE_MODE       : false
  OS_TYPE             : auto
  WEB_USER            : www-data
  PROJECT_DIR         : /var/www/laravel
  GIT_URL             : '(none)'
  ENV_FILE_PATH       : '(none)'
  BRANCH              : main
  Last Commit ID      : cc316d6
  Last Commit Msg     : Added images
  Code Backup         : /var/backups/laravel/20250219_180725/code.tar.gz
  DB Backup           : /var/backups/laravel/20250219_180725/db.sql.gz
  
  PHP Version         : PHP 8.1.31
  DB Version          : MySQL/MariaDB: 8.0.41-0ubuntu0.24.04.1
  Disk Usage          : 4.3G / 75G (Free: 68G) on /
  
  ENABLE_BACKUP       : true
  ENABLE_MAINTENANCE  : true
  RUN_MIGRATIONS      : true
  CLEAR_CACHE         : true
  SET_PERMISSIONS     : true
  RESTART_SUPERVISOR  : true
  CHECK_CRON          : true
  CHECK_CHCON         : true
  CREATE_STORAGE_LINK : true
--------------------------------------------------------
```

## License

This project is licensed under the **MIT License**.

```text
The MIT License (MIT)
=====================

© 2025 Omar Haris

Permission is granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"),
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES, OR OTHER LIABILITY, ARISING FROM, OUT OF, OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

