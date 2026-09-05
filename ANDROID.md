# Setting this up on Android

A procedure, in order, with a check after each step that can fail quietly.
Budget an hour, most of it waiting for downloads.

What you get at the end: Org notes and eww, on a touchscreen, with no
keyboard. What you deliberately do not get: magit, mail, the bibliography,
agent-shell. `init.el` does not load those modules on Android — see
[NOTES.md](NOTES.md) for why each one cannot work there.

---

## 0. Before you start

- **A phone on Android 7.0 or later.** Termux needs it.
- **Know your CPU architecture.** Almost certainly `arm64-v8a`. Getting this
  wrong is not a clean failure: an x86 package on x86_64 compiles fine and
  then breaks subprocess execution.
- **Back up anything already in Emacs's home.** Step 2 may require you to
  uninstall an existing Emacs, and that wipes its data directory.

---

## 1. Install Termux — *first*, before Emacs

Order matters. Android assigns the shared user ID at install time.

Install Termux **from F-Droid**, not Google Play. The Play version is
unmaintained.

### The signature problem

Emacs and Termux must be signed with the same key for the shared user ID to
work. That is what lets Emacs run `git`, `rg` and the rest — without it the
APK has no userland at all.

The Termux APK bundled in the SourceForge `termux/` directory dates from June
2024 and its signature is no longer valid on Android 15. Three ways out:

- **Re-sign current Termux yourself.** In Termux: `pkg install apksigner`.
  Download the current release APK from
  <https://github.com/termux/termux-app/releases> and the Emacs keystore from
  `java/emacs.keystore` in the Emacs tree, then:

  ```sh
  apksigner sign --ks emacs.keystore termux.apk
  ```

  Uninstall the F-Droid Termux and install the re-signed one.
- **Use a prebuilt** from
  <https://github.com/johanwiden/termux-for-android-emacs>.
- **Sign both APKs with your own key** — avoids trusting GNU's published
  signing key, but every Termux add-on you install later must also be
  re-signed.

> **Check:** Termux opens and `echo $PREFIX` prints
> `/data/data/com.termux/files/usr`.

---

## 2. Install Emacs

From the **`termux/` subdirectory** of
<https://sourceforge.net/projects/android-ports-for-gnu-emacs/files/> — those
builds set `sharedUserId` to `com.termux`. A build from the top-level
directory will install and run and then have no `git`.

Do **not** use the F-Droid Emacs: it is an old snapshot without GnuTLS, the
image libraries or tree-sitter, and it uses a different signing key, so you
cannot upgrade from it — you would have to uninstall first.

**Which file:** the number in the filename is the *minimum* Android version,
not the target. `-29-arm64-v8a` is Android 10+; `-35-arm64-v8a` is Android
15+. Take **30.2** unless you have a reason not to — the APK builds lag the
tarball releases considerably, and 31.0.50 has a reported focus bug in the
agenda that 30.2 does not.

> **Check:** Emacs starts. Then `M-x eshell` and run `which git`. If it prints
> a path under `/data/data/com.termux`, the shared UID is working. If it finds
> nothing, you have a non-`termux/` build or a signature mismatch — go back to
> step 1.
>
> To type `M-x` without a keyboard: **Edit → Execute Command** on the menu bar.

---

## 3. Termux packages

```sh
pkg update && pkg upgrade
pkg install git ripgrep openssh
```

`git` is what makes step 5 possible. `ripgrep` backs `consult-ripgrep` and
`deadgrep`.

---

## 4. Grant storage access

Android 11+: **Settings → Apps → Special app access → All files access** →
enable for Emacs (or Termux; the shared UID means either grant serves both).
Pre-11 it is under App Info → Permissions → Storage.

This is *not* the same thing as the Termux variant of the APK, contrary to
what circulates. It is an ordinary permission.

You need it for `/sdcard/Download`, which is where eww saves files.

---

## 5. Put the configuration in place

First find Emacs's home, rather than assuming it:

```
M-: (expand-file-name "~")
```

It should print `/data/data/org.gnu.emacs/files`. **Use what it actually
prints** in the next command — the package name can differ between builds.

Then, in Termux (which can write there, because of the shared UID):

```sh
git clone https://github.com/jhp-1/.emacs.d \
    /data/data/org.gnu.emacs/files/.emacs.d
```

> **Check:** back in Emacs, `C-x C-f ~/.emacs.d/init.el` opens the file.

---

## 6. First launch

Restart Emacs. It will install about thirty packages from MELPA. On a phone
this takes **several minutes** and needs a live connection. If it stalls or
errors, run `M-x package-refresh-contents` and restart.

Two things that are *not* going wrong while you wait:

- `compile-angel` is disabled on Android on purpose — byte-compiling every
  library on load is minutes of phone CPU for a fraction of a second saved.
- The nerd-icons packages are skipped, so the interface has no glyph icons.
  That is deliberate; see step 9 if you want them.

> **Check:** the tool bar sits at the **bottom** of the screen with six
> buttons, and a second row of modifier buttons (Ctrl, Meta, Shift…) sits
> beside it. If the tool bar is at the top or missing, `early-init.el` did not
> load — confirm the clone landed at `~/.emacs.d`, not `~/.emacs.d/.emacs.d`.

---

## 7. Notes and Syncthing

The configuration expects notes at:

```
/data/data/com.termux/files/home/Sync/Notes
```

