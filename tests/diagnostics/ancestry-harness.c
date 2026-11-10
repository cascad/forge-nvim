// Native fixture: только собственные процессы, controlled snapshot, не SDK binary.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tlhelp32.h>
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <signal.h>
#ifndef SIGKILL
#define SIGKILL 9
#endif

typedef struct { HANDLE handle; DWORD pid; uint64_t creation; } Owned;
typedef struct { DWORD parent, pid; } Row;
typedef struct { int index; } Snapshot;
static Owned owned[3]; // older, root, настоящий child root.
static Row rows[3];
static Snapshot *snapshots[16];
static DWORD killed[3], fail_time_pid;
static int outside, kill_count, query_count;

static uint64_t creation(HANDLE process)
{
  FILETIME start, exit_time, kernel, user;
  if (!GetProcessTimes(process, &start, &exit_time, &kernel, &user)) return 0;
  return ((uint64_t)start.dwHighDateTime << 32) | start.dwLowDateTime;
}

static bool allowed(DWORD pid)
{
  for (int i = 0; i < 3; i++) if (owned[i].pid == pid && pid != 0) return true;
  return false;
}

static HANDLE fixture_open(DWORD access, BOOL inherit, DWORD pid)
{
  if (!allowed(pid)) { outside++; SetLastError(ERROR_ACCESS_DENIED); return NULL; }
  return OpenProcess(access, inherit, pid);
}

static BOOL fixture_terminate(HANDLE process, UINT code)
{
  DWORD pid = GetProcessId(process);
  if (!allowed(pid) || kill_count >= 3) { outside++; return FALSE; }
  killed[kill_count++] = pid;
  return TerminateProcess(process, code);
}

static BOOL fixture_times(HANDLE p, LPFILETIME a, LPFILETIME b, LPFILETIME c, LPFILETIME d)
{
  query_count++;
  if (GetProcessId(p) == fail_time_pid) { SetLastError(ERROR_ACCESS_DENIED); return FALSE; }
  return GetProcessTimes(p, a, b, c, d);
}

static HANDLE fixture_snapshot(DWORD flags, DWORD pid)
{
  (void)flags; (void)pid;
  for (int i = 0; i < 16; i++) if (!snapshots[i]) {
    snapshots[i] = calloc(1, sizeof(Snapshot));
    return snapshots[i] ? (HANDLE)snapshots[i] : INVALID_HANDLE_VALUE;
  }
  return INVALID_HANDLE_VALUE;
}

static BOOL fixture_next(HANDLE h, LPPROCESSENTRY32 entry)
{
  Snapshot *snapshot = (Snapshot *)h;
  if (snapshot->index >= 3) return FALSE;
  Row row = rows[snapshot->index++];
  entry->th32ProcessID = row.pid; entry->th32ParentProcessID = row.parent;
  return TRUE;
}

static BOOL fixture_first(HANDLE h, LPPROCESSENTRY32 entry)
{
  ((Snapshot *)h)->index = 0;
  return fixture_next(h, entry);
}

static BOOL fixture_close(HANDLE h)
{
  for (int i = 0; i < 16; i++) if ((HANDLE)snapshots[i] == h && h != NULL) {
    free(snapshots[i]); snapshots[i] = NULL; return TRUE;
  }
  return CloseHandle(h);
}

#undef Process32First
#undef Process32Next
#define CreateToolhelp32Snapshot fixture_snapshot
#define Process32First fixture_first
#define Process32Next fixture_next
#define OpenProcess fixture_open
#define TerminateProcess fixture_terminate
#define GetProcessTimes fixture_times
#define CloseHandle fixture_close
#define ILOG(...) ((void)0)
#define ELOG(...) ((void)0)

/* FORGE_PROC_FRAGMENT */

#undef CreateToolhelp32Snapshot
#undef Process32First
#undef Process32Next
#undef OpenProcess
#undef TerminateProcess
#undef GetProcessTimes
#undef CloseHandle

static bool spawn(const wchar_t *args, HANDLE job, Owned *target)
{
  wchar_t exe[32768], command[32768];
  if (!GetModuleFileNameW(NULL, exe, 32768)) return false;
  if (swprintf_s(command, 32768, L"\"%ls\" %ls", exe, args) < 0) return false;
  STARTUPINFOW startup = {0}; startup.cb = sizeof(startup);
  PROCESS_INFORMATION info = {0};
  if (!CreateProcessW(NULL, command, NULL, NULL, FALSE, CREATE_SUSPENDED | CREATE_NO_WINDOW,
                      NULL, NULL, &startup, &info)) return false;
  target->handle = info.hProcess; target->pid = info.dwProcessId;
  if (job && !AssignProcessToJobObject(job, info.hProcess)) {
    TerminateProcess(info.hProcess, 123); CloseHandle(info.hThread); return false;
  }
  target->creation = creation(info.hProcess);
  bool resumed = ResumeThread(info.hThread) != (DWORD)-1;
  CloseHandle(info.hThread);
  return resumed;
}

static DWORD actual_parent(DWORD pid)
{
  DWORD parent = 0;
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return 0;
  PROCESSENTRY32 entry = {0}; entry.dwSize = sizeof(entry);
  if (Process32FirstW(snapshot, &entry)) do {
    if (entry.th32ProcessID == pid) { parent = entry.th32ParentProcessID; break; }
  } while (Process32NextW(snapshot, &entry));
  CloseHandle(snapshot); return parent;
}

