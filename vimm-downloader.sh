#!/bin/bash
set -uo pipefail

RESET='\033[0m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
BOLD='\033[1m'

BASE_DIR="path/to/library/roms"

PAGE=".page"
HEADER=".header"
TEMP="./.temp"

VIMM_FILE="Vimm's Lair.txt"

# Helping functions
error() {
	echo -e "${BOLD} #${RED} ERROR: "$*"${RESET}" >&2
} 

msg() {
	echo -e "${BOLD} #${RESET} $*"
} 

prompt() {
	echo -en "${BOLD} #${RESET} $*"
} 

clean() {
    rm -f "$PAGE"
}

clean2() {
    rm -f "$PAGE" "$HEADER"
}

clean3() {
    [ -n "$TEMP" ] && rm -rf "$TEMP"
    if ! cd "$BASE_DIR"; then
        error "Could not access $BASE_DIR"
        exit 1
    fi
    clean2
}

# Start program
if ! cd "$BASE_DIR"; then
    error "Could not access $BASE_DIR"
    exit 1
fi

echo -e "\n ${BOLD}╔═══════════════════════════════════╗${RESET}"
echo -e " ${BOLD}║          ${RESET}${BOLD}${RED}Vimm's${RESET} ${BOLD}Downloader        ║${RESET}"
echo -e " ${BOLD}╚═══════════════════════════════════╝${RESET}\n"

