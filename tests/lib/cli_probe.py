"""Настоящий subprocess с артефактами; deadline и ошибка вызывающего сохраняются."""

from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess
import time


def run(argv, *, cwd, env, timeout, artifacts, context_files=(), errors=None):
    folder = Path(artifacts) / str(time.monotonic_ns())
    folder.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    data = dict(argv=argv if isinstance(argv, str) else [str(a) for a in argv], cwd=str(cwd), timeout=timeout,
                started=datetime.now(timezone.utc).isoformat(), pid=None)

    def save(name, value):
        (folder / name).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")

    save("started.json", data)
    process = None
    stdout, stderr = "", ""
    data.update(timed_out=False, returncode=None)
    try:
        process = subprocess.Popen(argv, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True, errors=errors)
        data["pid"] = process.pid
        save("started.json", data)
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired as error:
            data["timed_out"] = True
            process.kill()
            stdout, stderr = process.communicate()
            error.output, error.stderr = stdout, stderr
            raise
        return subprocess.CompletedProcess(argv, process.returncode, stdout, stderr)
    except Exception as error:
        data["error"] = repr(error)
        if process is not None and process.poll() is None:
            process.kill()
            stdout, stderr = process.communicate()
        raise
    finally:
        data.update(elapsed=time.monotonic() - started, stdout=stdout, stderr=stderr,
                    returncode=process.returncode if process is not None else None)
        if data.get("error") or data["returncode"] != 0:
            # Только явно перечисленные fixture scripts; не HOME и не всё env.
            for index, source in enumerate(context_files):
                source = Path(source)
                if source.is_file():
                    shutil.copyfile(source, folder / (str(index) + "-" + source.name))
        save("result.json", data)
