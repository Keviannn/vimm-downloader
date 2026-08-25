# Vimm's Downloader

A Bash script to download ROMs from [Vimm's Lair](https://vimm.net) with **MD5 integrity verification** intended for your [RomM](https://romm.app) Library.

---

## ⚠️ Disclaimer ⚠️

This script is intended **only** to download a game you like directly to your own server, because you do not have a graphic instalation.

It is **not** meant to attack, scrape, automate in bulk, or otherwise hammer Vimm's API.

The actual desing, because of Vimm's bot protection and my own principles, only works with a valid session on a real browser, passing the bot protection in a legitimate way and getting the provided data.

---

## Overview

Vimm's Lair serves ROMs through a vault page that points to a dedicated download server URL (`dlX.vimm.net`). This script automates the whole flow:

1. Asks the user fot the Vault's game ID, the download server ID and the download server game ID.
2. Resolves the download URL and reads the file name and size from the HTTP headers.
3. Lets you pick a target platform from your local ROM library.
4. Downloads the file with a progress bar.
5. Extracts the ROM files and verifies **each one's MD5** against Vimm's official hash (multi-file ROMs like PSX .bin/.cue are fully supported) and keeps only the compressed file.

⚠️ Some files do not come with HASH for their .bin, because of this and if someone does not care too much about integrity, an error with hashes keeps the original compressed file.

---

## Use Case

You have a ROM library organized by platform (e.g. `/home/user/emu/library/roms/n64`). You find the game you want on Vimm's Lair and copy the vault ID from the URL:

```
https://vimm.net/vault/12345
```

Then inspect the download button and get the server and new game ID:

``` html
<form action="//dl3.vimm.net/" method="POST" id="dl-form" onsubmit="return submitDL(this, 'dialog3')">
    <input type="hidden" name="alt" value="0" disabled="">
    <input type="hidden" name="mediaId" value="3329">
    <button type="submit" style="width:100%">Download</button>
</form>
```
> In this case 3 and 3329

Then run:

```bash
./vimm-downloader.sh
```

The script will:

```
 ╔═══════════════════════════════════╗
 ║          Vimm's Downloader        ║
 ╚═══════════════════════════════════╝

 # Input vault game ID: 3454
 # Input download server ID: 3
 # Input download server game ID: 3329

 # Fetching game information from https://dl3.vimm.net/?mediaId=3329...
 # Pokemon - Red Version (USA, Europe) (SGB Enhanced).zip 359KiB

 # These are your current platforms:
     gb

 # Select the platform: gb

 # Downloading Pokemon - Red Version (USA, Europe) (SGB Enhanced).zip
    359KiB/359KiB [==========================================>] 100% [ 142KiB/s]

 # Extracting files to calculate HASH...
 # Files extracted

 # Calculated Pokemon - Red Version (USA, Europe) (SGB Enhanced).gb HASH: 3d45c1ee9abd5738df46d2bdda8b57dc
 # Expected Pokemon - Red Version (USA, Europe) (SGB Enhanced).gb HASH: 3d45c1ee9abd5738df46d2bdda8b57dc
 # Hashes match!

 # Bye bye!
```

⚠️ Only the `.zip` (or `.7z`) file is kept; the extracted ROM is verified and then discarded. I'm working on making a better approach for temporary files, specially with hash calculation, to reduce the I/O operations in the disk using more RAM (for temporary files is easy and tiny roms too, but having a 10GB ROM stored in RAM might not be really cool).

---

## Requirements

The script relies on the following programs being installed and available in `PATH`, most of them are preinstalled:

| Tool            | Used for                                              |
| :-------------- | :---------------------------------------------------- |
| **`curl`**      | Fetching pages, headers and downloading.               |
| **`grep`**      | Extracting IDs, file names and hashes.   |
| **`unzip`**     | Extracting `.zip` files.             |
| **`7z`**        | Extracting `.7z` files.           |
| **`numfmt`**    | Formatting file size in human-readable units (MiB).   |
| **`pv`**        | Progress bar during the download.                     |
| **`md5sum`**    | Computing the MD5 hash of the extracted ROM.          |
| **`find` / `head`** | Locating the extracted ROM inside the temp folder. |
| **`cut`**       | Isolating the MD5 value from `md5sum` output.         |
| **sed / xargs** | Output formatting. |
| **`ls`**        | Listing directories to show available platforms.      |

> **Note:** `grep` must suppor the `-P` option.

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
- **Only `.zip` and `.7z` are supported**: any other file format triggers a "Filetype not supported" error and aborts the download as they are not expected.
- **One MD5 entry per media file**: Vimm's Lair.txt lists (sometimes it does, sometimes it doesen't) the MD5 of **each** file inside the archive.

### System & environment
- **Designed for a RomM library**: the script assumes the [RomM](https://romm.app) server folder structure: `BASE_DIR` contains one subdirectory per platform (RomM collection) and the names of this platforms contain no spaces.
- **`BASE_DIR` exists and is writable**: both it and its platform subdirectories require read/write permissions (of course right?).
