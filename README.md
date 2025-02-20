# 🚀 Laravel Deployment Script

![Laravel Deployment](laravel.gif)

Easily automate your **Laravel** deployments with this flexible shell script. Designed for seamless **Continuous Deployment (CD)** on Linux servers.

## ✨ Features

✅ **OS Detection**: Auto-detects **Debian**, **RHEL**, or lets you choose manually.  
✅ **Backup System**: Automatically backs up **code & database** before deploying.  
✅ **Scheduler Check**: Ensures the **Laravel cron job** is installed and running.  
✅ **Storage & Permissions**: Sets up Laravel **storage** directories and fixes permissions.  
✅ **Cache Optimization**: Clears and optimizes **views, config, routes, etc.**  
✅ **Database Migrations**: Runs migrations & seeding (can be skipped).  
✅ **Queue Management**: Restarts **Supervisor & queue workers** after deployment.  
✅ **Maintenance Mode**: Enables during deployment and disables after (optional).  
✅ **SELinux Handling**: Configures correct file permissions automatically.  
✅ **Dependency Installation**: Installs new Composer packages when needed.  
✅ **Deployment Summary**: Displays a **detailed status report** post-deployment.

---

## 🖥️ Supported Linux Distributions

This script works with all major Linux distributions:

```text
✅ Ubuntu
✅ Debian
✅ Rocky Linux
✅ AlmaLinux
✅ CentOS
✅ RHEL
```

---

## 🚀 Getting Started

### 📥 1️⃣ Clone This Repository
```bash
git clone https://github.com/omar-haris/laravel-deploy.git
cd laravel-deploy
```

### 🔑 2️⃣ Make the Script Executable
```bash
chmod +x laravel-deploy.sh
```

### ▶️ 3️⃣ Run the Script
```bash
./laravel-deploy.sh -h
```
💡 **Tip:** Run `-h` to see all available options.

---

## 🛠️ Deployment Options

### 🌍 **Deploy an Existing Project**
```bash
./laravel-deploy.sh \
  --project-dir=/var/www/laravel \
  --branch=main
```

### 🆕 **Deploy a New Project from Git**
```bash
./laravel-deploy.sh \
  --git-url=https://github.com/your/repo.git \
  --env-file=your-env-file.env \
  --project-dir=/var/www/laravel \
  --branch=main
```

### 🐛 **Debug Mode**
```bash
# Mask sensitive information (default)
./laravel-deploy.sh --debug

# Show actual credentials (use with caution!)
./laravel-deploy.sh --debug --unsecure
```

---

## ⚙️ Available Options

| Option | Description |
|--------|-------------|
| `--git-url=URL` | Clone the project if the directory is empty |
| `--env-file=PATH` | Provide `.env` for fresh clones |
| `--debug` | Print commands (masks DB credentials by default) |
| `--unsecure` | Reveal actual DB credentials (use with `--debug`) |
| `--no-backup` | Skip backup of code & database |
| `--no-maintenance` | Skip enabling maintenance mode |
| `--no-migrate` | Skip running migrations |
| `--no-cache-clear` | Skip clearing and optimizing cache |
| `--no-permissions` | Skip setting folder permissions |
| `--no-supervisor` | Skip restarting Supervisor |
| `--check-cron` | Verify Laravel's cron configuration (default: true) |
| `--os-type=[auto|debian|rhel]` | Auto-detect or specify OS (default: auto) |
| `--project-dir=PATH` | Define the Laravel project directory |
| `--branch=BRANCH` | Specify deployment branch (default: `main`) |

---

## 📊 Deployment Summary Output

After deployment, a summary like this will be displayed:

```bash
--------------------------------------------------------
Deployment Summary:
--------------------------------------------------------
  DEBUG_MODE          : false
  OS_TYPE             : auto
  WEB_USER            : www-data
  PROJECT_DIR         : /var/www/laravel
  GIT_URL             : '(none)'
  BRANCH              : main
  Last Commit ID      : cc316d6
  Code Backup         : /var/backups/laravel/code.tar.gz
  DB Backup           : /var/backups/laravel/db.sql.gz
  PHP Version         : PHP 8.1.31
  Disk Usage          : 4.3G / 75G (Free: 68G)
--------------------------------------------------------
```

---

## 📜 License

This project is licensed under the **MIT License**.

```text
The MIT License (MIT)
=====================

© 2025 Omar Haris

Permission is granted, free of charge, to any person obtaining a copy
of this software to use, modify, distribute, and sell copies.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
```
