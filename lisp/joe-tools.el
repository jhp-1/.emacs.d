;;; joe-tools.el --- Shells, AI, and external tools configuration -*- lexical-binding: t; -*-

;;;; rg
;; wgrep is a required dependency of rg (>= 2.1.10); install it explicitly.
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
(use-package llama
  :ensure t)

(use-package magit
  :ensure t
  :defer t
  :bind
  ("C-x g" . magit-status)
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1))

;;;; eshell
;; `C-c s' always starts at $HOME; `C-c S' starts in the current buffer's
;; directory, for jumping to a shell from a file you are editing.
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

(use-package eshell
  :ensure nil
  :bind
  ("C-c s" . joe/eshell-home)
  ("C-c S" . joe/eshell-here))

;;;; eww
;; Moved out to joe-eww.el. It was the one thing in this file with no external
;; dependency at all, and on Android it is wanted while magit, rg, eshell and
;; bluetooth are not -- bluetooth in particular `require's dbus at load time,
;; which does not exist there, so merely loading this file to reach eww would
;; fail.

;;;; tmr
(use-package tmr
  :ensure t
  :bind
  ("C-c t t" . tmr)
  ("C-c t r" . tmr-timer-remove)
  ("C-c t s" . tmr-timer-start)
  :config
  (setq tmr-sound-file
        "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"))

(provide 'joe-tools)
;;;; bluetooth
(use-package bluetooth
  :ensure t)
;;; joe-tools.el ends here
