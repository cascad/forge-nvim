"""Explicit Windows LLDB observer. Run inside prepared LLDB, never system Python."""
import ctypes as C
from ctypes import wintypes as W
import hashlib
import json
import os
from pathlib import Path
import time
import traceback

import lldb


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run():
    request_path = Path(os.environ["FORGE_NATIVE_ASSERT_REQUEST"])
    deadline = time.monotonic() + 10
    while not request_path.exists() and time.monotonic() < deadline:
        time.sleep(0.02)
    request = read(request_path)
    output = Path(request["output"]).resolve()
    result = {"attached": False, "pid": request["pid"], "host_pid": request["host_pid"]}
    process = None
    handles = []

    def save(name, value):
        path = output / name
        temp = path.with_suffix(".tmp")
        temp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
        temp.replace(path)

    try:
        root = Path(request["root"]).resolve()
        output.relative_to(root / ".tests")
        runtime = Path(request["runtime"]).resolve()
        owner = read(runtime / ".forge-e2e-owner.json")
        assert Path(owner["root"]).resolve() == root and Path(owner["path"]).resolve() == runtime
        assert owner["token"] == request["token"], "Runtime owner token mismatch"
        sdk = read(root / ".tools/neovim/windows-x64/forge-sdk.json")
        lock = read(root / "scripts/sdk/windows.json")
        for key in ("Schema", "SourceRevision", "PatchSHA256", "ProcessPatchSHA256", "ProcessSourceSHA256"):
            assert sdk[key] == lock[key], "SDK lock mismatch: " + key
        exe = (root / ".tools/neovim/windows-x64" / sdk["Binary"]).resolve()
        assert sdk["Ready"] and digest(exe).upper() == sdk["BinarySHA256"]
        assert exe.with_suffix(".pdb").is_file(), "Selected SDK PDB missing"
        debug_root = root / ".tests/rust-deps/codelldb/extension/lldb"
        manifest = read(root / ".tests/rust-deps/manifest.json")
        for name in ("lldb.exe", "liblldb.dll", "python312.dll"):
            assert digest(debug_root / "bin" / name) == manifest["files"]["codelldb\\extension\\lldb\\bin\\" + name]
        result.update(version=lldb.SBDebugger.GetVersionString(), sdk_sha256=digest(exe))

        kernel = C.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.argtypes = [W.DWORD, W.BOOL, W.DWORD]
        kernel.OpenProcess.restype = W.HANDLE
        kernel.QueryFullProcessImageNameW.argtypes = [W.HANDLE, W.DWORD, W.LPWSTR, C.POINTER(W.DWORD)]
        kernel.GetProcessTimes.argtypes = [W.HANDLE] + [C.POINTER(W.FILETIME)] * 4
        kernel.QueryInformationJobObject.argtypes = [W.HANDLE, C.c_int, W.LPVOID, W.DWORD, W.LPVOID]
        kernel.CloseHandle.argtypes = [W.HANDLE]
        job = W.HANDLE(request["job_handle"])
        handles.append(job)

        def identity(pid):
            handle = kernel.OpenProcess(0x100000 | 0x1000, False, pid)  # SYNCHRONIZE | QUERY_LIMITED
            assert handle, "OpenProcess failed: " + str(C.get_last_error())
            handles.append(handle)  # Keep identity alive until detach/kill, no PID reuse.
            image, size = C.create_unicode_buffer(32768), W.DWORD(32768)
            assert kernel.QueryFullProcessImageNameW(handle, 0, image, C.byref(size))
            assert Path(image.value).resolve() == exe, "Unexpected target image"
            times = [W.FILETIME() for _ in range(4)]
            assert kernel.GetProcessTimes(handle, *[C.byref(t) for t in times])
            return {"pid": pid, "image": image.value, "created": times[0].dwLowDateTime | (times[0].dwHighDateTime << 32)}

        host = identity(request["host_pid"])
        target_identity = identity(request["pid"])
        assert target_identity["created"] >= host["created"], "Target predates its fixture host"
        # The controller duplicated QUERY-only rights to the exact fixture Job.
        # Its process list includes nested Jobs (libuv/ConPTY have their own).
        ids = C.create_string_buffer(8 + 4096 * C.sizeof(C.c_size_t))
        assert kernel.QueryInformationJobObject(job, 3, ids, len(ids), None), "Cannot query fixture Job"
        count = C.c_uint32.from_buffer(ids, 4).value
        members = list((C.c_size_t * count).from_buffer(ids, 8))
        result.update(host=host, target=target_identity, job_members=members)
        assert request["pid"] in members and request["host_pid"] in members, "Target is outside the fixture Job"
        debugger = lldb.debugger
        debugger.SetAsync(True)
        target = debugger.CreateTarget(str(exe))
        assert target.IsValid(), "Cannot create debugger target"
        symbols = target.FindFunctions("wstream_write")
        assert symbols.GetSize() > 0, "SDK symbols unavailable"
        breakpoint = target.BreakpointCreateByName("_wassert")
        listener, error = lldb.SBListener("forge-native-assert"), lldb.SBError()
        process = target.AttachToProcessWithID(listener, request["pid"], error)
        assert error.Success() and process.IsValid(), "Attach failed: " + str(error)
        result["attached"] = True
        assert breakpoint.GetNumLocations() > 0, "CRT assertion breakpoint unresolved"
        initial_stop = process.GetStopID()
        assert process.Continue().Success(), "Cannot resume after attach"
        save("ready.json", {**result, "breakpoint_locations": breakpoint.GetNumLocations()})
        deadline = time.monotonic() + request.get("seconds", 20)
        while time.monotonic() < deadline and not (output / "stop").exists():
            event = lldb.SBEvent()
            listener.WaitForEvent(1, event)
            state = process.GetState()
            if state in (lldb.eStateExited, lldb.eStateDetached):
                result.update(outcome="target-exited", exit_status=process.GetExitStatus())
                break
            if state != lldb.eStateStopped or process.GetStopID() == initial_stop:
                continue
            threads, assertion = [], False
            assertion_args = None
            for thread in process:
                reason = thread.GetStopReason()
                hit = reason == lldb.eStopReasonBreakpoint and thread.GetStopReasonDataCount() >= 2 and thread.GetStopReasonDataAtIndex(0) == breakpoint.GetID()
                assertion = assertion or hit
                if hit:
                    frame = thread.GetFrameAtIndex(0)
                    def wide_argument(register):
                        address = frame.FindRegister(register).GetValueAsUnsigned()
                        error = lldb.SBError()
                        data = process.ReadMemory(address, 512, error)
                        if not error.Success():
                            return None
                        end = next((i for i in range(0, len(data)-1, 2) if data[i:i+2] == b"\0\0"), len(data))
                        return data[:end].decode("utf-16-le", errors="replace")
                    assertion_args = {"expression": wide_argument("rcx"), "file": wide_argument("rdx"),
                                      "line": frame.FindRegister("r8").GetValueAsUnsigned()}
                frames = []
                for frame in list(thread)[:64]:
                    line = frame.GetLineEntry()
                    item = {"pc": hex(frame.GetPC()), "function": frame.GetFunctionName(),
                                   "module": str(frame.GetModule().GetFileSpec()),
                                   "file": str(line.GetFileSpec()) if line.IsValid() else None,
                                   "line": line.GetLine() if line.IsValid() else None}
                    if "wstream_write" in (frame.GetFunctionName() or ""):
                        stream = frame.FindVariable("stream")
                        item["stream"] = {"address": stream.GetValue(), "error": str(stream.GetError())}
                        if stream.IsValid() and stream.GetError().Success():
                            item["stream"]["fields"] = {name: stream.Dereference().GetChildMemberWithName(name).GetValue()
                                                       for name in ("closed", "pending_reqs", "maxmem")}
                    frames.append(item)
                threads.append({"tid": thread.GetThreadID(), "reason": reason, "assertion": hit, "frames": frames})
            phase = (output / "phase.json")
            capture = {**result, "assertion": assertion, "threads": threads,
                       "assertion_args": assertion_args,
                       "phase": read(phase) if phase.exists() else None}
            save("capture.json", capture)
            if assertion:
                result.update(outcome="assertion-captured", diagnostic_termination=True)
                assert process.Kill().Success(), "Cannot terminate captured assertion fixture"
            else:
                result["outcome"] = "unexpected-stop"
            break
        else:
            result["outcome"] = "stop-request" if (output / "stop").exists() else "deadline"
    except Exception:
        result.update(outcome="error", error=traceback.format_exc())
    finally:
        if process and process.IsValid() and process.GetState() not in (lldb.eStateDetached, lldb.eStateExited):
            detached = process.Detach()
            result["detached"] = detached.Success()
            if not detached.Success():
                result["detach_error"] = str(detached)
        for handle in handles:
            kernel.CloseHandle(handle)
        save("done.json", result)


run()
