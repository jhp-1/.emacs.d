;;; init.el --- Main init -*- lexical-binding: t; -*-

;; GC threshold already maximised in early-init.el; just disable the file-name
;; handler for faster require calls during startup.
(setq file-name-handler-alist-original file-name-handler-alist)
(setq file-name-handler-alist nil)

(defconst joe/start-time (current-time))

;; Emacs Wayland improvements for better window management
(setq frame-resize-pixelwise t)
(setq window-resize-pixelwise t)
;; frame-inhibit-implied-resize is set in early-init.el
(when (eq window-system 'x)
  ;; Improve window movement and resizing on Wayland
  (setq x-gtk-resize-child-frames 'resize-mode)
  ;; Better integration with Wayland compositors
  (setq x-gtk-use-system-tooltips nil))

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
;; wsl.exe lives here; only meaningful on Windows
(when (eq system-type 'windows-nt)
  (add-to-list 'exec-path "C:/Windows/System32"))

;; Load startup profiling if needed
;; (require 'startup-profiling) ; Uncomment to enable profiling

;; Essential modules loaded immediately (needed for basic functionality)
(require 'joe-core)
(require 'joe-completion)

;; Org and bibliography are heavy on Windows (bib file read, org-element init,
;; AV scanning) — defer them to just after startup so the daemon is ready fast.
(run-with-idle-timer 0.1 nil
                     (lambda ()
                       (require 'joe-org-notes)
                       (require 'joe-career)
                       (require 'joe-research)
                       (require 'joe-python)))

(run-with-idle-timer 0.5 nil
                     (lambda ()
                       (require 'joe-ui)
                       (require 'joe-files)))

(run-with-idle-timer 1 nil
                     (lambda ()
                       (require 'joe-tools)
                       (require 'joe-mail)
                       (require 'joe-elfeed)))

;; Restore GC settings and report startup time
(add-hook 'emacs-startup-hook
          (lambda ()
            ;; Restore default GC settings
            (setq gc-cons-threshold (* 16 1024 1024)
                  gc-cons-percentage 0.1
                  file-name-handler-alist file-name-handler-alist-original)
            (message "Emacs ready in %.2fs with %d GCs"
                     (float-time
                      (time-subtract (current-time) joe/start-time))
                     gcs-done)))

(provide 'init)
;;; init.el ends here