int wmain(int argc, wchar_t **argv)
{
  if (argc == 2 && !wcscmp(argv[1], L"--worker")) { Sleep(60000); return 124; }
  if (argc == 3 && !wcscmp(argv[1], L"--branch")) {
    Owned child = {0};
    if (!spawn(L"--worker", NULL, &child)) return 125;
    FILE *file = NULL;
    if (_wfopen_s(&file, argv[2], L"w") != 0) return 126;
    fprintf(file, "%lu\n", (unsigned long)child.pid); fclose(file);
    Sleep(60000); CloseHandle(child.handle); return 124;
  }
  if (argc != 3) { fputs("case ready-file required\n", stderr); return 125; }
  bool stale = !wcscmp(argv[1], L"stale");
  bool child_failure = !wcscmp(argv[1], L"child-query-failure");
  bool root_failure = !wcscmp(argv[1], L"root-query-failure");
  if (!stale && !child_failure && !root_failure && wcscmp(argv[1], L"valid")) return 125;
  HANDLE job = CreateJobObjectW(NULL, NULL);
  if (!job) return 125;
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  int result = 125;
  bool scope_clean = true;
  if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) goto cleanup;
  if (!spawn(L"--worker", job, &owned[0])) goto cleanup;
  Sleep(25); // Реальная creation time older < root, без подкрутки часов.
  wchar_t branch[32768];
  if (swprintf_s(branch, 32768, L"--branch \"%ls\"", argv[2]) < 0) goto cleanup;
  if (!spawn(branch, job, &owned[1])) goto cleanup;
  DWORD child_pid = 0;
  for (int tick = 0; tick < 200 && !child_pid; tick++) {
    FILE *file = NULL;
    if (_wfopen_s(&file, argv[2], L"r") == 0) {
      unsigned long got = 0; if (fscanf_s(file, "%lu", &got) == 1) child_pid = (DWORD)got;
      fclose(file);
    }
    if (!child_pid) Sleep(10);
  }
  owned[2].pid = child_pid;
  if (!child_pid || actual_parent(child_pid) != owned[1].pid) goto cleanup;
  owned[2].handle = OpenProcess(PROCESS_QUERY_INFORMATION | SYNCHRONIZE, FALSE, child_pid);
  if (!owned[2].handle) goto cleanup;
  owned[2].creation = creation(owned[2].handle);
  for (int i = 0; i < 3; i++) {
    BOOL member = FALSE;
    if (!IsProcessInJob(owned[i].handle, job, &member) || !member) goto cleanup;
  }
  if (!owned[0].creation || owned[0].creation >= owned[1].creation || owned[1].creation > owned[2].creation) goto cleanup;
  rows[0] = (Row){stale ? owned[1].pid : GetCurrentProcessId(), owned[0].pid};
  rows[1] = (Row){GetCurrentProcessId(), owned[1].pid};
  rows[2] = (Row){owned[1].pid, owned[2].pid};
  fail_time_pid = child_failure ? owned[2].pid : root_failure ? owned[1].pid : 0;
  bool stopped = os_proc_tree_kill((int)owned[1].pid, SIGTERM);
  WaitForSingleObject(owned[1].handle, 2000);
  Sleep(50);
  DWORD exits[3] = {0};
  for (int i = 0; i < 3; i++) GetExitCodeProcess(owned[i].handle, &exits[i]);
  bool older_alive = exits[0] == STILL_ACTIVE, child_alive = exits[2] == STILL_ACTIVE;
  bool ok = stopped && exits[1] == SIGTERM && older_alive && child_alive == (child_failure || root_failure) && !outside;
  printf("{\"mode\":\"controlled-snapshot-real-workers\",\"job_members_verified\":3,\"ok\":%s,\"stale_edge\":%s,\"query_failure_pid\":%lu,\"query_calls\":%d,\"outside_attempts\":%d,\"workers\":[",
         ok ? "true" : "false", stale ? "true" : "false", (unsigned long)fail_time_pid, query_count, outside);
  for (int i = 0; i < 3; i++) printf("%s{\"pid\":%lu,\"creation_100ns\":%llu,\"exit\":%lu}",
    i ? "," : "", (unsigned long)owned[i].pid, (unsigned long long)owned[i].creation, (unsigned long)exits[i]);
  fputs("],\"termination_targets\":[", stdout);
  for (int i = 0; i < kill_count; i++) printf("%s%lu", i ? "," : "", (unsigned long)killed[i]);
  fputs("]", stdout); result = ok ? 0 : 1;
cleanup:
  if (!CloseHandle(job)) scope_clean = false; // Только собственный Job.
  for (int i = 0; i < 3; i++) if (owned[i].handle) {
    if (WaitForSingleObject(owned[i].handle, 2000) != WAIT_OBJECT_0) scope_clean = false;
    CloseHandle(owned[i].handle);
  }
  for (int i = 0; i < 16; i++) if (snapshots[i]) free(snapshots[i]);
  if (result != 125) printf(",\"scope_clean\":%s}\n", scope_clean ? "true" : "false");
  if (!scope_clean) result = 125;
  if (result == 125) fprintf(stderr, "fixture setup failed, Windows error %lu\n", (unsigned long)GetLastError());
  return result;
}
