"""Настоящий интерактивный PTY-процесс для клавиатурного E2E терминала."""
import os
import sys

print(f"FORGE_TERM_READY {os.getpid()}", flush=True)
for line in sys.stdin:
    line = line.rstrip("\r\n")
    if line == "FORGE_TERM_EXIT":
        print("FORGE_TERM_BYE", flush=True)
        break
    print("FORGE_TERM_ACK:" + line, flush=True)
