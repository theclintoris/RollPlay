# RollPlay — Steam Release Checklist

This is the working plan for taking RollPlay from a tested local build to a
store release. It is intentionally concrete: every unchecked item is something
that still needs a human decision, a Steamworks account, or a store asset.

The app is not yet a published product. Do not upload a build to the default
branch until the Windows and Linux smoke tests pass on a clean machine.

## 1. Steamworks account and app

- [ ] Create a Steamworks partner account and pay the Steam Direct fee.
- [ ] Complete tax and bank details.
- [ ] Create the RollPlay app and record its **App ID**.
- [ ] Create the Windows depot and Linux depot and record both **Depot IDs**.
- [ ] Create a developer-comp package that includes both depots, so test
      accounts can install builds before release.
- [ ] Add the app to your own Steam library through the developer package.
- [ ] Create a private beta branch in **App Admin → Builds**.
- [ ] Put the real app ID into `project.godot`:

  ```ini
  [rollplay]
  steam/app_id=1234560
  ```

  This does two things: it identifies the product internally, and it prevents
  RollPlay from rolling itself when the installed copy is in the owner's Steam
  library. It does **not** require the Steamworks SDK.

## 2. Version and build

- [ ] Decide the first public version, for example `1.0.0`.
- [ ] Run the build script with that version:

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\build-release.ps1 -Version 1.0.0
  ```

  The script updates `config/version`, the Windows file version, and the
  product version fields in `export_presets.cfg`, then builds both platforms.

- [ ] Confirm the outputs exist and checksums are written:

  ```text
  build/windows/RollPlay.exe
  build/windows/LICENSES/
  build/windows/THIRD_PARTY_NOTICES.txt
  build/windows/SHA256SUMS.txt
  build/linux/RollPlay.x86_64
  build/linux/LICENSES/
  build/linux/THIRD_PARTY_NOTICES.txt
  build/linux/SHA256SUMS.txt
  ```

- [ ] Keep `THIRD_PARTY_NOTICES.txt` and `LICENSES/` next to the binaries in
      the depot. The copies inside the embedded PCK are not human-accessible
      enough to satisfy attribution expectations.

- [ ] On Linux, set the executable bit:

  ```bash
  chmod +x build/linux/RollPlay.x86_64
  ```

## 3. SteamPipe upload

The templates in `steam/` contain placeholders. Replace all of them before use:

| File | Placeholders |
| --- | --- |
| `steam/app_build_windows.vdf` | `YOUR_APP_ID`, `YOUR_WINDOWS_DEPOT_ID` |
| `steam/depot_build_windows.vdf` | `YOUR_WINDOWS_DEPOT_ID` |
| `steam/app_build_linux.vdf` | `YOUR_APP_ID`, `YOUR_LINUX_DEPOT_ID` |
| `steam/depot_build_linux.vdf` | `YOUR_LINUX_DEPOT_ID` |

Run a dry run first by adding `"Preview" "1"` to the app build file, then:

```powershell
steamcmd.exe +login <build-account> +run_app_build "C:\path\to\RollPlayGodot\steam\app_build_windows.vdf" +quit
```

Inspect the logs in `steam/output/windows/` (or the configured `BuildOutput`),
remove `"Preview"`, and upload for real. Repeat for Linux.

Then:

- [ ] Set the build live on the **beta branch**, not `default`.
- [ ] Install it from Steam on a clean Windows machine.
- [ ] Install it from Steam on a Linux desktop (or Steam Deck desktop mode).
- [ ] Verify the launch option `RollPlay.exe` / `RollPlay.x86_64` is correct.
- [ ] Verify Steam's **Installed files** are complete, including licenses.
- [ ] Only after sign-off, promote the tested build to `default` manually.

`SetLive` is intentionally blank in the templates. Steam does not allow an
automated build to set the `default` branch live; that is a deliberate safety
step and may require a Steam Guard confirmation.

## 4. Store assets

Check the current [Steamworks store asset guidelines](https://partner.steamgames.com/doc/store/assets)
before exporting; Valve changes dimensions occasionally. At minimum:

| Asset | Typical size | Status |
| --- | --- | --- |
| Header capsule | 460 × 215 | Needs design |
| Small capsule | 231 × 87 | Needs design |
| Main capsule | 1232 × 706 | Needs design |
| Vertical capsule | 748 × 896 | Needs design |
| Library capsule | 600 × 900 | Needs design |
| Library hero | 3840 × 1240 | Needs design |
| Library logo | 1280 × 720 PNG | Needs design |
| Client icon | 32 × 32 ICO | `assets/branding/icon.ico` exists |
| Screenshots | 1920 × 1080, at least 5 | Current dev captures are 1440 × 900 |
| Trailer | 1920 × 1080, H.264 | Needs capture |

The current screenshots in `docs/screenshots/` are useful for the README and
press kit, but they show real third-party game covers. For the public store
page, use screenshots you are comfortable licensing and displaying, and avoid
implying those games are included with RollPlay.

Store copy must make clear that RollPlay is a **library launcher/roulette**, not
a game store, and that the player needs their own Steam library.

## 5. Store page, privacy, support

- [ ] Finalize the store description and system requirements.
- [ ] Replace the placeholder support address in `docs/PRIVACY.md`.
- [ ] Publish a privacy policy URL. The current policy is an accurate draft for
      this build, not legal advice.
- [ ] Decide whether to ship Valve's default EULA or a custom EULA. A custom
      EULA needs legal review.
- [ ] Add a support URL, community hub, and refund/contact language.
- [ ] Disclose that the app fetches public Steam Store metadata and cover art.
- [ ] Confirm there is no telemetry, no account system, and no developer backend.
- [ ] Add content survey / age rating information.
- [ ] Add accessibility notes (keyboard support, reduced-motion behavior if
      implemented, text scaling).
- [ ] Do not use Valve's logo in a way that implies endorsement. The README and
      About copy already include the trademark disclaimer.

## 6. Quality gates

Test each of these before release.

### Windows, clean user account

- [ ] Fresh install, empty cache: scan completes, metadata fills in, covers load.
- [ ] Offline launch: library still appears, genre chips use cached data, all-random
      works.
- [ ] Multiple Steam libraries on different drives.
- [ ] Game installed on a secondary library launches through Steam.
- [ ] Demo/playtest/tool entries are absent.
- [ ] Own RollPlay app ID is excluded when installed from Steam.
- [ ] All-random avoids an immediate repeat when another game exists.
- [ ] Genre mode: every genre chip returns only games carrying that genre.
- [ ] Library drawer search, genre filter, sort, and click-to-launch.
- [ ] Refresh while a game is not running.
- [ ] `R` and `Escape` keyboard paths.
- [ ] Launch feedback resets if Steam is closed.
- [ ] Window fits a 1366 × 768 display; no clipped controls.
- [ ] 1920 × 1080 and 2560 × 1440 rendering is sharp, not stretched.

### Linux / Steam Deck

- [ ] AppImage or binary launches on SteamOS and a common desktop distro.
- [ ] Steam Flatpak/Snap library detection or `STEAM_PATH` fallback.
- [ ] `steam://` launch works from the exported binary.
- [ ] 1280 × 800 readability and touch/controller navigation.
- [ ] CA bundle loads; metadata and covers fetch.
- [ ] No dependence on a Windows-only font or path.