if [ $# -ne 1 ]; then
	error "Vault ID not recieved as argument!"
	exit 1
fi

# Get vault html
VAULT_URL="https://vimm.net/vault/$1"

msg "Connecting to ${BOLD}${GREEN}$VAULT_URL${RESET}..."

HTTP_CODE1=$(
    curl \
        -s \
        -o $PAGE \
        -w "%{http_code}" \
        $VAULT_URL
)

if [ -z $HTTP_CODE1 ] || [ $HTTP_CODE1 -ne 200 ]; then
    clean2
	error "Could not get vault page: ${HTTP_CODE1:-0}!"
    exit 1
fi

# Find MEDIA_ID and SERVER_ID in the html
MEDIA_ID=$(grep -oP 'mediaId"\s*value="\K\d+' $PAGE 2>/dev/null)
SERVER_ID=$(grep -oP 'action="//dl\K\d+' $PAGE 2>/dev/null)

if [ -z "$MEDIA_ID" ]; then
    clean
	error "Could not get download server ID!"
    exit 1
elif [ -z "$SERVER_ID" ]; then
    clean
    error "Could not get download server URL ID!"
    exit 1
fi

msg "Fetched game URL\n"

MEDIA_URL="https://dl$SERVER_ID.vimm.net/?mediaId=$MEDIA_ID"

msg "Fetching game information from ${BOLD}${GREEN}https://dl$SERVER_ID.vimm.net/?mediaId=$MEDIA_ID${RESET}..."

# Get final URL and game name and size
HTTP_CODE2=$(
    curl \
        -s \
        -I \
        -o $HEADER \
        -w "%{http_code}" \
        -H "Referer: $VAULT_URL" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0" \
        $MEDIA_URL
)

if [ -z $HTTP_CODE2 ] || [ $HTTP_CODE2 -ne 200 ]; then
    clean2
	error "Connection error to file: ${HTTP_CODE2}"
    exit 1
fi

# Get and print game information
FILENAME=$(grep -oP 'filename="\K[^"]+' $HEADER 2>/dev/null)
FILESIZE=$(grep -oP 'Content-Length:\s*\K\d+' $HEADER 2>/dev/null)

if [ -z "$FILENAME" ]; then
    clean
	error "Could not get game name!"
    exit 1
elif [ -z "$FILESIZE" ]; then
    clean
    error "Could not get game size!"
    exit 1
fi

FILESIZE_SIMPLE=$(numfmt --to=iec --suffix=iB --format="%.2f" "$FILESIZE" | sed 's/\([0-9]*\.[0-9]\)[0-9]*\([a-zA-Z]*\)/\1\2/') # Truncate to 1 decimal as pv

msg "${BOLD}${YELLOW}$FILENAME $FILESIZE_SIMPLE${RESET}\n"

# Set download directory
msg "These are your current platforms:"
ls --color=always | xargs -n 4 | sed 's/^/     /'
echo
prompt "Select the platform: "
if ! read -r PLATFORM || [ -z "$PLATFORM" ] || [ ! -e "$PLATFORM" ]; then
    clean2
	error "Platform is not valid!"
    exit 1
fi
if ! cd "$PLATFORM"; then
    error "Could not access $PLATFORM"
    exit 1
fi



# Download game and add format with pv
echo
msg "Downloading ${BOLD}${YELLOW}$FILENAME${RESET}"
curl \
    -s \
    -f \
    --retry 3 \
    --retry-delay 5 \
    -H "Referer: $VAULT_URL" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0" \
    $MEDIA_URL | pv -s "$FILESIZE" -F "   %b/${FILESIZE_SIMPLE} %p %r" -w 80 > "$FILENAME"

STATUS=$?
if [ $STATUS -ne 0 ]; then
    if ! cd "$BASE_DIR"; then
        error "Could not access $BASE_DIR"
        exit 1
    fi
    rm -f "$FILENAME"
    clean2
    error "One of the 100 errors in curl occured: $STATUS!"   # Not serious error msg i know
    exit 1
fi

# Check hashes
if [ -f "$FILENAME" ]; then
    echo
    msg "Extracting files to calculate HASH..."

    if ! mkdir -p "$TEMP"; then
        clean3
        error "Could not create $TEMP"
        exit 1
    fi

    case ${FILENAME##*.} in
        zip)
            unzip -q -o "$FILENAME" -d $TEMP
            if [ $? -ne 0 ]; then
                clean3
                error "Could not extract files!"
                exit 1
            fi
            ;;
        7z)
            7z x "$FILENAME" -o $TEMP -y
            if [ $? -ne 0 ]; then
                clean3
                error "Could not extract files!"
                exit 1
            fi
            ;;
        *)
            clean3
            error "Filetype not supported!"
            exit 1
            ;;
    esac


    EXTRACTED_FILE=$(find $TEMP -type f -name "${FILENAME%.*}.*" | head -n 1)

    if [ -z "$EXTRACTED_FILE" ]; then
        clean3
        error "Extracted file $EXTRACTED_FILE not found!"
        exit 1
    fi

    if [ ! -f "$TEMP/$VIMM_FILE" ]; then
        clean3
        error "Could not find HASH file: $TEMP/$VIMM_FILE"
        exit 1
    fi

    msg "Files extracted"

    HASH=$(grep -oP 'MD5:\s*\K[0-9a-fA-F]{32}' "$TEMP/$VIMM_FILE" 2>/dev/null)
    CHASH=$(md5sum "$EXTRACTED_FILE" | cut -d' ' -f1)

    if [ -z "$HASH" ]; then
        clean3
        error "Could not get game HASH!"
        exit 1
    elif [ -z "$CHASH" ]; then
        clean3
        error "Could not calculate game HASH!"
        exit 1
    fi

    msg "Calculated HASH: ${BOLD}${GREEN}${CHASH}${RESET}"
    msg "Expected HASH: ${BOLD}${GREEN}${HASH}${RESET}"

    if [ "$CHASH" == "$HASH" ]; then
        msg "${BOLD}${GREEN}Hashes match!${RESET}"
    else
        clean3
        error "Hashes do not match!"
        exit 1
    fi
else
    if ! cd "$BASE_DIR"; then
        error "Could not access $BASE_DIR"
        exit 1
    fi
    clean2
    error "File $FILENAME not found, can't calculate hash!"
    exit 1
fi

# Clean temp files
clean3

# Say bye
echo
msg "${BOLD}${YELLOW}Bye bye!${RESET}"
