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

;; Windows-only: it shells out to powershell.exe, defaults to C:/Users/Joe/,
;; and ships a native ghostel-module.so. On the appliance the module cannot be
;; built (no compiler) or loaded (noexec /home), so it only warns on startup.
;; Wrapped in `when' rather than using :if, because use-package processes
;; :ensure BEFORE :if - so :if alone still installed the package here, and its
;; autoloads then warned about the missing native module on every startup.
(when (eq system-type 'windows-nt)
  (use-package ghostel
    :ensure t
    :custom
    (ghostel-shell "powershell.exe")
    :bind
    ("C-c s" . ghostel-home)))

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
