# Notes

The long version. Everything here used to live in the README, which now has
better things to do (see the shelf). This is the file to read when a machine
starts behaving oddly and you want to know whether it was on purpose.

Most of it is also in the module comments, next to the code it explains — that
is the copy that will stay honest, since it is the one you trip over while
editing. This file is the map.

## Platform notes

Runs on Emacs 30+ on three machines: a NixOS desktop, a locked-down console
appliance and an Android phone (the last two below).

Path constants live in `joe-core.el` (`joe/notes-dir`, `joe/texts-dir`,
`joe/noises-dir`) rather than being hardcoded per module. Their fallback
branch is `/mnt/d/...`, a leftover from a decommissioned host that no current
machine uses; every live machine matches an earlier branch of the `cond`.

A Windows host was retired in Aug 2026, and its configuration went with it:
the `.cmd` wrappers that bridged notmuch/mbsync/msmtp to WSL, the explicit
`exec-path` and `HOME` handling, the `w32-pipe-*` tuning, the PowerShell timer
sound, ghostel, the msys64 epdfinfo and pdftotext paths, the 8.3 short-name
fallback in `joe/--native-path`, the case-insensitive branch of
`joe/--dedup-paths`, and the two WSL path-translation helpers (which nothing
called). Two things it left behind are deliberate, and both are noted where
they live: `joe/--citekey-unsafe-rx` still strips the full hostile set,
because the library syncs to `/sdcard` on Android; and the daemon-exit logger
in `joe-core.el` is kept because it costs nothing until something dies.

## The console appliance (`x270`)

A ThinkPad X270 running NixOS as a non-graphical, locked-down Emacs box.
`early-init.el` defines:

```elisp
(defconst joe/console-appliance-p (string= (system-name) "x270") ...)
```

Everything appliance-specific is gated on that constant, so **none of it
changes behaviour on any other machine**. What it turns off, and why:

| Gated off | Reason |
|---|---|
| `compile-angel` | Calls `native-compile` explicitly, ignoring `native-comp-jit-compilation`. Its `.eln` output can't be `dlopen`'d from a `noexec` `/home`, and its byte-compilation produced a broken magit `.elc`. |
| `native-comp` JIT + trampolines | Same `noexec` constraint: `.elc` is interpreted and fine, `.eln` is `mmap`'d executable and is not. |
| `nerd-icons*` | The console (kmscon, built without pango) has no font fallback, so unpatched fonts render replacement boxes. |
| `fontaine` | Font faces are a window-system concept; the console font is set system-wide. |
| `auto-dark` | No OS appearance setting to poll on a TTY. `modus-operandi` is loaded explicitly instead. |
| `pulsar` | No sub-cell rendering in a TTY, so the pulse is a full-width bar rather than a fade. |
| `pdf-tools`, `saveplace-pdf-view` | Graphical, and native modules can't be built or loaded here. |

And what it turns **on** or adjusts:

- `corfu-terminal` — Corfu's popup needs child frames, which are GUI-only
  until Emacs 31; without this the completion popup renders nothing.
- Embark rebound from `C-.` / `C-;` / `C-,` to `C-c .` / `C-c ;` / `C-c ,` —
  the originals are unreachable in a terminal.
- Mode line: modus substitutes an `:underline` for the `:box` border it can't
  draw in a TTY, and `mode-line-end-spaces` defaults to `"-%-"` (a row of
  dashes) on non-graphical displays. Both are stripped.
- Theme background: Emacs emits SGR 39;49 for `default` on a TTY — i.e. defers
  to the terminal — so `bg-main`/`fg-main` are pushed onto the `default` face
  from `modus-themes-after-load-theme-hook`. Without this, `<f8>` appears to do
  nothing but recolour the mode line.

Note that anything hooked to theme loading must re-apply on
`modus-themes-after-load-theme-hook`: modus reapplies its own faces on every
theme load, so a one-shot `set-face-attribute` is silently undone by `<f8>`.

The system side (LUKS, the five sandboxing barriers, kmscon, Syncthing,
key bindings) lives in that machine's `/etc/nixos/configuration.nix`, not here.

## Android

A phone, running the native Android port (the APK — not a terminal Emacs under
Termux). Gated on:

```elisp
(defconst joe/android-p (eq system-type 'android) ...)   ; early-init.el
```

Scope is deliberately two things: **reading and editing org, and reading the
web in eww.** `init.el` branches on `joe/android-p` and loads only
`joe-android`, `joe-core`, `joe-completion`, `joe-org-notes`, `joe-eww`,
`joe-ui` and `joe-files`. The rest is not merely unwanted, it cannot work:
`joe-research` needs pdf-tools (`epdfinfo` is a C program and there is no
compiler), `joe-mail` needs the notmuch CLI and a local maildir, `joe-media`
shells out to mpv, `joe-python` needs a Python, `joe-tools` loads bluetooth
which `require`s dbus. Loading them would spend a phone's startup downloading
packages that then fail at first use.

