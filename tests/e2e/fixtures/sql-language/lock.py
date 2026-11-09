"""Настоящий SQLite lock до release marker; используется private E2E."""
import sqlite3
import sys
import time
from pathlib import Path

database,ready,release=map(Path,sys.argv[1:])
conn=sqlite3.connect(database,timeout=5)
try:
    conn.execute('BEGIN EXCLUSIVE')
    ready.write_text('locked',encoding='utf-8')
    deadline=time.monotonic()+25
    while not release.exists() and time.monotonic()<deadline:
        time.sleep(0.02)
finally:
    conn.rollback()
    conn.close()
