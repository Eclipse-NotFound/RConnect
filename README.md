# RConnect — two-player co-op

**English** · [简体中文](README.zh-CN.md)

Explore the wasteland with a friend: see each other, chat, fight together, or split up across ordinary rooms on the same map.

**[Download v0.2.8 — RConnect_v0.2.8.zip](https://github.com/Eclipse-NotFound/RConnect/releases/download/v0.2.8/RConnect_v0.2.8.zip)** · [Release notes / other versions](https://github.com/Eclipse-NotFound/RConnect/releases)

Use the download link above, or open the release page, expand **Assets**, and select that filename. **Source code** and the green **Code → Download ZIP** button are development files, not the installable package.

> **The download and development versions differ.** The public package is **0.2.8**, and the instructions below match it. Newer source records do not imply a newer download. The compact tabbed panel, Ctrl+Enter chat and shared menu/SATS pause are later features, not part of this package.

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
5. After connecting, look for your partner’s translucent character and name. Click the chat input, type, and press **Enter** to send.

If Windows Firewall asks, allow the game on your trusted local network; the host must allow the selected port. You do not need to disable the firewall.

## Playing together

- Split up in ordinary rooms; let the host lead map changes, and enter story/challenge areas together.
- Ground items have one owner: the first player to collect them. XP-point rewards and checkpoint unlocks can be shared.
- Empty rooms pause and retain progress during the session. This does not add a persistent save of every random-room battle; save characters normally before quitting.
- Optional shared exploration can also work with RealisticVision’s local view.

## Connection problems, updates and removal

Check in this order: matching versions and a full restart → host clicked Host first → joiner entered the host’s LAN address → matching ports → host firewall permits the connection. Test on the same LAN first; a failed connection does not mean you need to reinstall the game.

For updates, both players save and exit, back up `mods/RConnect`, install the same new version, scan and restart. Keep each player’s `release/config.txt`; the old ZIP includes one, so avoid overwriting nicknames, addresses and ports. To disable, move the RConnect folder outside `mods` as a backup, scan and restart.

## Need help?

Check the folder location, run the scanner, and fully restart the game. See the [installation troubleshooting guide](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md#troubleshooting) for common problems.

If it still fails, [report an issue](https://github.com/Eclipse-NotFound/RConnect/issues) with your game version, mod version, other installed mods, steps to reproduce, and what you expected versus what happened. Include a screenshot or exact error if available; a personal save is not needed for an initial report.

<details>
<summary>Development resources and version differences</summary>

The controls above are based on the [v0.2.8 source](https://github.com/Eclipse-NotFound/RConnect/tree/v0.2.8). Current repository source may contain fixes not yet packaged; see [src/](src/) and [state/](state/).

</details>

[Browse the mod collection](https://github.com/Eclipse-NotFound/ModLoader#choose-mods) · [First-time installation guide](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md)

An unofficial fan project. You need your own copy of the game.