`joe-android.el` is required **eagerly and first**, unlike every other module,
because it turns on the tool bar, menu bar and modifier bar — which on a
touchscreen are not decoration but the only way to press Ctrl at all.

### Installing

Step by step, with the checks: **[ANDROID.md](ANDROID.md)**. The short
version follows.

Use a build from the `termux/` subdirectory of
<https://sourceforge.net/projects/android-ports-for-gnu-emacs/files/>: those
set `sharedUserId` to `com.termux`, which is what lets Emacs execute Termux's
binaries. Without it there is no `git`, `rg`, `am` or even `ls` on
`exec-path` — the APK ships no userland of its own. Install **Termux first,
then Emacs**; the API-level number in the APK filename is the minimum Android
version, and the CPU architecture must match exactly. 30.2 is the safe choice;
the APK builds lag the tarball releases considerably.

The Termux APK bundled in that directory is from June 2024 and its signature
is no longer valid on Android 15. Two ways round it: re-sign the current
upstream Termux with Emacs's own published keystore
(`pkg install apksigner`, then `apksigner sign --ks emacs.keystore termux.apk`
using the keystore from `java/emacs.keystore` in the Emacs tree), or sign both
APKs with a personal key after adding `android:sharedUserId` to Emacs's
manifest with apktool.

Avoid the F-Droid build: it is an old February snapshot with no GnuTLS, no
image libraries and no tree-sitter, and it uses a different signing key, so
you cannot upgrade from it — you must uninstall first.

### Text conversion: the one thing that will confuse you

Android input methods do not send key events. They call Emacs's buffer-editing
primitives directly — a mechanism called *text conversion* — and Emacs infers
what electric-pair and auto-fill should have done by analysing the edit after
the fact.

So **anything that reads raw key events cannot see your typing while the IME is
driving**: evil, meow, and org's own speed keys. The keystrokes arrive as
inserted text instead of as commands. Nothing is misconfigured when that
happens; it is the design.

`joe/android-toggle-text-conversion` (`C-c A t`, and a tool bar button) flips
it. With text conversion off the IME sends real key events, so
`org-use-speed-commands` works — `n`/`p`/`f`/`b`/`t`/`c` as bare letters at the
start of a headline, which is the single largest ergonomic win available on
this machine. The cost is predictive and swipe typing, which is why it is a
toggle and not a setting.

It calls `set-text-conversion-style`, **not** `setq-local`. That function's
whole job over a plain assignment is what it does afterwards: it forces the
input method in any window showing the buffer to stop and restart itself. A
bare `setq-local` only changes what redisplay will do the next time it
reconsiders the buffer, which for a toggle you just pressed is not now — the
IME carries on swallowing keys and the command looks broken. The previous
value is saved and restored rather than a constant written back, because there
is no single correct "on" value: `text-mode` sets `t`, and the minibuffer
wants `action`.

Two related IME bugs, both documented upstream as IME bugs rather than Emacs
bugs: point jumping to the start of the buffer after typing an opening paren,
and fundamental-mode/Customize buffers going haywire in IMEs that do not
implement `TYPE_NULL`. The fix for both is a better IME — the port's
maintainer uses AnySoftKeyboard; Unexpected Keyboard is the one most often
recommended in write-ups.

### What is configured, and why

