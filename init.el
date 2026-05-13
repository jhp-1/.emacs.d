;;; init.el --- Main init -*- lexical-binding: t; -*-

;; Increase GC threshold during startup for faster loading
(setq gc-cons-threshold (* 512 1024 1024)) ; 512MB - even higher for faster startup
(setq gc-cons-percentage 0.8) ; Increase percentage to reduce GC frequency
(setq file-name-handler-alist-original file-name-handler-alist)
(setq file-name-handler-alist nil)

(defconst joe/start-time (current-time))

;; Emacs Wayland improvements for better window management
(setq frame-resize-pixelwise t)
(setq window-resize-pixelwise t)
(setq frame-inhibit-implied-resize t)
(when (eq window-system 'x)
  ;; Improve window movement and resizing on Wayland
  (setq x-gtk-resize-child-frames 'resize-mode)
  ;; Better integration with Wayland compositors
  (setq x-gtk-use-system-tooltips nil))

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; Load startup profiling if needed
;; (require 'startup-profiling) ; Uncomment to enable profiling

;; Essential modules loaded immediately (needed for basic functionality)
(require 'joe-core)
(require 'joe-org-notes)
(require 'joe-completion)
(require 'joe-research)

;; Defer heavy modules until after startup
;; Defer these until idle time
(run-with-idle-timer 0.5 nil
                     (lambda ()
                       (require 'joe-ui)
                       (require 'joe-files)))

(run-with-idle-timer 1 nil
                     (lambda ()
                       (require 'joe-tools)
                       (require 'joe-mail)))

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
