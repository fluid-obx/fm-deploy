# 🚀 FileMaker Server in Docker (Ubuntu + systemd)
### **A production-ready FileMaker Server image**

Welcome to a **sane, repeatable, no-nonsense** way to run **Claris FileMaker Server** inside Docker. This project produces a **fully installed, snapshot-clean FileMaker Server image** published to GHCR, install-once and run anywhere.

---

# 🎯 What This Project Actually Delivers

✔ **A clean Ubuntu base image with systemd**
✔ **All required FMS dependencies preinstalled**
✔ **A one-time installation container** that runs the full FMS installer
✔ **Automatic Assisted Install handling**
✔ **Automatic OttoFMS installation**
✔ **Instant startup**: FMS just boots — zero installation needed
✔ **A reusable golden image** you can pull from GHCR
✔ Runs on any host with **exec-enabled storage**

---

# 🧱 Architecture Overview

### **1. Base Image (`fms-os`)**
Ubuntu + systemd + dependencies (fonts, ODBC, iproute2, nginx, etc.)

### **2. One-Time Installer (`compose.install.yaml`)**
- boots systemd
- loads `.env`
- validates installer
- copies Assisted Install
- installs FileMaker Server
- installs OttoFMS
- runs health checks
- writes logs to `/share/logs`

### **3. Production Runtime (`compose.yaml`)**
Pulls your GHCR image:

```
ghcr.io/fluid-obx/fms-22.0.2:3.0.1
ghcr.io/fluid-obx/fms-22.0.2:latest
```

---

# 🏭 Build Process

## **1 — Build base**
```
docker build -t fms-os .
docker tag fms-os ghcr.io/fluid-obx/fms-os:latest
docker push ghcr.io/fluid-obx/fms-os:latest
```

## **2 — Run installer**
```
docker compose -f compose.install.yaml up
```

## **3 — Commit golden image**
```
docker commit filemaker-control fms-22.0.2:3.0.1
docker tag fms-22.0.2:3.0.1 ghcr.io/fluid-obx/fms-22.0.2:3.0.1
docker tag fms-22.0.2:3.0.1 ghcr.io/fluid-obx/fms-22.0.2:latest
docker push ghcr.io/fluid-obx/fms-22.0.2:3.0.1
docker push ghcr.io/fluid-obx/fms-22.0.2:latest
```

---

# ⚠️ Requirements

### **1. NO `noexec` on your mount**
Check:
```
mount | grep <path>
```

### **2. Must run on a real Linux host**
Docker Desktop is not supported.

### **3. Supply your own FileMaker Server installer**

---

# 🚦 Production Compose

```yaml
services:
  fms:
    image: ghcr.io/fluid-obx/fms-22.0.2:latest
    privileged: true
    restart: unless-stopped
    tmpfs:
      - /run
      - /run/lock
      - /var/log/journal
    env_file:
      - ./.env
    volumes:
      - ${COMPOSE_DATA_PATH}:/opt/FileMaker/FileMaker Server
      - ${COMPOSE_OTTO_PATH}:/opt/OttoFMS
      - ${COMPOSE_CONFIG_PATH}:/config
      - ${PATH_SHARE}:/share
      - ${COMPOSE_INSTALL_PATH}:/install
```

---

# 📄 License

Automation only — bring your own FileMaker Server license + installer.

---

# 🎤 Final Word

You now have a reliable, repeatable, production-grade FMS deployment pipeline.
