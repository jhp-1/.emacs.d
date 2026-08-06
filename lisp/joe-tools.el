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
(defun ghostel-home ()
  "Open ghostel in the home directory."
  (interactive)
  (let ((default-directory "C:/Users/Joe/"))
    (ghostel)))

(use-package ghostel
  :ensure t
  :custom
  (ghostel-shell "powershell.exe")
  :bind
  ("C-c s" . ghostel-home))

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
  ;; SuperCollider: install dir is version-numbered (SuperCollider-4.x.y), so
  ;; glob for it rather than hardcoding a version that goes stale on upgrade.
  (let ((sc-dir (car (file-expand-wildcards "C:/Program Files/SuperCollider-*"))))
    (when sc-dir
      (add-to-list 'exec-path sc-dir t)))
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

;;;; SuperCollider (sclang)
;; Editing + offline (NRT) rendering only, no live REPL -- scel's Windows
;; support is unclear; revisit if we want real-time livecoding later.
;; Not on MELPA or NonGNU ELPA (checked live against a refreshed archive,
;; Aug 2026 -- neither "sclang" nor "scel" exist there), so this is vendored
;; straight from the upstream repo instead of going through package.el:
;;   git clone --depth 1 https://github.com/supercollider/scel .emacs.d/vendor/scel
;; The sclang-vars.el.in template (CMake-substituted paths) is only needed
;; when building alongside SuperCollider from source; sclang.el doesn't
;; require it, so the plain clone works standalone.
(defun joe/sclang-executable ()
  "Path to sclang.exe, or nil if SuperCollider isn't installed."
  (car (file-expand-wildcards "C:/Program Files/SuperCollider-*/sclang.exe")))

(let ((scel-dir (expand-file-name "vendor/scel/el" user-emacs-directory)))
  (when (file-directory-p scel-dir)
    (add-to-list 'load-path scel-dir)
    (require 'sclang)
    (add-to-list 'auto-mode-alist '("\\.scd\\'" . sclang-mode))
    (keymap-set sclang-mode-map "C-c C-c" #'compile)
    ;; Absolute path, not bare "sclang" -- M-x compile shells out via cmd.exe,
    ;; which resolves commands off the real Windows PATH, not Emacs exec-path.
    (add-hook 'sclang-mode-hook
              (lambda ()
                (when-let ((exe (joe/sclang-executable)))
                  (setq-local compile-command
                              (format "%s %s"
                                      (shell-quote-argument exe)
                                      (shell-quote-argument (buffer-file-name)))))))))

(provide 'joe-tools)
;;; joe-tools.el ends here
