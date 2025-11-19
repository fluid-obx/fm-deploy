# fm-launch
### Systemd-Enabled Linux Base Image for FileMaker Server & OttoFMS

## About
**fm-launch** is the **no-nonsense way to run FileMaker Server in Docker**.
No fake systemd, no brittle entrypoints, no endless reboot loops.
Just a clean Linux base, a real systemd boot, a one-time install, and a rock-solid image you can deploy anywhere.

**If you’re done fighting FileMaker inside containers, this is your launchpad.**

---

## Why fm-launch Exists
FileMaker Server requires:
- systemd as PID 1
- cgroup controllers
- journald
- proper service supervision
- multi-user.target boot

These components **do not exist** during Dockerfile build**,** which makes traditional scripted installs unreliable. Installing FMS during a `docker build` leads to:

- broken systemd units
- incomplete service registration
- fmshelper failures
- infinite restart loops

**fm-launch fixes this** by separating the workflow into two clean phases:

1. Build a **systemd-capable base image**
2. Perform a **one-time interactive installation**
3. Commit the result as a **stable, production-ready runtime image**

This avoids all the pitfalls of fake systemd hacks, bootstrap loops, or unreliable entrypoint scripts.

---

# 🚧 Project Workflow

## 🧱 Phase 1 — Build the Base Image
A minimal Linux systemd container with:

- True systemd (PID 1) support
- ODBC drivers (MariaDB/MySQL)
- Microsoft Core Fonts
- Nginx
- Unix utilities for debugging and maintenance
- `fmserver` user created
- All FileMaker dependencies pre-installed

Build it:

```bash
docker build -t ghcr.io/YOURUSER/fm-launch:base .
```

Push it (optional):

```bash
docker push ghcr.io/YOURUSER/fm-launch:base
```

---

## 🚀 Phase 2 — One-Time Interactive Installation

Start a container that boots systemd correctly:

```bash
docker run -it --privileged   -v /sys/fs/cgroup:/sys/fs/cgroup:rw   -v /path/to/fms-installer:/install   -v /path/to/config:/config   ghcr.io/YOURUSER/fm-launch:base
```

Inside the container:

1. Place your `.deb` installer into `/install`
2. Place your `Assisted Install.txt` in the project root
3. Run:

   ```bash
   ./go.sh
   ```

4. Verify FMS services:

   ```bash
   systemctl status fmshelper.service
   ```

5. Verify OttoFMS install and boot:

   ```bash
   systemctl status ottofms-proofgeist-com.service
   ```

If everything is healthy, proceed to commit the image.

---

## 📦 Phase 3 — Commit the Installed Image

After exiting the container:

```bash
docker commit <container_id> ghcr.io/YOURUSER/fm-launch:fms22
docker push ghcr.io/YOURUSER/fm-launch:fms22
```

This becomes your **golden FileMaker Server image**.

---

## ▶️ Phase 4 — Runtime Deployment (docker-compose)

Example `compose.yaml`:

```yaml
services:
  fms:
    image: ghcr.io/YOURUSER/fm-launch:fms22
    container_name: filemaker-server
    privileged: true
    restart: unless-stopped

    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - /host/databases:/opt/FileMaker/FileMaker Server/Data/Databases

    ports:
      - "443:443"
      - "5003:5003"
      - "2399:2399"
```

---

## Repository Structure

```
/
├── Dockerfile
├── go.sh
├── Assisted Install.txt
├── compose.example.yaml
└── README.md
```

---

## Security Notes
- Do not commit secrets to this repository.
- Use `.env` or GitHub Actions secrets for tokens.
- GHCR images may be public or private depending on your workflow.

---

## Requirements
- Docker Engine ≥ 24
- Docker Compose v2
- Linux host or VM recommended

---

## License
MIT License
