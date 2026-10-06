# Telegram Local Bot API

This repository provides a shared Telegram Local Bot API server deployment intended for use by multiple Telegram bot stacks running on the same host.

## Image

`aiogram/telegram-bot-api:latest`

This is an unofficial Docker image maintained by the aiogram project that packages and runs Telegram's official Bot API server. It is not an official Telegram Docker image.

## Deploy with Portainer

1. Create the external Docker network `telegram-bots` if it does not already exist:
   ```bash
   docker network create telegram-bots
   ```
2. In Portainer, navigate to **Stacks** → **Add stack**.
3. Select **Git repository** and provide this repository URL.
4. Set the environment variables:
   - `TELEGRAM_API_ID`
   - `TELEGRAM_API_HASH`
5. Click **Deploy the stack**.

## Configuration

The service uses the following environment variables:
- `TELEGRAM_API_ID`: Your Telegram API ID from https://my.telegram.org.
- `TELEGRAM_API_HASH`: Your Telegram API Hash from https://my.telegram.org.
- `TELEGRAM_LOCAL=1`: Enables local mode (higher file upload/download limits, local file paths).

## Network

- **Network**: `telegram-bots` (external bridge network)

## Endpoint

- **Internal API URL**: `http://telegram-bot-api:8081`

## Storage

- **Volume**: `telegram-bot-api-data:/var/lib/telegram-bot-api`

## Future Bots

Future bot containers can join the `telegram-bots` external network and communicate directly with the shared server at `http://telegram-bot-api:8081`.

## Important

Existing bots are **not** migrated by this repository. Migration of existing bot stacks will be handled separately.
