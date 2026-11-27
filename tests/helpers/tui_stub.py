#!/usr/bin/env python3
"""Fake Claude-Code TUI for the compact-delivery test: shows the 2.1-style busy
spinner line for N seconds, then clears and waits for ONE submitted line and
appends it to the output file. If a second argument LINES=2 is given, it then
shows a "Compacting conversation…" spinner for 4 s and waits for a second
line (the follow-up), appending it too. Exits afterwards (so the tmux session
closes)."""
import sys
import time

out = sys.argv[1]
busy = float(sys.argv[2]) if len(sys.argv) > 2 else 6.0
lines = int(sys.argv[3]) if len(sys.argv) > 3 else 1

open(out, "w").close()
print("✳ Wrangling… (3s · ↓ 24 tokens)", flush=True)
time.sleep(busy)
print("\033[2J\033[H", end="", flush=True)
print("READY", flush=True)
for i in range(lines):
    line = sys.stdin.readline().rstrip("\n")
    with open(out, "a") as f:
        f.write(line + "\n")
    print("GOT: " + line, flush=True)
    if i + 1 < lines:
        print("✽ Compacting conversation… (2s)", flush=True)
        time.sleep(4)
        print("\033[2J\033[H", end="", flush=True)
        print("Compacted", flush=True)
time.sleep(1)
