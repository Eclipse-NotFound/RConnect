# RConnect — two-player co-op

**English** · [简体中文](README.zh-CN.md)

Explore the wasteland with a friend: see each other, chat, fight together, or split up across ordinary rooms on the same map.

**[Download v0.2.24-animfix3-l10n — RConnect_v0.2.24-animfix3-l10n.zip](https://github.com/Eclipse-NotFound/RConnect/releases/download/v0.2.24-animfix3-l10n/RConnect_v0.2.24-animfix3-l10n.zip)** · [Release notes / other versions](https://github.com/Eclipse-NotFound/RConnect/releases)

Use the download link above, or open the release page, expand **Assets**, and select that filename. **Source code** and the green **Code → Download ZIP** button are development files, not the installable package.

> **Current A architecture, with nine-language UI.** This prerelease includes the deployed animfix3 repairs and the localization update. It does not contain B architecture. Dense scenes can still stall; this release does not claim to resolve every animation or performance issue.

## Languages and this update

The panel, settings, shortcuts and connection/room notices follow the game's language setting: **English, Русский, Українська, 简体中文, 繁體中文, Polski, Deutsch, Español and 日本語**. You can switch language without restarting the mod. Nicknames and chat messages are never translated. Long hints remain inside the scrolling panel.

This build also includes A's native enemy weapon reflection/melee poses, enemy speech, telekinetic impact damage numbers and rapid door-toggle fixes. Special projectile motion interpolates confirmed samples; occasional whole-frame stalls remain. [Validation and known limits](docs/release-0.2.24.md).

## Before you start

- Each player needs **Windows / Remains 1.02** and the **same RConnect version**.
- Start with two computers on the same local network. Internet play, reliable reconnection and three or more players are not guaranteed.
- One player hosts, the other joins. Each saves their own character; you do not need identical save files.

## Install

For **Windows / Remains 1.02**.

1. Save and close the game. In your Steam Library, right-click Remains → **Manage → Browse local files**. The game folder contains `pfe.swf` and `application.xml`.
2. If this is your first mod from this collection, complete the [ModLoader first-time setup](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md#first-install), including the game patch and scanner. Skip this if already installed.
3. Extract the ZIP and **merge its `mods` folder into the game folder**. Avoid a nested `mods/mods` folder.
4. Double-click **`mods/ModLoader/RemainsModScanner.exe`** inside the game folder. Wait for it to finish, close its message, then launch the game normally.

Check that this file exists: `mods/RConnect/release/RConnectMod.swf`. After loading a character, look for the panel with Host / Join buttons; F10 shows or hides it.

[Folder diagram, updating and recovery](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md)

**Both players must complete the installation steps.**

## Connect for the first time

1. Both players launch the game and load their own characters. Press **F10** if the panel is hidden.
2. The host enters a nickname, keeps **127.0.0.1** and port **23456**, then clicks **Host**.
3. The host finds their **IPv4 address** in Windows Settings → Network & Internet → properties for the connected network, and shares it with the other player (for example 192.168.1.10).
4. The joining player enters a nickname, the **host’s IPv4 address**, and the same port **23456**, then clicks **Join**. 127.0.0.1 means your own computer; it cannot reach another computer.
5. Expand the compact panel with **▼** and select the connection tab. After connecting, look for your partner and name. Press **Ctrl+Enter** to open chat, **Enter** to send, and **Esc** to close it.

If Windows Firewall asks, allow the game on your trusted local network; the host must allow the selected port. You do not need to disable the firewall.

## Playing together

- Split up in ordinary rooms; let the host lead map changes, and enter story/challenge areas together.
- Ground items have one owner: the first player to collect them. XP-point rewards and checkpoint unlocks can be shared.
- Empty rooms pause and retain progress during the session. This does not add a persistent save of every random-room battle; save characters normally before quitting.
- Optional shared exploration can also work with RealisticVision’s local view.

## Compact panel and local co-op

The panel starts as a short status bar. Expand it for connection, chat, teammate and settings tabs. Drag the title to move it; adjust opacity from 30–100% in settings. F10 hides/shows it. The host can enable shared menu/SATS pause and friendly fire; each player controls whether a teammate may grab them and whether WASD resists the grab.

For two windows on one PC, run `mods/RConnect/Start-Coop.bat`; both windows keep separate characters. See [local co-op details](docs/local-coop.md) (Chinese). The launcher keeps its own game processes responsive in the background and may increase power usage.

## Validation and limits

Localization was checked in isolated, muted host/join instances across all nine languages, including native AIR text layout and preserved player text. The 80 gameplay classes are byte-identical to the deployed animfix3 source; its targeted door, weapon, speech, throw-feedback and projectile checks are reused where unchanged. This is not a new performance qualification or a test of every mod combination. See [validation and limits](docs/release-0.2.24.md).

## Connection problems, updates and removal

Check in this order: matching versions and a full restart → host clicked Host first → joiner entered the host’s LAN address → matching ports → host firewall permits the connection. Test on the same LAN first; a failed connection does not mean you need to reinstall the game.

For updates, both players save and exit, back up `mods/RConnect`, install the same new version, scan and restart. Keep each player’s existing configuration. This ZIP omits `config.txt` to avoid overwriting personal settings; new installations use built-in defaults. To disable, move the RConnect folder outside `mods` as a backup, scan and restart.

## Need help?

Check the folder location, run the scanner, and fully restart the game. See the [installation troubleshooting guide](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md#troubleshooting) for common problems.

If it still fails, [report an issue](https://github.com/Eclipse-NotFound/RConnect/issues) with your game version, mod version, other installed mods, steps to reproduce, and what you expected versus what happened. Include a screenshot or exact error if available; a personal save is not needed for an initial report.

<details>
<summary>Development resources and version differences</summary>

This release tag contains the exact A source in [src/](src/), the editable [language catalog](locales/messages.json), and a [build guide](docs/BUILD-A.md). No B experiment is included.

</details>

[Browse the mod collection](https://github.com/Eclipse-NotFound/ModLoader#choose-mods) · [First-time installation guide](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md)

An unofficial fan project. You need your own copy of the game.
