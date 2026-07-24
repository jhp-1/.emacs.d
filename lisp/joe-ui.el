;;; joe-ui.el --- UI-related configuration -*- lexical-binding: t; -*-

;;;; Follow mouse
;; Focus-follows-mouse conflicts with Windows' own focus system when using
;; multiple frames; disable it there.
(when (not (eq system-type 'windows-nt))
  (setq mouse-autoselect-window t))

;;;; Cursor
(setq-default cursor-type 'bar)

;;;; Bell
;; Emacs dings on every trivial event (point hitting end of buffer, C-g in the
;; minibuffer, isearch wrapping), which on Windows is the loud system alert
;; sound rather than a discreet beep.  `ring-bell-function' takes precedence
;; over `visible-bell', so pointing it at `ignore' silences the audible bell
;; and the screen flash together; `visible-bell' is pinned to nil so nothing
;; re-enables the flash if that precedence ever changes.
(setq ring-bell-function #'ignore)
(setq visible-bell nil)

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

;;;; Frames
(add-hook 'server-after-make-frame-hook
          (lambda () (select-frame-set-input-focus (selected-frame))))

;;;; modus-themes
;; Built into Emacs 29+; :ensure t pulls a newer version from GNU ELPA if available.
(use-package modus-themes
  :ensure t
  :config
  (setq modus-themes-to-toggle '(modus-operandi modus-vivendi))
  :bind
  ("<f8>" . modus-themes-toggle))

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
	   :default-family "Aporetic Serif"
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
;; nerd-icons-completion is fully configured in joe-completion.el
;; (marginalia hook + nerd-icons-completion-mode); no duplicate block needed here.
;;;; auto-dark-emacs
;; Use modus-vivendi (dark) and modus-operandi (light) — both are built into
;; Emacs 29+ and always available, avoiding theme-not-found errors at startup.
;; joe--sync-pdf-midnight-colors is defined in joe-core.el.
(use-package auto-dark
  :ensure t
  :custom
  (custom-safe-themes t)
  (auto-dark-themes '((modus-vivendi) (modus-operandi)))
  (auto-dark-polling-interval-seconds 5)
  :hook
  ((auto-dark-dark-mode auto-dark-light-mode) . joe--sync-pdf-midnight-colors)
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
  (("C-<tab>" . outline-cycle)
   :map outline-mode-map
   ("C-c C-n" . outline-next-visible-heading)
   ("C-c C-p" . outline-previous-visible-heading)))

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
(electric-pair-mode 1)

(provide 'joe-ui)
;;; joe-ui.el ends here