| Setting | Reason |
|---|---|
| `modifier-bar-mode` | A second tool bar row applying Ctrl/Meta/Super/Shift to the next event. The only way to type a modified sequence on glass. |
| `tool-bar-mode`, `menu-bar-mode` | Not chrome here — `M-x` lives at Edit → Execute Command. `early-init.el` stops suppressing them on Android. |
| `tool-bar-position` = `bottom` | Buttons under the thumbs. Implemented on non-GTK systems at an Android user's request. |
| `touch-screen-display-keyboard` = `t` | Emacs hides the on-screen keyboard in read-only buffers to save space. That is what makes eww's URL prompt, dired and the agenda feel broken. |
| `tool-bar-button-margin` = 12 | FAQ 22: button margins do not scale with display density, so buttons render undersized on a high-DPI phone. |
| `context-menu-mode` | Long-press becomes a real context menu. |
| `server-start` | Puts Emacs in Android's "open with" dialog for text files. |
| `initial-buffer-choice` | Lands on Dired in the notes directory rather than a scratch buffer. |
| `ls-lisp-dirs-first` | Emacs already lists directories with ls-lisp on Android — `ls-lisp-use-insert-directory-program` defaults to nil for `android` just as for `windows-nt`, so dired needs no `ls` and works without Termux. What is lost is `--group-directories-first`: ls-lisp sanitises away long GNU options with no short equivalent, so it is silently dropped (not misparsed). `ls-lisp-dirs-first` is the native equivalent. `dired-listing-switches` carries the Android branch in `joe-files.el`, which is its one canonical assignment — setting it from `joe-android.el` too would be a race, since `joe-files` loads on a later idle timer. |
| Six tool bar buttons | M-x, eww, agenda, capture, text-conversion toggle, clipboard→eww. |
| `touch-screen-word-select`, `-extend-selection`, `-preview-select` | All three default to nil and all three are worth having. Character-granularity dragging with a fingertip is a losing game: word-select makes a long-press drag take whole words, extend-selection lets a tap on point or mark resume a region, and preview-select shows the selection in the echo area. |
| `repeat-mode` | Built in since Emacs 28 and worth more here than on a desktop. After `C-x o`, a bare `o` switches windows again; every repeat is one modifier-bar round trip that does not happen. |
| `shr-use-fonts` = nil, `shr-max-image-proportion` 0.4 | Phone-width reflow, and images that do not push the text below the fold. |
| `eww-download-directory` = `/sdcard/Download/` | `~/Downloads` is Emacs's private app directory; nothing else on the phone can see a file put there. |
| Default face height 140 | Fontaine is skipped (Aporetic is not installed), so this is set directly — and re-applied on `enable-theme-functions`, since `<f8>` reloads a theme. |

Turned **off**: `compile-angel` (minutes of phone CPU; the APK has no
libgccjit anyway), the forced installs of notmuch/pdf-tools/jinx in
`joe-core.el` (none can work — no compiler), `fontaine`, `ultra-scroll`
(the port does its own precision scrolling from touch events),
`mouse-autoselect-window` (touch synthesises mouse motion, so a thumb drag
across a window boundary would switch windows), the nerd-icons packages, and
openwith's mpv associations.

### Two things that need a device test first

Both are off by default, and both are off for the same kind of reason: the
Emacs half works and the Android half is unverified.

**`joe/android-auto-dark`** — following the system light/dark setting. An
earlier revision of these notes said auto-dark has no detection mechanism on
Android. That was wrong. It has one: the `termux` method shells out to
`cmd uimode night`, which is a plain Android command, not termux-api. What it
will not do is *choose* that method, because its detector gates the branch on
`(and (eq system-type 'gnu/linux) (member 'dbus features) ...)` — which
describes a terminal Emacs running *inside* Termux, not this APK, where
`system-type` is `android`. So it falls through to "Could not determine a
viable theme detection mechanism!". `auto-dark-detection-method` is a
defcustom that bypasses the detector when set, so naming the method is the
entire fix. Before switching this on, check on the device that

```
M-: (shell-command-to-string "cmd uimode night")
```

answers `Night mode: yes` or `no` — `cmd` lives in `/system/bin` and some of
its subcommands want a shell UID. The poll is a subprocess, so `joe-ui.el`
drops the interval to 60s here; the desktop's 5s would be a battery decision
rather than a cosmetic one.

**`joe/android-notifications`** — agenda alerts in the notification shade.
The port defines `android-notifications-notify` in C (`src/androidselect.c`),
so this needs no Termux, no termux-api and no D-Bus, and a notification can
carry action buttons that call back into Emacs. `joe-android.el` defines an
`alert` style that forwards to it and points org-alert at that style. The
limit is not Emacs: a timer only fires while the process is alive, and Android
doze suspends backgrounded apps. Exempt Emacs from battery optimisation, then
confirm alerts still arrive before relying on it.

`joe/android-bind-volume-keys` is **on by default**, because it costs almost
nothing. Emacs on Android already reserves *both* volume keys — that is the
default of `android-pass-multimedia-buttons-to-system`, and it is how the port
gives you a `C-g` without a keyboard — so the rocker has already stopped
adjusting the volume the moment Emacs has focus, bound or not. (The manual's
own suggestion for changing the volume is to pull down the notification shade,
which takes focus away from Emacs.) It binds volume-up to
`joe/android-run-dwim`: mode-dispatching, `C-c C-c` in org, reload in eww,
visit in dired. Volume-*down* is never bound — pressed in rapid succession it
is the quit gesture, and it is the default of `android-quit-keycode`. Set the
variable to nil to leave both keys alone.

### Storage — the part that bites

Android exposes three storage classes, and only one of them is any good:

1. **Emacs's app directory** (`/data/data/org.gnu.emacs/files`) — its Unix
   home. Private to Emacs.
2. **External storage** (`/sdcard`) — needs a permission (Settings → Special
   App Access on Android 11+). Contrary to what circulates, the Termux variant
   of the APK is *not* required for this; the shared UID only means the two
   apps inherit each other's grants.
