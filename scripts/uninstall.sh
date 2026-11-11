#!/bin/bash
# call-copilot: снять агент и удалить программу. Транскрипты (live.txt, archive/) остаются.
set -euo pipefail
DIR="${CALL_COPILOT_DIR:-$HOME/Library/Application Support/CallCopilot}"
LABEL="${CALL_COPILOT_LABEL:-com.call-copilot.zoom-notes}"
launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -f "${DIR:?}/bin/zoomnotes-ocr" "${DIR:?}/bin/zoom_notes_live.py"
rmdir "${DIR:?}/bin" 2>/dev/null || true
echo "✓ call-copilot снят, транскрипты остались в $DIR"
