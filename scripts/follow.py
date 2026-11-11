#!/usr/bin/env python3
"""call-copilot: следить за транскриптом созвона и печатать только новые строки.

Запускать через Monitor (каждая напечатанная пачка будит Claude):
  python3 ~/.claude/skills/call-copilot/scripts/follow.py --interval 60

Молчит, если нового нет. Сам выходит, когда окна заметок нет дольше --stop-after минут.
"""
from __future__ import annotations
import argparse
import json
import os
import sys
import time
from pathlib import Path

DIR = Path(os.environ.get("CALL_COPILOT_DIR") or Path.home() / "Library/Application Support/CallCopilot")
TXT, JSN = DIR / "live.txt", DIR / "live.json"


def reading() -> bool:
    try:
        return json.loads(JSN.read_text()).get("status") == "reading"
    except Exception:
        return False


def lines() -> list[str]:
    try:
        return TXT.read_text(encoding="utf-8").splitlines()
    except Exception:
        return []


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--interval", type=int, default=60)
    ap.add_argument("--stop-after", type=int, default=15, help="минут без окна заметок до выхода")
    ap.add_argument("--status", action="store_true", help="напечатать статус и весь транскрипт, выйти")
    a = ap.parse_args()
    if a.status:
        print(f"status={'reading' if reading() else 'no_window'} lines={len(lines())} dir={DIR}")
        print("\n".join(lines()))
        return
    seen = len(lines())
    idle_since = None
    print(f"[follow] старт, строк уже {seen}, шаг {a.interval}с, статус {'reading' if reading() else 'no_window'}", flush=True)
    while True:
        time.sleep(a.interval)
        ls = lines()
        if len(ls) < seen:  # прошлый созвон ушёл в архив, начат новый
            seen = 0
        new = ls[seen:]
        seen = len(ls)
        if new:
            print(f"[новое {time.strftime('%H:%M')}, {len(new)} стр]\n" + "\n".join(new), flush=True)
        if reading():
            idle_since = None
        else:
            idle_since = idle_since or time.time()
            if time.time() - idle_since > a.stop_after * 60:
                print("[follow] окна заметок нет дольше лимита, отключаюсь", flush=True)
                sys.exit(0)


if __name__ == "__main__":
    main()
