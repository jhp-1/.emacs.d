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

;;;; PowerShell via comint
(defun powershell ()
  "Open a PowerShell buffer."
  (interactive)
  (let ((buf (get-buffer-create "*powershell*")))
    (pop-to-buffer buf)
    (unless (comint-check-proc buf)
      (make-comint-in-buffer "powershell" buf "powershell.exe" nil "-NoLogo")
      (shell-mode))))

(global-set-key (kbd "C-c s") #'powershell)

;;;;; eshell
(defun eshell-at-home ()
  "Opens or creates an eshell buffer at ~/."
  (interactive)
  (if (equal (get-buffer "*eshell ~/*") nil)
      (let ((default-directory "~/"))
        (let ((new-buffer (get-buffer-create "*eshell ~/*")))
          (with-current-buffer new-buffer
            (eshell-mode)
            (switch-to-buffer new-buffer))))
    (switch-to-buffer "*eshell ~/*")))

(use-package eshell
  :ensure nil)

;;;; eww
(use-package eww
  :ensure nil
  :init
  (setq browse-url-browser-function #'eww-browse-url)
  :config
  (setq eww-search-prefix "https://duckduckgo.com/html/?q=")
  (setq eww-download-directory "~/Downloads/")
  :bind
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

;;;; pass
(use-package pass
  :ensure t
  :bind
  ("C-c p p" . pass)
  ("C-c p i" . pass-insert)
  ("C-c p g" . pass-generate))

;;;; elfeed
(use-package elfeed
  :ensure t
  :bind
  ("C-c e" . elfeed)
  :config
  (setq-default elfeed-search-filter "@6-months-ago ")
  (setq elfeed-use-curl t)
  (setq elfeed-curl-max-connections 10)
  (setq elfeed-curl-timeout 10))

(use-package elfeed-org
  :after elfeed
  :ensure t
  :config
  (elfeed-org)
  (setq rmh-elfeed-org-files (list "~/.elfeed/elfeed.org")))

;;;; tmr
(use-package tmr
  :ensure t
  :bind
  ("C-c t t" . tmr)
  ("C-c t r" . tmr-timer-remove)
  ("C-c t s" . tmr-timer-start))

(provide 'joe-tools)
;;; joe-tools.el ends here
