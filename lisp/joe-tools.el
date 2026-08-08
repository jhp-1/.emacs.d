;;; joe-tools.el --- Shells, AI, and external tools configuration -*- lexical-binding: t; -*-

;;;; rg
;; wgrep is a required dependency of rg (>= 2.1.10); install it explicitly.
;; Pure Elisp — works fine on native Windows Emacs.
(use-package wgrep
  :ensure t
  :defer t)

(use-package rg
  :ensure t
  :defer t
  :bind
  ("C-c r" . rg-menu))

;;;; magit
;; llama is a required dependency of magit-section and magit (>= 1.0).
;; Pure Elisp — works fine on native Windows Emacs.
(use-package llama
  :ensure t)

(use-package magit
  :ensure t
  :defer t
  :bind
  ("C-x g" . magit-status)
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1))

;;;; ghostel
(declare-function ghostel "ghostel")

(defun ghostel-home ()
  "Open ghostel in the home directory."
  (interactive)
  (let ((default-directory "C:/Users/Joe/"))
    (ghostel)))

;; Windows-only: it shells out to powershell.exe, defaults to C:/Users/Joe/,
;; and ships a native ghostel-module.so, which on a noexec /home can be neither
;; built (no compiler) nor loaded.
;;
;; `:ensure nil' plus an imperative install, rather than `:ensure t' inside a
;; guard. Neither `:if' nor an enclosing `when' is enough: use-package resolves
;; :ensure while the form is being MACRO-EXPANDED, and the byte-compiler expands
;; the body of a `when' whether or not its condition can ever hold. So merely
;; byte-compiling this file on Linux reinstalled ghostel from MELPA — verified,
;; after a package-delete, in Aug 2026 — and its autoloads then warned about the
;; missing module for the rest of that session. Only compile-angel being
;; disabled here (see joe-core.el) kept that off the daemon's startup path.
;;
;; This mirrors the notmuch/pdf-tools/jinx handling in joe-core.el: decide
;; installation in plain Elisp, where a conditional means what it says, and
;; leave use-package to do configuration only.
;;
;; `:ensure nil' is the whole of the fix; the `when' only keeps the binding and
;; the powershell setting off non-Windows hosts, exactly as `:if' would. It is
;; specifically NOT load-bearing against the install — measured Aug 2026, `when'
;; and `:if' behave identically here, both silent on an ordinary load and both
;; emitting "Cannot load ghostel" when this file is byte-compiled.
;;
;; That leftover message is harmless and not worth chasing: use-package loads
;; each package at compile time to pick up its macros, inside a
;; `with-demoted-errors' precisely because it may be absent. It is a message
;; rather than a warning, the compile succeeds, and nothing gets installed.
(when (eq system-type 'windows-nt)
  (unless (package-installed-p 'ghostel)
    (unless package-archive-contents (package-refresh-contents))
    (package-install 'ghostel))
  (use-package ghostel
    :ensure nil
    :custom
    (ghostel-shell "powershell.exe")
    :bind
    ("C-c s" . ghostel-home)))

;;;; eshell
;; The Linux counterpart to ghostel above: same `C-c s' slot, since ghostel is
;; Windows-only and leaves the key free everywhere else. `C-c s' mirrors
;; `ghostel-home' and always starts at $HOME; `C-c S' starts in the current
;; buffer's directory, for jumping to a shell from a file you are editing.
;;
;; Sessions are named for their directory (`*eshell: ~/.emacs.d*'), so several
;; can coexist and `C-c s'/`C-c S' return to the right one instead of whichever
;; `*eshell*' happened to be first. The name carries the whole abbreviated path
;; rather than just the last component: basenames collide (every project has a
;; src/), and a collision here would silently hand you a shell sitting in a
;; different directory than the one you asked for.

;; Declared, not required, at top level: this only tells the byte-compiler the
;; symbol is special, so the `let' below is a dynamic binding rather than a
;; lexical one that eshell would never see. The matching runtime half is the
;; `require' in the function — without it the `let' would bind a symbol that is
;; still void, eshell.el's defcustom would then decline to initialise it
;; (`default-boundp' being non-nil), and unwinding the `let' would leave
;; `eshell-buffer-name' permanently void for every other caller.
(defvar eshell-buffer-name)

(defun joe/eshell-in (dir &optional new)
  "Open an Eshell in DIR, in a buffer named after DIR.
Reuses that directory's existing session unless NEW is non-nil."
  (require 'eshell)
  (let* ((dir (file-name-as-directory (expand-file-name dir)))
         (default-directory dir)
         (eshell-buffer-name
          (format "*eshell: %s*"
                  (abbreviate-file-name (directory-file-name dir)))))
    (eshell new)))

(defun joe/eshell-home (&optional new)
  "Open an Eshell in $HOME.  With prefix arg NEW, force a fresh session."
  (interactive "P")
  (joe/eshell-in "~" new))

(defun joe/eshell-here (&optional new)
  "Open an Eshell in the current buffer's directory.
With prefix arg NEW, force a fresh session."
  (interactive "P")
  (joe/eshell-in default-directory new))

;; `:if' is safe here where it was not for ghostel — the :ensure-before-:if
;; ordering noted above only bites when :ensure actually installs something,
;; and eshell is built in.
(use-package eshell
  :ensure nil
  :if (eq system-type 'gnu/linux)
  :bind
  ("C-c s" . joe/eshell-home)
  ("C-c S" . joe/eshell-here))

;;;; eww
(use-package eww
  :ensure nil
  :init
  (setq browse-url-browser-function #'eww-browse-url)
  :config
  (setq eww-search-prefix "https://duckduckgo.com/html/?q=")
  (setq eww-download-directory "~/Downloads/")
  (setq eww-history t)
  (setq eww-auto-rename-buffer 'title)
  (setq eww-readable-urls
	'("https://plato.stanford.edu/.*"
          "https://www.marxists.org/.*"
	  "https://splash247.com/.*"
	  "https://theloadstar.com/.*"
          ("https://en.wikipedia.org/.*" . t)))  
  :bind
  ("C-c e" . eww)
  (:map eww-mode-map
        ("M-n" . eww-next-url)
        ("M-p" . eww-previous-url)))

;;;; Windows-only: explicit PATH and exec-path additions
;; On Windows, exec-path-from-shell is not used (it requires a POSIX shell).
;; C:/Users/Joe/bin contains .cmd wrappers that bridge to WSL tools
;; (notmuch.cmd, mbsync.cmd, msmtp.cmd, etc.).
(when (eq system-type 'windows-nt)
  (setenv "HOME" "C:/Users/Joe")
  (dolist (p '("C:/Program Files/Git/usr/bin"
               "C:/msys64/usr/bin"
               "C:/msys64/mingw64/bin"
               "C:/Users/Joe/bin"))
    (add-to-list 'exec-path p t))
  ;; Pipe performance: eliminate the ~50 ms per-read latency Emacs adds by
  ;; default on Windows.  This significantly speeds up magit, rg, notmuch and
  ;; any other subprocess-heavy workflow.
  (setq w32-pipe-read-delay 0)
  (setq w32-pipe-buffer-size (* 64 1024))
  (setq process-adaptive-read-buffering nil))

;;;; tmr
(use-package tmr
  :ensure t
  :bind
  ("C-c t t" . tmr)
  ("C-c t r" . tmr-timer-remove)
  ("C-c t s" . tmr-timer-start)
  :config
  (pcase system-type
    ('windows-nt
     (setq tmr-sound-file "C:/Windows/Media/Alarm10.wav")
     (defun tmr-sound-play (&rest _)
       "Play sound on Windows using PowerShell."
       (when tmr-sound-file
         (call-process "powershell.exe" nil 0 nil
                       "-Command"
                       (format "$p=New-Object System.Media.SoundPlayer('%s');$p.PlaySync()" tmr-sound-file)))))
    ('gnu/linux
     (setq tmr-sound-file "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"))))

(provide 'joe-tools)
;;; joe-tools.el ends here