### Release hygiene

- [ ] Windows Authenticode signing certificate purchased and applied to the
      release binary. Unsigned indie builds trigger SmartScreen warnings.
- [ ] Antivirus false-positive check on the signed and unsigned binaries.
- [ ] Clean install from the actual Steam depot, not just the build folder.
- [ ] SHA-256 checksums archived with the release notes.
- [ ] Install/uninstall leaves no unexpected files outside the documented data
      folder.
- [ ] Crash handling: capture the Godot log path in support documentation.
- [ ] Confirm data deletion instructions work (delete the data folder).

## 7. Known limitations

- Windows and Linux exports exist; macOS detection exists in code but there is no
  tested macOS build.
- Genre data depends on Valve's public Store API. Delisted games, offline first
  runs, or API changes degrade to all-random mode rather than blocking the app.
- Cover art is fetched from Valve's CDN. Offline first runs show designed
  placeholders.
- There is no automatic updater; Steam handles updates.
- There is no telemetry or crash reporting. Support requires the user to share
  logs and their library details manually.
- Localization is English-only.
- The app launches through the `steam://` protocol rather than the Steamworks
  SDK. That keeps the build dependency-free, but it means Steam must handle the
  protocol association.

## 8. Release sequence

1. Finish sections 1–3 and get a beta build installed through Steam.
2. Run section 6 on clean Windows and Linux machines.
3. Freeze strings and export final store assets.
4. Publish the store page for review; fix review feedback.
5. Upload the release candidate, set it live on beta, smoke test again.
6. Promote to `default`, publish, and monitor the community hub.
7. Tag the repository and archive the exact source revision, export presets,
   templates, checksums, and store copy used for the build.

---

Steam and the Steam logo are trademarks of Valve Corporation. RollPlay is not
affiliated with or endorsed by Valve.
