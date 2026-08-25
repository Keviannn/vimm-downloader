# Vimm's Downloader

A Bash script to download ROMs from [Vimm's Lair](https://vimm.net) with **MD5 integrity verification** intended for your [RomM](https://romm.app) Library.

---

## ⚠️ Disclaimer ⚠️

This script is intended **only** to download a game you like directly to your own server, because you do not have a graphical interface.

It is **not** meant to attack, scrape, automate in bulk, or otherwise hammer Vimm's API.

The current design, because of Vimm's bot protection and my own principles, only works with a valid session on a real browser, passing the bot protection in a legitimate way and getting the provided data.

---

## Overview

Vimm's Lair serves ROMs through a vault page that points to a dedicated download server URL (`dlX.vimm.net`). This script automates the whole flow:

1. Asks the user for the Vault's game ID, the download server ID and the download server game ID.
2. Resolves the download URL and reads the file name and size from the HTTP headers.
3. Lets you pick a target platform from your local ROM library.
4. Downloads the file with a progress bar.
5. Streams the ROM files through a pipeline (never writing anything to disk) and verifies **each one's MD5** against Vimm's official hash (multi-file ROMs like PSX .bin/.cue are fully supported) and keeps only the compressed file.

⚠️ Some files do not come with HASH for their .bin. Because of this and if someone does not care too much about integrity, a hash mismatch is only reported.

---

## Use Case

You have a ROM library organized by platform (e.g. `/home/user/emu/library/roms/n64`). You find the game you want on Vimm's Lair and copy the vault ID from the URL:

```
https://vimm.net/vault/12345
```

Then inspect the download button and get the server and new game IDs:

``` html
<form action="//dl3.vimm.net/" method="POST" id="dl-form" onsubmit="return submitDL(this, 'dialog3')">
    <input type="hidden" name="alt" value="0" disabled="">
    <input type="hidden" name="mediaId" value="3329">
    <button type="submit" style="width:100%">Download</button>
</form>
```
> In this case `3` and `3329`

Then run:

```bash
./vimm-downloader.sh
```

The script will:

```
 ╔═══════════════════════════════════╗
 ║          Vimm's Downloader        ║
 ╚═══════════════════════════════════╝

 # Input vault game ID: 234234
 # Input download server ID: 3
 # Input download server game ID: 43986

 # Fetching game information from https://dl3.vimm.net/?mediaId=43986...
 # Silent Hill (Europe) (En,Fr,De,Es,It).7z 243MiB

 # These are your current platforms:
     3ds gb gba n64
     nds nes new-nintendo-3ds nintendo-dsi
     ps2 psx switch

 # Select the platform: psx

 # Downloading Silent Hill (Europe) (En,Fr,De,Es,It).7z...
    242MiB/243MiB [==========================================>] 100% [7.66MiB/s]

 # Calculating hash for Silent Hill (Europe) (En,Fr,De,Es,It).bin...
 # Calculated hash is 980eaef02b5d8476964d9d37ffaa01cc
 # Expected hash is 980eaef02b5d8476964d9d37ffaa01cc
 # They match!

 # Calculating hash for Silent Hill (Europe) (En,Fr,De,Es,It).cue...
 # Calculated hash is 52991ae412eb216626250f6a425e18a8
 # Expected hash is empty
 # They don't match!

 # Bye bye!
```
---

## Requirements

The script relies on the following programs being installed and available in `PATH`, most of them are preinstalled:

| Tool              | Used for                                              |
| :--------------   | :---------------------------------------------------- |
| **`curl`**        | Fetching pages, headers and downloading.              |
| **`grep`**        | Extracting headers, hashes and formatting lines.      |
| **`7z`**          | Reading `.7z` and `.zip` files.                       |
| **`numfmt`**      | Formatting file size in human-readable units (MiB).   |
| **`pv`**          | Progress bar during the download.                     |
| **`md5sum`**      | Computing the MD5 hash of the extracted ROM.          |
| **`cut`**         | Isolating the MD5 value from `md5sum` output.         |
| **`tail`**        | Splitting the HTTP code from the response dump.       |
| **`sed / xargs`** | Output formatting.                                    |
| **`ls`**          | Listing directories to show available platforms.      |

> **Note:** `grep` must support the `-P` option.

## Configuration

Edit the variable at the top of the script to point to your ROM library:

```bash
BASE_DIR="/path/to/library/roms"
```

---

## Assumptions

The script is tailored to Vimm's Lair as it exists today. It assumes:

### Vimm's Lair
- **Hash file format is strict**: `MD5:` followed by 32 hex characters on the same line, inside the `Vimm's Lair.txt` file that ships with the archive. Variations like `md5:`, `MD5 =` are not supported as they are not expected.
- **No session cookie required**: the download server answers without any session cookie.
- **Only for .zip and .7z**: `7z` is used and does not test for other filetypes.
- **One MD5 entry per media file**: Vimm's Lair.txt lists (sometimes it does, sometimes it doesn't) the MD5 of **each** file inside the archive.

### System & environment
- **Designed for a RomM library**: the script assumes the [RomM](https://romm.app) server folder structure: `BASE_DIR` contains one subdirectory per platform (RomM collection) and the names of these platforms contain no spaces.
- **`BASE_DIR` exists and is writable**: both it and its platform subdirectories require read/write permissions (of course right?).
