#!/bin/bash
set -uo pipefail

RESET='\033[0m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
BOLD='\033[1m'

BASE_DIR="path/to/library/roms"

VAULT_URL="https://vimm.net/vault/"
VIMM_FILE="Vimm's Lair.txt"

# Helping functions
msg() {
	echo -e "${BOLD} #${RESET} $*"
} 

error() {
    msg "${BOLD}${RED}ERROR: "$*"${RESET}"
} 

prompt() {
	echo -en "${BOLD} #${RESET} $*"
} 

filename() {
    echo -en "${BOLD}${YELLOW}$*${RESET}"
}

info() {
    echo -en "${BOLD}${GREEN}$*${RESET}"
}

fail() {
    echo -en "${BOLD}${RED}$*${RESET}"
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
prompt "Input download server ID: "
if ! read -r SERVER_ID || [ -z "$SERVER_ID" ] || ! [[ "$SERVER_ID" =~ ^[0-9]+$ ]]; then
	error "Server ID is not valid!"
    exit 1
fi

prompt "Input download server game ID: "
if ! read -r MEDIA_ID || [ -z "$MEDIA_ID" ] || ! [[ "$MEDIA_ID" =~ ^[0-9]+$ ]]; then
	error "Media ID is not valid!"
    exit 1
fi

MEDIA_URL="https://dl$SERVER_ID.vimm.net/?mediaId=$MEDIA_ID"

echo
msg "Fetching game information from $(info "https://dl$SERVER_ID.vimm.net/?mediaId=$MEDIA_ID"...)"

# Get final URL and game name and size
RESPONSE=$(
    curl \
        -s \
        -I \
        -D - \
        -o /dev/null \
        -w "%{http_code}" \
        -H "Referer: $VAULT_URL" \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0" \
        $MEDIA_URL
)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
HEADER=$(echo "$RESPONSE" | sed '$d')

if [ -z $HTTP_CODE ] || [ $HTTP_CODE -ne 200 ]; then
	error "Connection error to file: ${HTTP_CODE}"
    exit 1
fi

if [ -z "$HEADER" ]; then
	error "Could not get file headers!"
    exit 1
fi

# Get and print game information
FILENAME=$(grep -oP 'filename="\K[^"]+' <<< "$HEADER")
FILESIZE=$(grep -oP 'Content-Length:\s*\K\d+' <<< "$HEADER")

if [ -z "$FILENAME" ]; then
	error "Could not get game name!"
    exit 1
elif [ -z "$FILESIZE" ]; then
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
	error "Platform is not valid!"
    exit 1
fi
if ! cd "$PLATFORM"; then
    error "Could not access $PLATFORM"
    exit 1
fi

# Download game and add format with pv
echo
msg "Downloading $(filename $FILENAME)..."
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
    rm -f "$FILENAME"
    error "One of the 100 errors in curl occured: $STATUS!"   # Not serious error msg i know
    exit 1
fi

# Check hashes
if [ -f "$FILENAME" ]; then
    echo

    TXT=$(7z e -so "$FILENAME" "$VIMM_FILE")

    if [ -z "$TXT" ]; then
        error "No $VIMM_FILE in $(filename $FILENAME)!"
        exit 1
    fi

    # Im so proud of this piece of code right here
    7z l "$FILENAME" | grep -oP '^[0-9-]+\s+[0-9:]+\s+\S+\s+\d+\s+\d+\s+\K.*\.[a-zA-Z0-9]+$' | grep -v '\.txt$' | while read -r LINE; do
        FILE="${LINE##*/}"
        msg "Calculating hash for $(filename $FILE)..."

        CHASH=$(7z e "$FILENAME" -so "$LINE" | md5sum | cut -d' ' -f1)
        msg "Calculated hash is $(info $CHASH)"

        HASH=$(grep -F -A 3 -m 1 "$FILE" <<< "$TXT" | grep -oP 'MD5:\s*\K[0-9a-fA-F]{32}')

        if [ -z "$HASH" ]; then
            msg "Expected hash is $(fail "empty")"
        else
            msg "Expected hash is $(info $HASH)"
        fi

        if [ "$HASH" == "$CHASH" ]; then
            msg "$(info "They match!")"
        else
            msg "$(fail "They don't match!")"
        fi
        echo
    done
else
    error "File $(filename $FILENAME) not found, can't calculate hash!"
    exit 1
fi

# Say bye
msg "$(filename "Bye bye!")"
