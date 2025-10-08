#!/bin/bash
# Fuzz session logger
# Usage: ./fuzz/log.sh SESSION_ID "description" "file_path"

if [ $# -ne 3 ]; then
    echo "Usage: $0 SESSION_ID DESCRIPTION FILE_PATH"
    exit 1
fi

SESSION_ID="$1"
DESCRIPTION="$2"
FILE_PATH="$3"

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

echo "$TIMESTAMP | $SESSION_ID | $DESCRIPTION | $FILE_PATH" >> fuzz/history.txt
echo "Logged: $TIMESTAMP | $SESSION_ID | $DESCRIPTION"
