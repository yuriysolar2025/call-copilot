#!/usr/bin/env python3
"""call-copilot: живое чтение окна Zoom «Мои заметки».

Zoom сам расшифровывает созвон в окне «Мои заметки», но хранит текст в закрытой базе.
Поэтому окно раз в несколько секунд снимается и распознаётся локально (zoomnotes-ocr),
а снимки склеиваются по перекрытию в один журнал. Ничего не уходит в сеть.

  <DIR>/live.txt   накопленный текст текущего созвона
  <DIR>/live.json  {"status": "reading"|"no_window", "updated_at", "lines"}
  <DIR>/archive/   прошлые созвоны

DIR = $CALL_COPILOT_DIR или ~/Library/Application Support/CallCopilot
  zoom_notes_live.py          цикл (запускает LaunchAgent)
  zoom_notes_live.py --once   один распознанный снимок в stdout (проверка)
"""
from __future__ import annotations
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

DIR = Path(os.environ.get("CALL_COPILOT_DIR") or Path.home() / "Library/Application Support/CallCopilot")
OCR = DIR / "bin/zoomnotes-ocr"
INTERVAL = 8
IDLE_INTERVAL = 30
NEW_SESSION_AFTER = 30 * 60  # окна нет 30 мин -> следующий созвон пишется заново
HEADER = re.compile(r"^(Мои заметки|Готово|My notes|Done|Мої нотатки|[\d\s|Il]*\d\d:\d\d:\d\d)$", re.I)


def snapshot() -> list[str] | None:
    r = subprocess.run([str(OCR)], capture_output=True, text=True, timeout=60)
    out = r.stdout.strip()
    if out == "NOWIN" or out.startswith("ERR") or r.returncode != 0:
        return None
    lines = [l.strip() for l in out.splitlines() if l.strip() and not HEADER.match(l.strip())]
    return lines or None


def norm(s: str) -> str:
    return re.sub(r"[^\w]", "", s.lower())


def merge(log: list[str], snap: list[str]) -> list[str]:
    """Добавить из snap строки после самого длинного перекрытия с хвостом log."""
    if not log:
        return list(snap)
    tail = [norm(x) for x in log[-len(snap) - 5:]]
    sn = [norm(x) for x in snap]
    best = 0
    for k in range(min(len(sn), len(tail)), 0, -1):
        if tail[-k:] == sn[:k]:
            best = k
            break
    if best == 0:
        known = set(tail)
        idx = max((i for i, x in enumerate(sn) if x in known), default=-1)
        best = idx + 1
    return log + snap[best:]


def main() -> None:
    if "--once" in sys.argv:
        print("\n".join(snapshot() or ["NOWIN"]))
        return
    DIR.mkdir(parents=True, exist_ok=True)
    live = DIR / "live.txt"
    log = live.read_text(encoding="utf-8").splitlines() if live.exists() else []
    last_seen = time.time()
    while True:
        try:
            snap = snapshot()
        except Exception:
            snap = None
        now = time.time()
        if snap is None:
            if log and now - last_seen > NEW_SESSION_AFTER:
                arch = DIR / "archive"
                arch.mkdir(exist_ok=True)
                live.replace(arch / f"{datetime.now():%Y-%m-%d_%H-%M}.txt")
                log = []
            status = "no_window"
        else:
            last_seen = now
            new = merge(log, snap)
            if len(new) != len(log):
                log = new
                live.write_text("\n".join(log) + "\n", encoding="utf-8")
            status = "reading"
        (DIR / "live.json").write_text(json.dumps({
            "status": status,
            "updated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "lines": len(log),
        }, ensure_ascii=False))
        time.sleep(INTERVAL if status == "reading" else IDLE_INTERVAL)


if __name__ == "__main__":
    main()
