# RollPlay Privacy Notice

**Draft for release review — replace the contact details and host this page at a
public URL before publishing on Steam. This is a plain-language description of
what the current build does, not legal advice.**

Last updated: 5 November 2026

## The short version

RollPlay does not have an account system, analytics, advertising, or a developer
server. It does not collect your Steam credentials, Steam ID, email address, or
gameplay history. The app reads your local Steam library so it can offer games
to launch, and it asks Valve's public Steam Store service for public game
metadata and cover art. Your device's IP address is visible to Valve when those
requests are made, just as it is when you browse the Steam Store.

## What RollPlay reads on your device

RollPlay reads local Steam configuration and installed-game manifests to build
the list of games you can launch:

- Steam install locations and `libraryfolders.vdf` entries;
- installed `appmanifest_*.acf` files, including app ID, game name, install
  folder, size, and last-played timestamp;
- the contents of your RollPlay cache folder.

This information stays on your device. It is not uploaded to RollPlay or to any
developer-operated service.

RollPlay does not read your Steam password, payment details, friends list,
chat history, screenshots, or saved games.

## Network requests

When RollPlay needs artwork or genre information, it makes HTTPS requests to
public Valve services:

1. **Steam Store appdetails** — sends the numeric app IDs of installed games,
   the requested language, and a standard RollPlay User-Agent. Valve returns
   public store information such as the game name, genres, description, and
   image URLs.
2. **Steam CDN** — downloads publicly available cover/header images for those
   games.

These requests do not include your Steam account, Steam ID, or a RollPlay
account. Valve can see your IP address, User-Agent, and the app IDs requested,
and handles that information under [Valve's privacy policy](https://store.steampowered.com/privacy_agreement/).

When you press **Launch on Steam**, RollPlay asks your operating system to open
`steam://rungameid/<app_id>`. The Steam client then starts the game. RollPlay
does not proxy, monitor, or report your play session. Steam's own privacy terms
apply to Steam and to the game being launched.

There are no third-party analytics SDKs, ad networks, crash-reporting services,
or cloud sync services in RollPlay.

## Cookies and identifiers

RollPlay does not set or use cookies. It does not create a persistent user
identifier. The app's only persistent files are the metadata and cover caches in
the data folder described below.

## Local storage

RollPlay stores:

- `metadata_cache.json` — public game names, genres, descriptions, and image
  URLs for installed games;
- `covers/` — cached cover images.

On Windows this is normally `%APPDATA%\RollPlay`; on Linux it is normally
`~/.local/share/RollPlay`; on macOS it is normally
`~/Library/Application Support/RollPlay`. A portable or sandboxed build may use a
`.userdata` or `RollPlayData` folder beside the executable, or a folder chosen
with the `ROLLPLAY_DATA_DIR` environment variable.

You can delete this folder at any time while RollPlay is closed. The app will
rebuild it on the next run. Deleting it does not affect your Steam library,
Steam account, or installed games.

## Data sharing and selling

RollPlay does not sell personal information and does not share app data with
advertisers or data brokers. The only network recipients are Valve-operated
Steam services described above. We do not receive a copy of those requests.

## Children

RollPlay is a local utility for launching games and is not directed at children
under 13. It does not knowingly collect personal information from anyone.

## Security

Requests to Valve use HTTPS and the app ships a CA certificate bundle to verify
those connections consistently. No method of transmission or storage is
perfect, but RollPlay deliberately keeps its data footprint small: a local
library scan and a public metadata cache.

## Changes

If a future version adds accounts, telemetry, cloud sync, or another network
service, this notice will be updated before that version is released, and the
change will be described in the release notes.

## Contact

Questions about this notice or RollPlay's data handling:

**RollPlay support — [configure support email before publishing]**

[Configure a public support URL before publishing.]
