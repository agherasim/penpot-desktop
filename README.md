# Penpot Desktop

A macOS app bundle that runs [Penpot](https://penpot.app) locally via Docker Compose, with a native menu bar status indicator.

## Prerequisites

- macOS
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Xcode Command Line Tools (`xcode-select --install`)

## Project Structure

```
penpot-desktop/
├── Makefile                          # Build & install targets
├── .env                              # Shared configuration (app + api-client)
├── src/
│   ├── app/
│   │   ├── Info.plist                # macOS app bundle metadata
│   │   └── docker-compose.yaml       # Penpot services
│   ├── menubar/
│   │   └── PenpotMenuBar.swift       # Native menu bar status app
│   ├── scripts/
│   │   ├── Penpot                    # Main launcher script (start/stop/status)
│   │   └── setup.sh                  # Interactive first-run .env setup
│   ├── resources/
│   │   └── AppIcon.icns              # macOS app icon (all sizes)
│   └── icons/
│       └── macOS-App-Icon.png        # Source icon (512x512)
```

## Build & Install

```sh
make install
```

| Target | Description |
|--------|-------------|
| `make build` | Compile the Swift menu bar binary |
| `make install` | Build + assemble app bundle at `~/Applications/Penpot.app` |
| `make clean` | Remove compiled binary |
| `make uninstall` | Delete `Penpot.app` entirely |
| `make status` | Check if app is installed |

## Usage

**Launch from Finder** — double-click `Penpot.app`. Starts Docker containers, opens the browser, and shows a menu bar indicator.

**From the terminal:**

```sh
# Start Penpot
~/Applications/Penpot.app/Contents/MacOS/Penpot start

# Check health
~/Applications/Penpot.app/Contents/MacOS/Penpot status

# Stop Penpot
~/Applications/Penpot.app/Contents/MacOS/Penpot stop
```

**Menu bar (◆):**

- Shows ◆ when healthy, ◇ when not running
- **Open Penpot** — opens browser
- **Stop Penpot** — stops all containers + quits menu bar

## Configuration

The installed app's `.env` lives at `~/Library/Application Support/Penpot/.env` — outside `Penpot.app` itself, so it survives DMG-based app updates (which replace the whole bundle).

On first launch (Finder double-click or `Penpot start`/`Penpot` from the terminal), if that file doesn't exist yet, `setup.sh` runs automatically and interactively prompts for the values below, auto-generating `PENPOT_SECRET_KEY`. From Finder, this opens a Terminal window to run the prompts.

For local development, `.env` at the repo root is used instead (copied into `~/Library/Application Support/Penpot/.env` by `make install`, unless one already exists there). You can also run the setup script yourself, or just copy the example and edit it directly:

```sh
src/scripts/setup.sh .env .env.example   # interactive
# or
cp .env.example .env                     # manual
```

`.env` is shared by the app and `src/api-client`'s `penpot-cli`:

| Variable | Default | Description |
|----------|---------|-------------|
| `PENPOT_VERSION` | `2.14.3` | Penpot Docker image tag |
| `PENPOT_PUBLIC_URI` | `http://localhost:9001` | URL for browser + backend |
| `GOOGLE_OAUTH_CLIENT_ID` / `GOOGLE_OAUTH_CLIENT_SECRET` | — | Google OAuth login credentials |
| `PENPOT_SECRET_KEY` | — | Penpot backend master key |
| `PENPOT_AUTH_TOKEN` | — | `penpot-cli` login token (obtained separately via the Penpot UI/API) |

After editing, re-run `make install` to apply changes.
