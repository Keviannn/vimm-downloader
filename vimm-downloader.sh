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

filename() {
    echo -en "${BOLD}${YELLOW}$*${RESET}"
}

info() {
    echo -en "${BOLD}${GREEN}$*${RESET}"
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

# Get ids from user
prompt "Input vault game ID: "
if ! read -r VAULT_ID || [ -z "$VAULT_ID" ] || ! [[ "$VAULT_ID" =~ ^[0-9]+$ ]]; then
    clean2
	error "Vault game ID is not valid!"
    exit 1
fi

VAULT_URL="https://vimm.net/vault/$VAULT_ID"

prompt "Input download server ID: "
if ! read -r SERVER_ID || [ -z "$SERVER_ID" ] || ! [[ "$SERVER_ID" =~ ^[0-9]+$ ]]; then
    clean2
	error "Server ID is not valid!"
    exit 1
fi

prompt "Input download server game ID: "
if ! read -r MEDIA_ID || [ -z "$MEDIA_ID" ] || ! [[ "$MEDIA_ID" =~ ^[0-9]+$ ]]; then
    clean2
	error "Media ID is not valid!"
    exit 1
fi

MEDIA_URL="https://dl$SERVER_ID.vimm.net/?mediaId=$MEDIA_ID"

echo
msg "Fetching game information from $(info "https://dl$SERVER_ID.vimm.net/?mediaId=$MEDIA_ID...")"

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

SIZE_VALUE=$(numfmt --to=iec --suffix=iB --format="%.2f" "$FILESIZE")

VALUE="${SIZE_VALUE%%[a-zA-Z]*}"    # Remove longer letter sufix
SUFFIX="${SIZE_VALUE##*[0-9.]}"     # Remove longer number prefix
DEC="${VALUE#*.}"                   # Remove shorter prefix until .
INT="${VALUE%%.*}"                  # Remove longer post .

# ≥100s no decimals, ≥10s one, <10s none
if [ "$INT" -ge 100 ]; then
    FILESIZE_SIMPLE="${INT}${SUFFIX}"
elif [ "$INT" -ge 10 ]; then
    FILESIZE_SIMPLE="${INT}.${DEC:0:1}${SUFFIX}"
else
    FILESIZE_SIMPLE="${VALUE}${SUFFIX}"
fi

msg "$(filename $FILENAME $FILESIZE_SIMPLE)\n"

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
msg "Downloading $(filename $FILENAME)"
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
            unzip -qq -j -o "$FILENAME" -d $TEMP
            if [ $? -ne 0 ]; then
                clean3
                error "Could not extract files!"
                exit 1
            fi
            ;;
        7z)
            7z e "$FILENAME" -o$TEMP -y -bso0 -bsp0
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


    EXTRACTED_FILES=$(find "$TEMP" -type f ! -name "$VIMM_FILE")

    if [ -z "$EXTRACTED_FILES" ]; then
        clean3
        error "Extracted files $EXTRACTED_FILES not found!"
        exit 1
    fi

    if [ ! -f "$TEMP/$VIMM_FILE" ]; then
        clean3
        error "Could not find HASH file: $TEMP/$VIMM_FILE"
        exit 1
    fi

    msg "Files extracted"
    echo

    for FILE in "$TEMP"/*; do
        NAME=$(basename "$FILE")

        [ ! -f "$FILE" ] && continue
        [ "$(basename "$FILE")" = "$VIMM_FILE" ] && continue

        HASH=$(grep -F -A 3 -m 1 "$NAME" "$TEMP/$VIMM_FILE" | grep -oP 'MD5:\s*\K[0-9a-fA-F]{32}' | head -n 1)

        CHASH=$(md5sum "$FILE" | cut -d' ' -f1)

        if [ -z "$HASH" ]; then
            clean3
            error "Could not get $(filename "$NAME") HASH form HASH file!"
            exit 1
        elif [ -z "$CHASH" ]; then
            clean3
            error "Could not calculate $(filename "$NAME") HASH!"
            exit 1
        fi

        msg "Calculated $(filename "$NAME") HASH: $(info "$CHASH")"
        msg "Expected $(filename "$NAME") HASH: $(info "$HASH")"

        if [ "$CHASH" == "$HASH" ]; then
            msg "$(info "Hashes match!")"
        else
            clean3
            error "Hashes do not match!"
            exit 1
        fi
        echo
    done
else
    if ! cd "$BASE_DIR"; then
        error "Could not access $BASE_DIR"
        exit 1
    fi
    clean2
    error "File $(filename $FILENAME) not found, can't calculate hash!"
    exit 1
fi

# Clean temp files
clean3

# Say bye
msg "$(filename "Bye bye!")"