3. **Storage Access Framework** (`/content/...`) — Nextcloud, Syncthing
   folders. **Avoid.** It is served entirely by Emacs's own file primitives, so
   a subprocess started there silently gets Emacs's home as its working
   directory instead — which is why ripgrep and git return nothing on such a
   folder. It is also extremely slow; agenda builds of several minutes have
   been reported. The same applies to `/assets`.

So `joe/notes-dir` and friends resolve to `/data/data/com.termux/files/home/Sync/...`
on Android (falling back to Emacs's own home if Termux is absent). That is an
ordinary Unix directory both Emacs and its subprocesses can read. Keep it in
step with the desktops by running Syncthing *inside Termux*:

```sh
pkg install syncthing termux-services

SV_DIR="$PREFIX/var/service/syncthing"
mkdir -p "$SV_DIR/log"
cat > "$SV_DIR/run" <<EOF
#!$PREFIX/bin/sh
exec syncthing --no-browser --gui-address=127.0.0.1:8385 2>&1
EOF
chmod +x "$SV_DIR/run"
ln -sf "$PREFIX/share/termux-services/svlogger" "$SV_DIR/log/run"

echo 'source $PREFIX/etc/profile.d/start-services.sh' >> "$HOME/.bashrc"
source "$PREFIX/etc/profile.d/start-services.sh"
sv-enable syncthing && sv up syncthing && sv status syncthing
```

Port 8385 rather than the default 8384, which one author had trouble binding.

### Odds and ends

- **Quit / `C-g`**: press volume-down in rapid succession
  (`android-quit-keycode`).
- **Fonts**: at startup Emacs enumerates TrueType fonts in `/system/fonts`,
  `/product/fonts` and the `fonts` directory inside its home directory — so
  `~/fonts`. Put files directly in it; the manual does not promise a recursive
  search. Drop a Nerd Font in there and `joe/no-icon-font-p` in
  `early-init.el` can be set to nil to get the icon packages back. Ignore
  Options → Set Default Font, an X-era vestige listing fonts that are not
  present.
- **E-ink** (Boox etc.): Android reports no monochrome visual class, so
  font-lock contrast is poor. Set the display depth to 2–8 for grayscale, 1
  for monochrome — but check the variable's name with `C-h v` first. The
  Emacs manual (emacs-30 branch *and* master) calls it
  `android-display-planes`; the port's own SourceForge FAQ calls it
  `android-display-depth`. The two disagree and only your build settles it.
- **Getting a URL out of Emacs**: `browse-url-secondary-browser-function` is
  set to `joe/android-browse-external`, a thin wrapper over the port's native
  `android-browse-url`. No Termux, and it handles URL-encoding and the
  `file://` → `content://` conversion that a hand-built `am` command line does
  not. The wrapper is load-bearing: `android-browse-url` takes
  `(URL &optional SEND)` where SEND non-nil means *share* rather than *open*,
  and `browse-url-secondary-browser-function` passes NEW-WINDOW as the second
  argument — binding the raw function would turn every new-window request into
  a share sheet. eww's `&` dispatches through that variable, so it keeps
  meaning what it documents.
- **Getting a URL in**: Android has no share-target integration for Emacs and
  no URL-scheme handler for org-protocol, so a link has to come across by
  hand. The port does wire Android's clipboard into Emacs's selection back
  end, though, so `joe/eww-open-clipboard` (`C-c A e`, and a tool bar button)
  turns copy-switch-yank-then-open into one tap.
- **Do not** set `LD_LIBRARY_PATH` for the Termux binaries. That advice is
  explicitly retracted by the port's README: Termux embeds its library paths
  in its executables and the variable causes name collisions and linking
  errors. `PATH` and `exec-path` only, which is what `early-init.el` does.

## Conventions worth knowing

**Capture templates guard on `org-capture`, never `org`.**
`org-capture-templates` is a defcustom in `org-capture.el`, so loading `org`
alone does not define it. Both places that add templates
(`joe-org-notes.el`, `joe-counting-house.el`) use
`(with-eval-after-load 'org-capture ...)`, with `joe-org-notes.el` doing the
`setq` and everything else appending via `add-to-list`. Ordering then follows
`init.el`'s require order rather than whichever feature loads first. Adding a
template elsewhere under a different guard reintroduces an ordering bug that
will look like a random `void-variable` or a silently missing template.

**Deferred loading is by idle timer, not autoload.** `init.el` requires
`joe-core` and `joe-completion` eagerly and everything else on 0.1s/0.5s/1s
idle timers. A consequence worth remembering when debugging: immediately after
a daemon restart, a module may genuinely not be loaded yet, so
`emacsclient -e` can report state that looks wrong but isn't.
