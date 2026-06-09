# dotemacs

Personal Emacs configuration.

## Structure

```
.
├── init.el           # Entry point
├── early-init.el     # Early init (GC, UI suppression)
└── lisp/
    ├── joe-core.el       # Package management, core settings
    ├── joe-completion.el # Vertico, Corfu, Consult, Embark
    ├── joe-files.el      # Dired, ibuffer, file management
    ├── joe-mail.el       # Notmuch, mu4e, msmtp
    ├── joe-org-notes.el  # Org, Denote, org-ql
    ├── joe-research.el   # Citar, PDF tools, bibliography
    ├── joe-tools.el      # Magit, rg, shells (PowerShell/eshell), eww, elfeed, pass
    └── joe-ui.el         # Themes, modeline, fonts, UI
```

## Platform notes

Config runs on both Linux/WSL and native Windows Emacs (30+).
On Windows, Unix tools (notmuch, mbsync, msmtp) are
called through `.cmd` wrapper scripts in `C:/Users/Joe/bin` that
delegate to WSL via `wsl.exe`.
