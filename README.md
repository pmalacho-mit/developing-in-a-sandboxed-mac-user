# sandboxed-mac-user

Run macOS Screen Sharing between two user accounts on **one physical Mac** (a `primary` account you work in and a `sandbox` you want to view/control), with app windows in the sandbox **auto-sizing to fill the Screen Sharing window** as you resize it.

macOS resists both halves of this: it blocks sharing your own machine's screen, and its window-matching feature (Dynamic Resolution) is unavailable in this configuration. This repo works around both.

## How it works

1. Both accounts stay logged in via Fast User Switching.
2. `primary` connects to the sandbox session over Screen Sharing, **tunneled through SSH** to defeat the same-machine block.
3. A **publisher** script in `primary` reports the live size of the Screen Sharing window into a shared file; a **watcher** script in `sandbox` reads it and resizes the target app windows to match. This is the manual _(clunky, but workable)_ replacement for Dynamic Resolution.

## Prerequisites

- Two accounts: `primary` (admin) and `sandbox` (standard).
- The scripts in this repo: `publisher.sh`, `watcher.sh`.

---

## 1. System setup

All under **System Settings → General → Sharing** unless noted.

**Fast User Switching** — enable it, and log into `sandbox` at least once so its session is live. You can only share a *running* session.

**Screen Sharing** — turn on, click the ⓘ, and set "**Allow access for: Only these users**" and add `sandbox` (in it addition to `Adminstrators`).

**Remote Login (SSH)** — turn on (required for the tunnel). Verify: `sudo systemsetup -getremotelogin`.
> If you click the ⓘ, leave **"Allow access for: Only these users" as `Administrators`** and **"Allow full disk access for remote users" OFF.** The tunnel only forwards a port; enabling this would hand every SSH session your protected data for no benefit.

---

## 2. Connect (the SSH-tunnel trick)

A direct `vnc://localhost` connection fails with **"You cannot control your own screen."** Routing VNC through an SSH tunnel makes the connection look non-local and bypasses the block.

```sh
ssh -fN -L 5901:localhost:5900 localhost
```

- `-fN` backgrounds the tunnel and starts no remote shell. This is required — see *Run scripts in the right session* below.
- Bonus: `-N` skips sourcing `.zshrc` over SSH, avoiding harmless `operation not permitted` errors when your shell config reads TCC-protected paths like `~/Downloads`.

Then point the **Screen Sharing** app at `vnc://localhost:5901` and authenticate as **sandbox**.

Stop the tunnel later with `pkill -f "5901:localhost:5900"`.

---

## 3. Best-quality configuration

In the Screen Sharing app:

- **View → Full Quality** (not Adaptive Quality). Adaptive blurs the image on "slow" links; over loopback that's pure loss. Biggest single quality win.
- **View → Turn Scaling Off** (Actual Size) for crisp 1:1 pixels. The resize scripts make this practical by keeping windows inside the viewport.
- **Hide the toolbar and tab bar** (View menu) — less chrome to account for.
- **Overlay scroll bars**: System Settings → Appearance → **Show scroll bars → "When scrolling"** (set in `primary`). Always-on scroll bars otherwise steal ~15px per axis from the visible area.
- **Disable pointer-edge auto-scroll**: Screen Sharing **Settings → Display → "Scroll the screen"** → pick the non-edge option so the view doesn't pan when the pointer nears an edge.

---

## 4. Why the resize scripts exist (the Dynamic Resolution dead end)

macOS has a feature that auto-matches the remote display to the Screen Sharing window — **Dynamic Resolution** — but it's unreachable here. Worth knowing why, so you don't burn time on it:

- It requires a **High Performance** connection with a **virtual display** (Apple Silicon + macOS Sonoma 14+).
- High Performance requires **UDP 5900–5902** between endpoints. An SSH tunnel forwards **TCP only**, so High Performance can't function through it.
- Connecting High Performance **directly** to `localhost` (no tunnel) still hits **"You cannot control your own screen"** — the block fires before any virtual display is created.

There is no same-machine path to Dynamic Resolution. The scripts reproduce its behavior by driving **window** size instead of **display** size — which touches neither the connection type nor the resolution, so nothing blocks it.

---

## 5. The resize scripts

**Architecture:** `publisher.sh` (primary) → shared file → `watcher.sh` (sandbox). Both accounts share the loopback interface and the filesystem, so a world-writable file at **`/Users/Shared/ss_size.txt`** is all the IPC you need — no second tunnel. The scripts assume **Actual Size (scaling off)** so window points map ~1:1 to sandbox points.

**publisher.sh — run in `primary`**
- Polls the Screen Sharing window size via one System Events `osascript` call (~0.1s). That call is unavoidable each tick (no cheaper way to detect a resize), so this side can't poll as fast as the watcher.
- Writes **atomically** (temp file + `mv`) and only on change, so the watcher never reads a half-written value.
- After each resize, **scrolls the viewport back to top-left.** This fixes a subtle bug: resizing the Screen Sharing window *from the top edge* makes its content scroll down, hiding the top of the sandbox screen where the pinned window lives.