**Inside Termux's home, deliberately.** Not a Storage Access Framework folder
under `/content`: those are served entirely by Emacs's own file primitives, so
a subprocess started there silently gets Emacs's home as its working directory
instead — which is why ripgrep and git return nothing on them. They are also
very slow; agenda builds of several minutes have been reported.

Run Syncthing *inside Termux*, so the files sit somewhere subprocesses can
reach:

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
If `sv status` says it cannot change to the service directory, restart Termux
and retry. Then open <http://127.0.0.1:8385> and pair the device with your
desktop, sharing the folder into `~/Sync/Notes`.

> **Check:** in Emacs, `M-: joe/notes-dir` prints the Termux path (not a path
> under `org.gnu.emacs`), and `C-c a` builds an agenda with your real items in
> it. A path under `org.gnu.emacs` means Termux's home did not exist when
> Emacs started — restart Emacs after Syncthing has created the directory.

---

## 8. A keyboard worth using

The stock Android keyboard is workable but has no Tab, no Escape and no easy
punctuation. Two known-good choices:

- **Unexpected Keyboard** (F-Droid or Play) — most recommended in write-ups.
  Swipe off a key for its alternate rather than switching layers. Turn on the
  number row, and enable the Alt key under "Add keys to the keyboard".
- **AnySoftKeyboard** — what the port's own maintainer uses.

This matters more than it sounds for one specific reason: FAQ 12 in the port's
README notes that input methods which do not implement `TYPE_NULL` misbehave
in buffers where text conversion is off — which is every read-only buffer,
including dired and eww. A bad IME makes those feel broken.

---

## 9. Optional polish

**Font size.** `joe/android-font-height` is 140 (14pt). Change it with
`M-x set-variable`, or edit `lisp/joe-android.el`.

**Fonts.** Emacs searches `/system/fonts`, `/product/fonts` and the `fonts`
directory inside its own home — so `~/fonts`. Put `.ttf` files directly in
it. Ignore Options → Set Default Font: it is an X-era leftover that lists
fonts which are not present.

**Icons.** Drop a Nerd Font into `~/fonts`, then set `joe/no-icon-font-p` to
nil in `early-init.el` to get the icon packages back.

**e-ink** (Boox and similar): Android reports no monochrome visual class, so
font-lock contrast is poor. Set the display depth to 2–8 for greyscale, 1 for
monochrome — but check the variable's name with `C-h v` first. The Emacs
manual calls it `android-display-planes`; the port's own FAQ calls it
`android-display-depth`. They disagree and only your build settles it.

---

## 10. The two features that need a device test

Both are off by default. In each case the Emacs side is sound and the Android
side is what is unverified.

### System light/dark theme

Check first, in Emacs:

```
M-: (shell-command-to-string "cmd uimode night")
```

It must answer `Night mode: yes` or `Night mode: no`. `cmd` lives in
`/system/bin` and some of its subcommands want a shell UID, so this can come
back empty.

If it answers, set `joe/android-auto-dark` to `t` in `lisp/joe-android.el` and
restart. The theme will then follow the system setting, polled once a minute.

### Agenda notifications

Emacs on this port has a native `android-notifications-notify`, so this needs
no Termux, no termux-api and no D-Bus. The constraint is Android's process
management: a timer only fires while Emacs is alive, and doze suspends
backgrounded apps.

1. **Settings → Apps → Emacs → Battery → Unrestricted.**
2. Set `joe/android-notifications` to `t` and restart. It installs `org-alert`
   on first run, two seconds after startup.
3. Schedule something a few minutes out, background Emacs, and wait.

If nothing arrives, the timer was suspended — that is a phone problem, not a
configuration one, and there is no fix inside Emacs.

---

## 11. Using it

| Want | Do |
|---|---|
| `C-g` / quit | Volume-down, three times, fast |
| `M-x` | Tool bar button, or Edit → Execute Command |
| Ctrl, Meta, Shift | The modifier bar — tap, then tap the key |
| Web | Tool bar, or `C-c e` |
| Open a copied link | Tool bar "Clip->eww", or `C-c A e` |
| Agenda / capture | Tool bar |
| Org speed keys | Tool bar "Speed keys", or `C-c A t` |
| Select a word | Long-press and drag — it snaps to words |
| Repeat a command | e.g. `C-x o`, then bare `o`, `o`, `o` |

**The one thing that will confuse you.** Android input methods do not send key
events; they call Emacs's editing primitives directly. So in an *editable*
buffer, single-letter commands — org speed keys especially — arrive as typed
text instead of running. Nothing is misconfigured; that is the design. The
"Speed keys" tool bar button toggles it off for a burst of navigation and back
on for writing.

---

## 12. When something is wrong

| Symptom | Cause |
|---|---|
| No `git`, no `rg`, no `ls` | Not a `termux/` build, or signatures do not match. Step 1. |
| Tool bar at the top, or absent | `early-init.el` did not load. Check the clone path. |
| Agenda is empty | `joe/notes-dir` points at Emacs's home because Termux's home did not exist at startup. Restart Emacs. |
| Typing in dired or eww misbehaves | Your IME does not implement `TYPE_NULL`. Step 8. |
| Ripgrep finds nothing | The files are under `/content`. Move them into Termux's home. Step 7. |
| Buttons too small to hit | Raise `tool-bar-button-margin` — margins do not scale with display density. |
| Volume keys do not change volume | Expected: Emacs reserves them, which is how the quit gesture works. Set `joe/android-bind-volume-keys` to nil to release volume-up. |
