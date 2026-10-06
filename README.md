# Telegram Local Bot API Server

A production-grade, reusable Docker and Portainer infrastructure setup for running Telegram's official Local Bot API server.

---

## 1. What This Repository Is

This repository provides an automated, reproducible Docker build and Portainer-ready Docker Compose stack to run a centralized **Telegram Local Bot API Server**.

Running a local Telegram Bot API server enables your bots to:
- Download files without Telegram's standard 20MB limit.
- Upload files up to 2,000MB (2GB).
- Process local file paths directly via `file://` URIs without network round-trips.
- Improve response latency by running TDLib closer to your bot services.

## 2. What This Repository Is NOT

- **NOT an MTProto User-Account Server**: This server does not interact with user Telegram accounts, user sessions, telethon/pyrogram userbots, or MTProto client libraries.
- **NOT a Bot Application**: It does not contain bot logic, YouTube Downloader code, SongTaggerBot code, or custom application tokens.
- **NOT a Custom/Third-Party Server**: It builds the official C++ source code provided directly by the Telegram team at [tdlib/telegram-bot-api](https://github.com/tdlib/telegram-bot-api).

---

## 3. Architecture

Instead of bundling a separate Bot API server inside every bot's stack, one centralized Local Bot API server serves multiple independent bot stacks over a shared Docker bridge network.

```text
Portainer
│
├── [Stack] telegram-bot-api
│   └── container: telegram-bot-api (port 8081 internal)
│         ▲
│         │ (Docker network: telegram-bots)
│         ├──────────────────────────────┐
│         │                              │
├── [Stack] youtube-downloader      [Stack] songtaggerbot
│   └── bot connects to:                └── bot connects to:
│       http://telegram-bot-api:8081        http://telegram-bot-api:8081
│
└── [Stack] future-bots...
    └── bot connects to:
        http://telegram-bot-api:8081
```

---

## 4. Pinned Version & Reproducibility

To ensure deterministic and reproducible builds, this repository pins the official Telegram Bot API source code to a specific stable commit rather than tracking an unpinned master branch:

| Component | Repository | Pinned Reference | Release / Notes |
| :--- | :--- | :--- | :--- |
| **telegram-bot-api** | [tdlib/telegram-bot-api](https://github.com/tdlib/telegram-bot-api) | `e3e9dd8e5b3d7ab8537cd5a10dc31d5ffa8f82d1` | Version 10.3 + `RichBlockDocument` fix |
| **td** (submodule) | [tdlib/td](https://github.com/tdlib/td) | `bc9c263e2bfee06aaab41e82db51a103376030bc` | TDLib reference used by commit `e3e9dd8` |

The multi-stage `Dockerfile` clones this exact commit and compiles the binary using CMake in Release mode inside Alpine Linux.

---

## 5. Prerequisites

Before deploying the stack, ensure you have:

1. **Docker & Portainer** installed and running on your host/VPS.
2. **Telegram API Credentials**:
   - `TELEGRAM_API_ID`
   - `TELEGRAM_API_HASH`
   *(Obtained from [https://my.telegram.org](https://my.telegram.org) under **API development tools**)*.
3. **Shared External Docker Network**:
   The Docker network `telegram-bots` **must exist** before deploying this stack.

### Creating the Shared Network

If the network has not already been created on your Docker host, create it using either method:

**Via CLI:**
```bash
docker network create telegram-bots
```

**Via Portainer Web UI:**
1. Navigate to **Networks** in the left sidebar.
2. Click **Add network**.
3. Set **Name**: `telegram-bots`.
4. Driver: `bridge`.
5. Click **Create the network**.

---

## 6. Portainer Deployment Instructions

This stack is designed to be deployed directly from GitHub using Portainer:

1. Open your **Portainer** dashboard.
2. Go to **Stacks** → **Add stack**.
3. Select **Repository** (Git repository).
4. Configure the repository settings:
   - **Name**: `telegram-bot-api`
   - **Repository URL**: `https://github.com/musicOverdose/telegram-local-bot-api.git`
   - **Repository reference**: `refs/heads/main`
   - **Compose path**: `docker-compose.yml`
5. Under **Environment variables**, click **Add environment variable** and supply your credentials:
   - `TELEGRAM_API_ID`: *<your_api_id>*
   - `TELEGRAM_API_HASH`: *<your_api_hash>*
6. *(Optional)* Enable **Automatic updates** (Polling or Webhook) if desired.
7. Click **Deploy the stack**.

Portainer will clone the repository, build the image from the multi-stage `Dockerfile`, tag it as `telegram-bot-api:10.3`, attach the persistent volume, and connect it to `telegram-bots`.

---

## 7. Configuration Details

### Network & Internal Endpoint
- **Network**: `telegram-bots` (external bridge network).
- **Service Name**: `telegram-bot-api`.
- **Internal API URL**:
  ```text
  http://telegram-bot-api:8081
  ```
  Any bot container attached to the `telegram-bots` network can communicate with the server using this URL.

### Port Exposure & Security
- **No Public Exposure**: Port 8081 is **NOT** exposed to the public Internet (`0.0.0.0:8081` is never bound).
- All bot-to-server traffic is isolated entirely within the internal Docker bridge network `telegram-bots`.
- For optional administrative diagnostics or host testing, an optional loopback binding (`127.0.0.1:8081:8081`) is provided in `docker-compose.yml` in commented form.

### Persistent Storage
- **Volume Name**: `telegram-bot-api-data`.
- **Container Path**: `/var/lib/telegram-bot-api`.
- The Telegram Local Bot API server stores database state, authorized bot session data, and cached files in this directory. Named Docker volumes persist data across container recreations, image updates, and restarts.

### Non-Root Runtime Security
- The runtime image runs as an unprivileged system user: `telegram-bot-api` (`UID 101`, `GID 101`).
- Both working directory (`/var/lib/telegram-bot-api`) and temporary directory (`/tmp/telegram-bot-api`) are owned by UID/GID 101 with permissions `770`.

### Healthcheck
- The stack includes a built-in healthcheck:
  ```yaml
  test: ["CMD", "curl", "-sS", "-o", "/dev/null", "http://127.0.0.1:8081/"]
  interval: 15s
  timeout: 5s
  retries: 3
  start_period: 10s
  ```
- **What it checks**: Probes the local HTTP daemon on port 8081. When the server is active, it immediately returns an HTTP response (HTTP 404 for unrecognized root paths), causing `curl` to exit with status `0`. If the server crashes or hangs, the connection fails or times out, triggering Portainer/Docker unhealthy alerts.

---

## 8. Updating the Telegram Bot API Version

To update the Telegram Bot API server when new official releases are published:

1. Look up the new commit SHA or tag in the official repository: [tdlib/telegram-bot-api](https://github.com/tdlib/telegram-bot-api).
2. Edit `Dockerfile`:
   ```dockerfile
   ARG TG_BOT_API_COMMIT=<new_commit_sha>
   ```
3. Update the image tag in `docker-compose.yml` if desired (e.g., `image: telegram-bot-api:10.4`).
4. Commit and push the changes to GitHub.
5. In Portainer, open the `telegram-bot-api` stack and click **Pull and redeploy** with **Re-build image** enabled.

---

## 9. Future Bot Integration (aiogram Example)

When you are ready to configure a bot (such as an aiogram bot) to use this shared Local Bot API server:

1. Attach the bot's Compose stack to the shared `telegram-bots` network:
   ```yaml
   networks:
     telegram-bots:
       external: true
   ```
2. Configure the bot client to point to the local server base URL:
   ```python
   from aiogram import Bot
   from aiogram.client.session.aiohttp import AiohttpSession
   from aiogram.client.telegram import TelegramAPIServer

   # Point to the shared Local Bot API server
   session = AiohttpSession(
       api=TelegramAPIServer.from_base("http://telegram-bot-api:8081")
   )

   bot = Bot(token="YOUR_BOT_TOKEN", session=session)
   ```
3. **Important Note on Migrating Existing Bots**: If migrating a bot that was previously running on official cloud Telegram servers (`https://api.telegram.org`) or on another local instance, remember to call `logOut` on the previous server or close the webhook before switching over to guarantee smooth receipt of updates. *(No bot changes are made by this repository).*
