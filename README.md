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
├── .version                          # Pinned Penpot version (source of truth)
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
| `make assemble` | Build + copy the app bundle to `APP_DIR` (no `.env`, no alias) |
| `make bundle` | Assemble + ad-hoc sign a relocatable bundle at `BUNDLE_DIR` (default `build/Penpot.app`, used for the DMG) |
| `make install` | Build + assemble app bundle at `~/Applications/Penpot.app` |
| `make clean` | Remove compiled binary |
| `make uninstall` | Delete `Penpot.app` entirely |
| `make status` | Check if app is installed |

### Homebrew

```sh
brew install agherasim/tap/penpot-desktop        # latest tagged release
brew install --HEAD agherasim/tap/penpot-desktop # build from main
penpot install-app                               # add a launcher to /Applications
```

The formula builds from source (Xcode Command Line Tools required), so nothing is downloaded pre-built and Gatekeeper doesn't block it. The app itself lives in `$(brew --prefix)/opt/penpot-desktop/Penpot.app`. `penpot install-app [dir]` writes a small launcher bundle into `/Applications` (or `~/Applications`, or `dir`) that runs that `opt` path, so it keeps working across `brew upgrade`. A Finder alias or symlink would point at the versioned Cellar directory and break after `brew cleanup`. Run `penpot uninstall-app` before `brew uninstall`.

Switching from `make install`? Run `make uninstall` first. Otherwise the `alias penpot=` it added to `~/.zshrc` shadows Homebrew's `penpot`.

The formula template is `packaging/homebrew/penpot-desktop.rb.in`. On a `v*` tag push, `release.yml` renders it with the tag's tarball checksum and pushes it to `agherasim/homebrew-tap` over SSH with the `TAP_DEPLOY_KEY` secret, the private half of a write-enabled deploy key on the tap repo (skipped if unset). Each project publishing to the tap gets its own deploy key.

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
| `PENPOT_PUBLIC_URI` | `http://localhost:9001` | URL for browser + backend |
| `GOOGLE_OAUTH_CLIENT_ID` / `GOOGLE_OAUTH_CLIENT_SECRET` | — | Google OAuth login credentials |
| `PENPOT_SECRET_KEY` | — | Penpot backend master key |
| `PENPOT_AUTH_TOKEN` | — | `penpot-cli` login token (obtained separately via the Penpot UI/API) |

### Penpot version

The Penpot version is **not** in `.env` — it's pinned in the committed `.version` file (single source of truth) and injected into `docker-compose.yaml` by the launcher script at startup. To upgrade/downgrade Penpot, edit `.version` and re-run `make install`.

A scheduled workflow (`.github/workflows/check-penpot-update.yml`) checks [penpot/penpot](https://github.com/penpot/penpot/releases) weekly (Mondays) and opens a PR bumping `.version` when a newer stable release is available. `PENPOT_MCP_VERSION` in `docker-compose.yaml` is pinned separately (the MCP package lags Penpot releases) and is not affected.

> Running `docker compose` manually (outside the launcher) won't pick up `.version` — export it first: `export PENPOT_VERSION=$(cat .version)`.

After editing, re-run `make install` to apply changes.
