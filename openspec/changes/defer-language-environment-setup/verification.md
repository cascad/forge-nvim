# Verification — 2026-11-19

Implemented: deferred Core installation; current embedded native frontend;
installed `--prepare-language` with shared SDK/tool settings and strict tools
postconditions; passive first-file notice and persistent `Space l S` hub.
`ForgeSdk` remains directly accessible. User/project prompt settings, Later,
reset/inheritance, manual SDK/tool paths, Mason, logs and explicit SDK apply
are exposed through existing native UIs/APIs. No SDK downloads on file open.

## Affected regression

Windows base packet `.tests/batches/1795081125538079100` and Ubuntu native-stand
packet `.tests/ubuntu/batches/1795081543259253662` exercised SDK actions/settings,
Nextest, eager/check compatibility, Go build policy, IDE tool version policy,
and new language preparation. The new installer tests use real Core/frontend/
native Node with a **controlled tools stage**, not actual language acceptance.
They cover deferred masks, embedded payload hashes, ready marker ownership,
project selection, unchanged kit/settings, failed stage and invalid result.

New/affected UI and readiness checks were repeated only after concrete failures
or added coverage. Latest successful evidence:

- Windows `.tests/cold-install/final-windows.txt`: language UI E2E and unit/trace.
- Ubuntu `.tests/cold-install/final-linux.txt`: same UI and unit/trace.
- `.tests/cold-install/affected-windows-final.txt`,
  `.tests/cold-install/affected-linux-native-tmp.txt`: UI/readiness PASS.
- `.tests/cold-install/cancel-windows.txt`, `cancel-linux.txt`: installed native
  preparation cancellation returns130, preserves kit and writes no ready result.
- `.tests/cold-install/provider-archive-regression-final.txt`: native executable/
  local curl fixture/GNU tar test accepts Unicode and rejects traversal before
  extraction; no network or host SDK mutation.

UI E2E uses the actual editor and Telescope: single passive notice, edit/save,
hub/scopes, Later without a settings file, project/user override/reset,
metadata preservation, fresh-process persistent settings, malformed settings,
unavailable maintenance backend and real native async failure/continued editing.
Existing Python/Node native menu/restart workflows and pre-Mason SDK paths also
pass. Source checkout absence of an embedded frontend is actionable, not a
request to compile/install it in the background.
The native async integration case explicitly requires FORGE_INSTALL_UI_BINARY;
source-only UI runs without this input report one SKIP with preparation guidance.
Acceptance supplied both source-matched native frontends and passed all4 cases
per OS. No E2E invocation builds or downloads a frontend implicitly.

Original failures remain in the earlier packets. Long failure notification
caused hit-enter and was shortened; full paths stay in Logs. First empty SQL
buffer could lack filetype; passive detection now also uses native
`vim.filetype.match`, without changing the buffer or invoking SDKs. The legacy
Mason fixture had a v2 source in a v1 receipt; its native schema was corrected.
Readiness fixture now supplies the required pre-Mason local build policy.
Unversioned receipts without bin exports are explicitly rejected.
The first local archive control used an incomplete copied Go SDK and failed its
native probe; it was corrected to an explicitly controlled native executable.
Real official SDK installation remains a separate cold-provider check.

Ubuntu input preparation initially stopped before editor startup on stale
Neogit/neotest-rust backports. A private overlay was prepared by the canonical
script; the pinned lock and base image were not altered. Two owned batches were
stopped after finding native stands/editor profiles on the Windows bind mount;
successful repeats use an owned native tmp directory. These are stand failures,
not product PASS. Exact process trees/reasons are recorded in
`.tests/ubuntu/deferred-aborted-{batch,e2e}.json`.

## Real cold evidence

`.tests/cold-install/1795081713824789000` records a pinned Ubuntu24.04 baseline
without Git/Neovim/SDKs/fride state. Root entry/current native frontend delivered
real Core/Terminal archives. Git installed, language SDK menus were deferred.
Default then failed its real font probe because `libX11-xcb.so.1` is absent.
No ready marker or successful Default is claimed. Original source/archive/UI
inputs and failure logs are preserved; renderer's generic Core label is not the
underlying cause. This is the open **IDE-142** OS-dependency decision.

Official SDK providers were then tested independently in a separate ordinary
test HOME, using the already verified Core executable. This does **not** turn
the failed Default into a successful cold installation.

- Initial Go1.27.4 failed on GNU tar's octal quoting of the official Unicode
  test filename `Þfoo.go`. The worker now requests literal names. Actual
  SHA-verified official Go1.27.4 install then passed.
- New official rustup installed Rust1.100.0, rustfmt1.11.0 and rust-src. Shared
  read-only Rust component inspection reports ready.
- Repeat reused versions and selected executables, with matching SHA256.
  Default `/root` still has no Cargo/Rustup homes; no host SDKs were installed.
- Rustup warns that `cc` is absent. Actual Rust compile/run is a separate
  OS-toolchain prerequisite, not a PASS inferred from a compiler version.

Worker reports are `provider-go-after.json`, `provider-rust.json`,
`native-rust-components.json`, `provider-repeat.json` in that cold directory;
logs are `.tests/cold-install/provider-*.txt`. Original source contains the
pre-fix worker; the corrected worker was supplied as a separately hashed
candidate for the affected repeat. No historical evidence was overwritten.

## Remaining

Cold installed Core→first Go/Rust→prepare→LSP/format/run/debug/tests→repeat
remains open until OS dependencies are resolved. Full regression across all
unrelated features was not repeated; this block ran its affected packet and
unit/trace once, with failed/affected repeats only. Native macOS, Windows WSL,
Terminal GUI and public artifact publication remain separate genuine gates.
