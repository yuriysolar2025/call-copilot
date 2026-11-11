#!/bin/bash
# call-copilot: установка на Mac. Безопасно запускать повторно.
#   install.sh              поставить и запустить фоновый читатель заметок Zoom
#   install.sh --no-launch  только собрать и разложить файлы (для проверки)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="${CALL_COPILOT_DIR:-$HOME/Library/Application Support/CallCopilot}"
LABEL="${CALL_COPILOT_LABEL:-com.call-copilot.zoom-notes}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
PY=/usr/bin/python3

[ "$(uname)" = Darwin ] || { echo "Нужен macOS: читаем окно Zoom через системный OCR."; exit 1; }
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Нет Command Line Tools (компилятор Swift). Запусти:  xcode-select --install  и повтори."; exit 1
fi
$PY -c 'import sys; assert sys.version_info >= (3, 9)' || { echo "Нужен python3 >= 3.9 (системный /usr/bin/python3 подходит)."; exit 1; }

mkdir -p "$DIR/bin" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
echo "• собираю OCR (Vision, локально)…"
swiftc -O -o "$DIR/bin/zoomnotes-ocr" "$HERE/ocr.swift"
[ -x "$DIR/bin/zoomnotes-ocr" ] || { echo "Сборка OCR не удалась."; exit 1; }
cp "$HERE/zoom_notes_live.py" "$DIR/bin/zoom_notes_live.py"
chmod +x "$DIR/bin/zoom_notes_live.py"

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array>
<string>$PY</string>
<string>$DIR/bin/zoom_notes_live.py</string>
</array>
<key>EnvironmentVariables</key><dict><key>CALL_COPILOT_DIR</key><string>$DIR</string></dict>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>ThrottleInterval</key><integer>30</integer>
<key>StandardErrorPath</key><string>$HOME/Library/Logs/call-copilot.err</string>
<key>StandardOutPath</key><string>/dev/null</string>
</dict></plist>
PL

if [ "${1:-}" = "--no-launch" ]; then
  echo "✓ файлы разложены в $DIR, агент не запускался ($PLIST)"; exit 0
fi

echo "• первый снимок (здесь macOS может спросить разрешение «Запись экрана»)…"
CALL_COPILOT_DIR="$DIR" $PY "$DIR/bin/zoom_notes_live.py" --once | head -3 || true

launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
sleep 2
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  echo "✓ фоновый читатель запущен. Статус: cat \"$DIR/live.json\""
else
  echo "✗ агент не поднялся, смотри $HOME/Library/Logs/call-copilot.err"; exit 1
fi
cat <<MSG

Осталось одно ручное действие, если его ещё нет:
  Системные настройки → Конфиденциальность и безопасность → Запись экрана и системного звука
  → добавить  $DIR/bin/zoomnotes-ocr  и  /usr/bin/python3  (или Terminal, откуда запускал).
Без этого снимок окна пустой и статус всегда no_window.
Проверка: открой Zoom, включи «Мои заметки», подожди 10 с и выполни  cat "$DIR/live.json"
MSG
