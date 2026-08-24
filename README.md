# Vimm's Downloader

A Bash script to download ROMs from [Vimm's Lair](https://vimm.net) with **MD5 integrity verification** intended for your [RomM](https://romm.app) Library.

---

## ⚠️ Disclaimer ⚠️

This script is intended **only** to download a game you like directly to your own server — e.g. connected via SSH, you run the script and grab that one ROM you want. It is **not** meant to attack, scrape, automate in bulk, or otherwise hammer Vimm's API.

Please use it the way it was designed: for the occasional single download, directly to your server. 

Be nice. 🙏

Also, right now, it may not handle all possible cases as I have made it from my experience, but for most of them it works. Check the Assumptions section below.

---

## Overview

Vimm's Lair serves ROMs through a vault page that points to a dedicated download server URL (`dlX.vimm.net`). This script automates the whole flow:

1. Fetches the vault page.
2. Extracts the `MEDIA_ID` and `SERVER_ID` of the download server from the page.
3. Resolves the final download URL and reads the file name and size from the HTTP headers.
4. Lets you pick a target platform from your local ROM library.
5. Downloads the file with a progress bar.
6. Extracts the ROM, compares its MD5 against Vimm's official hash, and keeps only the compressed file.

---

## Use Case

You have a ROM library organized by platform (e.g. `/home/user/emu/library/roms/n64`). You find the game you want on Vimm's Lair and copy the vault ID from the URL:

```
https://vimm.net/vault/12345
```

Then run:

```bash
./vimm-downloader.sh 12345
```

The script will:

```
 ╔═══════════════════════════════════╗
 ║          Vimm's Downloader        ║
 ╚═══════════════════════════════════╝

 # Connecting to https://vimm.net/vault/12345...
 # Fetched game URL

 # Fetching game information from https://dl3.vimm.net/?mediaId=54321...
 # Game Name (Europe).zip 25.9MiB

 # These are your current platforms:
     3ds gb gba n64
     nds nes new-nintendo-3ds nintendo-dsi
     ps2 psx switch

 # Select the platform: n64

 # Downloading Game Name (Europe).zip
   25.9MiB/25.9MiB [=========================================>] 100% [4.27MiB/s]

 # Extracting files to calculate HASH...
 # Files extracted
 # Calculated HASH: ed1378bc12115f71209a77844965ba50
 # Expected HASH: ed1378bc12115f71209a77844965ba50
 # Hashes match!

 # Bye bye!
```

Only the `.zip` (or `.7z`) file is kept; the extracted ROM is verified and then discarded.

---

## Requirements

The script relies on the following programs being installed and available in `PATH`:

| Tool            | Used for                                              |
| :-------------- | :---------------------------------------------------- |
| **`curl`**      | Fetching pages, headers and downloading.               |
| **`grep`**      | Extracting IDs, file names and hashes (needs `-P`).   |
| **`unzip`**     | Extracting `.zip` files (primary format).             |
| **`7z`**        | Extracting `.7z` files (secondary support).           |
| **`numfmt`**    | Formatting file size in human-readable units (MiB).   |
| **`pv`**        | Progress bar during the download.                     |
| **`md5sum`**    | Computing the MD5 hash of the extracted ROM.          |
| **`find` / `head`** | Locating the extracted ROM inside the temp folder. |
| **`cut`**       | Isolating the MD5 value from `md5sum` output.         |
| **`sed` / `xargs`** | Output formatting (platform listing, size truncation). |
| **`ls`**        | Listing directories to show available platforms.      |

> **Note:** `grep` must be the GNU version supporting the `-P` (Perl regex) option, e.g. `\K`.


## Configuration

Edit the variable at the top of the script to point to your ROM library:

```bash
BASE_DIR="/path/to/library/roms"
```

---

## Assumptions

The script is tailored to Vimm's Lair as it exists today. It assumes:

### System & environment
- **Designed for a RomM library** — the script assumes the [RomM](https://romm.app) server folder structure: `BASE_DIR` contains one subdirectory per platform (RomM collection), and game files are stored directly inside them.
- **No spaces in file/folder names** — platform folders are expected to be space-free, following the RomM naming standard.
- **`BASE_DIR` exists and is writable** — both it and its platform subdirectories require read/write permissions.

### Vimm's Lair
- **Hash file format is strict** — `MD5:` followed by 32 hex characters on the same line, inside the `Vimm's Lair.txt` file that ships with the archive. Variations like `md5:`, `MD5 =` are not supported as they are not expected.
- **No session cookie required** — the download server answers without the vault session cookie (as observed). If Vimm ever requires one, the download fails.
- **Only `.zip` and `.7z` are supported** — any other file format triggers a "Filetype not supported" error and aborts the download as they are not expected.
- **Single-file archives** — the downloaded `.zip`/`.7z` must contain **exactly one ROM**, sharing the same base name as the archive (e.g. `Paper Mario (USA).zip` → `Paper Mario (USA).z64`). Archives with multiple files, subfolders, or mismatched names are not handled (Like PSX disks that come with other stuff but I haven't tried yet).