**watcher.sh — run in `sandbox`**
- Fast poll (~0.05s) with a near-free idle path: a shell-builtin file read plus a string compare, **no subprocesses** until the value actually changes. The expensive window-resize `osascript` runs only on change.
- On change: parse width/height, **subtract `CHROME`** (the title-bar height) from the height, then for every **non-minimized** window of each target app: set position `{0,0}` → set size → set position `{0,0}` **again**. The double-pin matters — `set size` can shove a window off-screen, and re-pinning the corner afterward corrects that drift.
- **Target apps are parameterized** via arguments: `watcher.sh Code "Docker Desktop"`. Each app gets its own `osascript` call, so a closed app simply no-ops. Find exact process names with:
  ```sh
  osascript -e 'tell application "System Events" to get name of every process whose background only is false'
  ```

**Tuning**
- `CHROME` (~28): if a window spills past the bottom of the viewport, raise it; if there's a gap below, lower it. Hiding toolbar/tab bar keeps it a single constant.
- Give `sandbox` a display resolution at least as large as the biggest window you'll use, so windows have room to grow.

**Run scripts in the right session**
> ⚠️ Run each script from a **normal local Terminal in its own GUI session** — never inside the SSH tunnel shell. SSH sessions aren't part of the Aqua GUI session and **cannot reach System Events**; automation silently fails there. The tunnel is backgrounded with `-fN` precisely so it never occupies a terminal.

- `publisher.sh` → local Terminal in `primary`.
- `watcher.sh` → local Terminal in `sandbox` (open one inside the share).

---

## 6. Permissions (TCC) — nothing resizes without this

Both scripts drive **System Events**, which needs two permissions **per account** (grants in `primary` do nothing for `sandbox`, and vice-versa):

- **Automation** → Privacy & Security → Automation → enable **Terminal → System Events**. (Missing this is the `-1743 "Not authorized to send Apple events"` error.)
- **Accessibility** → Privacy & Security → Accessibility → enable **Terminal**. (Lets System Events actually move/resize windows.)

Two hard-won gotchas:

> **TCC prompts can't be approved over Screen Sharing.** macOS refuses to let security dialogs be approved through a remote/synthetic input path, so the prompt flashes and vanishes. **Switch to the account physically via Fast User Switching, approve there, then return to the share.** The grant sticks regardless of how you connect afterward. Apply this to every future permission grant in `sandbox`.

> **Stop the watcher loop before approving.** A running loop re-triggers the request every tick and strobes the prompt out of existence. Kill the loop, approve once, restart it.

If a prompt won't appear at all, reset and retry (per account): `tccutil reset AppleEvents`.

---

## 7. Workflow notes

- **Cycling windows:** `Cmd+\`` cycles only *non-minimized* windows, so it won't reach minimized ones. Use VS Code's **Switch Window** command (Command Palette → "Switch Window"; bind a key, e.g. `Ctrl+W`) which lists *all* windows including minimized and restores the one you pick.
- **After restoring/switching to a window, nudge the Screen Sharing window's size** to snap it to the viewport. The watcher only re-applies geometry on a size *change* (deliberate, to keep the idle path cheap), so a freshly un-minimized window isn't sized until then. If that's annoying, don't minimize — leave windows stacked at `{0,0}` and cycle with `Cmd+\``.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "You cannot control your own screen" | Direct same-machine VNC is blocked | Connect through the SSH tunnel (`vnc://localhost:5901`) |
| `ssh: connect to host ... port 22: Connection refused` | Remote Login isn't actually running | Enable Remote Login (toggle off/on); `sudo systemsetup -setremotelogin on` |
| Correct sandbox password rejected on connect | Account not in Screen Sharing's access list | Add sandbox under *Allow access for*, or use *All users* |
| `-1743 Not authorized to send Apple events` | Automation permission missing for that account | Grant Terminal → System Events in Privacy & Security → Automation (in that account) |
| Permission prompt appears then instantly vanishes | Polling loop re-triggering it, or approving over the share | Stop the loop; approve from the FUS console, not the share |
| Automation worked, then broke after starting the tunnel | Script is running inside the SSH session (no GUI session) | Background the tunnel (`-fN`); run scripts in local Terminals |
| Dynamic Resolution toolbar icon greyed out | Known quirk | Enable via System Settings → Displays instead — but it's moot here (next row) |
| Dynamic Resolution unavailable entirely | High Performance needs UDP (tunnel is TCP); direct localhost hits the self-screen block | Not solvable — use the resize scripts |
| Window edges clipped by toolbar / scroll bars | `CHROME` only covers the title bar | Hide toolbar + tab bar; set scroll bars to overlay |
| Window drifts off-screen after a resize | `set size` nudges a window when it would overflow | Re-pin position to `{0,0}` after setting size (double-pin) |
| Top of the screen disappears when resizing from the top edge | Viewport scrolls down on top-edge resize | Publisher re-scrolls viewport to top-left after each resize; or resize from the bottom-right |
| Blurry image | Adaptive Quality compression | View → Full Quality |
| `operation not permitted` sourcing `~/Downloads/...` over SSH | TCC protects Downloads; SSH lacks Full Disk Access | Harmless; move the file out of Downloads or guard with `[ -r file ]`. `-N` avoids it entirely |

---

Once permissions are granted and both scripts run in their sessions, resizing the Screen Sharing window resizes your sandbox app windows to match.
