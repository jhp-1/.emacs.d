;;; joe-ui.el --- UI-related configuration -*- lexical-binding: t; -*-

;;;; Follow mouse 
(setq mouse-autoselect-window t)

;;;; Cursor
(setq-default cursor-type 'bar)

;;;; Pulsar
(use-package pulsar
  :ensure t
  :defer t
  :config
  (setq pulsar-pulse t)
  (setq pulsar-delay 0.055)
  (setq pulsar-iterations 10)
  (setq pulsar-face 'pulsar-magenta)
  (setq pulsar-highlight-face 'pulsar-yellow)
  (setq pulsar-pulse-functions
      (append pulsar-pulse-functions
              '(aw-switch-to-window ace-window)))
  :init
  (pulsar-global-mode 1))

;;;; Popup frames
(defun prot-window-delete-popup-frame (&rest _)
  "Kill selected selected frame if it has parameter `prot-window-popup-frame'.
Use this function via a hook."
  (when (frame-parameter nil 'prot-window-popup-frame)
    (delete-frame)))

(defmacro prot-window-define-with-popup-frame (command)
  "Define interactive function which calls COMMAND in a new frame.
Make the new frame have the `prot-window-popup-frame' parameter."
  `(defun ,(intern (format "prot-window-popup-%s" command)) ()
     ,(format "Run `%s' in a popup frame with `prot-window-popup-frame' parameter.
Also see `prot-window-delete-popup-frame'." command)
     (interactive)
     (let ((frame (make-frame '((prot-window-popup-frame . t)))))
       (select-frame frame)
       (switch-to-buffer " prot-window-hidden-buffer-for-popup-frame")
       (condition-case nil
           (call-interactively ',command)
         ((quit error user-error)
          (delete-frame frame))))))

(declare-function org-capture "org-capture" (&optional goto keys))
(defvar org-capture-after-finalize-hook)

(prot-window-define-with-popup-frame org-capture)

(add-hook 'org-capture-after-finalize-hook #'prot-window-delete-popup-frame)

(declare-function tmr "tmr" (time &optional description acknowledgep))
(defvar tmr-timer-created-functions)

;;;###autoload (autoload 'prot-window-popup-tmr "prot-window")
(prot-window-define-with-popup-frame tmr)

(add-hook 'tmr-timer-created-functions #'prot-window-delete-popup-frame)

;;;;; Vterm popup frame
(declare-function vterm "vterm")

;;;###autoload (autoload 'prot-window-popup-vterm "prot-window")
(defun prot-window-popup-vterm ()
  "Run `vterm' in a popup frame with `prot-window-popup-frame' parameter."
  (interactive)
  (let ((frame (make-frame '((prot-window-popup-frame . t)))))
    (select-frame frame)
    (switch-to-buffer " prot-window-hidden-buffer-for-popup-frame")
    (let ((default-directory "~/"))
      (condition-case nil
          (call-interactively 'vterm)
        ((quit error user-error)
         (delete-frame frame))))))

(defun prot-window-delete-vterm-popup-frame ()
  "Delete popup frame when vterm process exits."
  (when (and (eq major-mode 'vterm-mode)
             (frame-parameter nil 'prot-window-popup-frame))
    (delete-frame)))

(add-hook 'vterm-exit-functions #'prot-window-delete-vterm-popup-frame)

;;;; doric-themes
(use-package doric-themes
  :ensure t
  :config
  (setq doric-themes-to-toggle '(doric-light doric-obsidian))
  :bind
  ("<f8>" . doric-themes-toggle))

;;;; Modeline
(use-package minions
  :ensure t
  :config
  (setq minions-mode-line-lighter ";")
  (minions-mode 1))

(use-package hide-mode-line
  :ensure t)

;;;; olivetti
(use-package olivetti
  :ensure t
  :config
  (setq-default olivetti-body-width 0.7)
  (setq olivetti-minimum-body-width 80)
  (setq olivetti-recall-visual-line-mode-entry-state t)
  :bind
  ("<f6>" . olivetti-mode))

;;;; fontaine
(use-package fontaine
  :ensure t
  :config
  (setq fontaine-presets
        '((regular
           :default-height 120
           :variable-pitch-height 120)
          (large
           :default-height 140
           :variable-pitch-height 140)
          (t
           :default-height 120
           :variable-pitch-height 120)))
  (fontaine-set-preset 'regular))

;;;; nerd-icons
(use-package nerd-icons
  :ensure t)

;;;; auto-dark-emacs
(use-package auto-dark
  :ensure t
  :custom
  (custom-safe-themes t) 
  (auto-dark-themes '((doric-obsidian) (doric-light)))
  (auto-dark-polling-interval-seconds 5)
  :hook
  (auto-dark-dark-mode
   . (lambda ()
       (setq-default pdf-view-midnight-colors
		     (cons (frame-parameter nil 'foreground-color)
			   (frame-parameter nil 'background-color)))))
  (auto-dark-light-mode
   . (lambda ()
       (setq-default pdf-view-midnight-colors
		     (cons (frame-parameter nil 'foreground-color)
			   (frame-parameter nil 'background-color)))))
  :init (auto-dark-mode))

;;;; ultra-scroll
(use-package ultra-scroll
  :ensure t
  :config
  (ultra-scroll-mode 1))

;;;;; outline
(use-package outline
  :ensure nil
  :hook
  (outline-mode . reveal-mode)
  :bind
  ("C-<tab>" . outline-cycle))

(defun joe/my-outline-hide-all ()
  "Hide all but the top-level headings in `outline-minor-mode`."
(interactive)
  (outline-hide-sublevels 1))
(add-hook 'outline-minor-mode-hook 'joe/my-outline-hide-all)

(setq outline-regexp "^\\((\\|;;;+ \\)")

(use-package outline-minor-faces
  :ensure t
  :config
  (setq outline-minor-faces-regexp ";;;+")
  :hook (outline-minor-mode . outline-minor-faces-mode))

(add-hook 'emacs-lisp-mode-hook 'outline-minor-mode)

;;;;; electric-pair-mode
(setq electric-pair-mode t)

(provide 'joe-ui)
;;; joe-ui.el ends here
