# dotemacs

Personal Emacs configuration.

## Structure

```
.
├── init.el           # Entry point; requires joe-core + joe-completion
│                     # eagerly, the rest on idle timers
├── early-init.el     # GC, UI suppression, joe/console-appliance-p
└── lisp/
    ├── joe-core.el           # Package management, core settings, path constants
    ├── joe-completion.el     # Vertico, Corfu, Cape, Consult, Embark
    ├── joe-files.el          # Dired, ibuffer, file management
    ├── joe-ui.el             # Themes, modeline, fonts, UI
    ├── joe-org-notes.el      # Org, Denote, org-ql
    ├── joe-research.el       # Citar, PDF tools, bibliography
    ├── joe-counting-house.el # Counting House capture, menu, garden walk
    ├── joe-career.el         # Career roadmap: capture, agenda, applications
    ├── joe-python.el         # Python / org-babel literate analysis
    ├── joe-elfeed.el         # Elfeed feeds + Karl-Voit-style tag vocabulary
    ├── joe-mail.el           # Notmuch, mu4e, msmtp
    ├── joe-media.el          # Ambient noise playback via mpv
    └── joe-tools.el          # Magit, rg, shells (PowerShell/eshell), eww, tmr
```

## Platform notes

Runs on native Windows Emacs (30+), Linux/WSL, and a locked-down console
appliance (see below).

On Windows, Unix tools (notmuch, mbsync, msmtp) are called through `.cmd`
wrapper scripts in `C:/Users/Joe/bin` that delegate to WSL via `wsl.exe`.

Path constants live in `joe-core.el` (`joe/notes-dir`, `joe/texts-dir`,
`joe/noises-dir`) rather than being hardcoded per module. Note that the
non-Windows branch historically assumed WSL (`/mnt/d/...`), which is not
correct on bare Linux — hence the appliance branch below.

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
| `ghostel` | Windows-only (powershell.exe, a native `.so`). Wrapped in `when` rather than `:if`, because use-package processes `:ensure` *before* `:if`. |

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
