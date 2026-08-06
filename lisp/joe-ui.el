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
;; Skipped on the console appliance. Pulsar technically works in a terminal -
;; it is only face overlays, and kmscon gives truecolor - but a TTY has no
;; sub-cell rendering, so the pulse paints a solid full-width bar out to the
;; screen edge and reads as a flash rather than a fade. That is a property of
;; the character grid, not something tuning the face or iterations fixes.
(use-package pulsar
  :ensure t
  :unless (bound-and-true-p joe/console-appliance-p)
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
;; Font faces are a window-system concept; on the appliance's TTY fontaine
;; warns "Cannot use Fontaine in a terminal emulator". The console font is set
;; system-wide instead (services.kmscon -> Aporetic Serif Mono).
(use-package fontaine
  :ensure t
  :unless (bound-and-true-p joe/console-appliance-p)
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
;; Nerd-icon glyphs live in a private Unicode area that only a patched font
;; carries. The appliance's console (kmscon) is built without pango, so it has
;; no fontconfig fallback: whatever single font is configured must contain the
;; glyph or you get a replacement box. Aporetic is not nerd-patched, hence the
;; row of "?" boxes. Skip the icon packages there rather than render rubbish.
(use-package nerd-icons
  :ensure t
  :unless (bound-and-true-p joe/console-appliance-p))
;; nerd-icons-completion is fully configured in joe-completion.el
;; (marginalia hook + nerd-icons-completion-mode); no duplicate block needed here.
;;;; auto-dark-emacs
;; Use modus-vivendi (dark) and modus-operandi (light) — both are built into
;; Emacs 29+ and always available, avoiding theme-not-found errors at startup.
;; joe--sync-pdf-midnight-colors is defined in joe-core.el.
;; auto-dark polls the OS for a light/dark appearance setting. A bare console
;; has none, so it errors with "Could not determine a viable theme detection
;; mechanism!" and leaves whichever theme happens to be first — modus-vivendi,
;; i.e. dark. Skip it there and pin the light theme explicitly.
(use-package auto-dark
  :ensure t
  :unless (bound-and-true-p joe/console-appliance-p)
  :custom
  (custom-safe-themes t)
  (auto-dark-themes '((modus-vivendi) (modus-operandi)))
  (auto-dark-polling-interval-seconds 5)
  :hook
  ((auto-dark-dark-mode auto-dark-light-mode) . joe--sync-pdf-midnight-colors)
  :init (auto-dark-mode))

(when (bound-and-true-p joe/console-appliance-p)
  ;; On a TTY Emacs emits SGR 39;49 for `default' - "whatever the terminal's
  ;; own default colours are" - instead of painting the theme's background.
  ;; Loading a theme therefore only recoloured faces carrying explicit colours
  ;; (the modeline), leaving the rest at the terminal's background. Pushing
  ;; bg-main/fg-main onto `default' ourselves puts the background back under
  ;; the theme's control, so modus-themes-toggle (<f8>) genuinely switches
  ;; light <-> dark instead of leaving a dark theme stranded on a white
  ;; terminal.
  (defun joe/console-sync-default-face (&rest _)
    "Apply the active modus theme's main colours to the TTY `default' face."
    (when (fboundp 'modus-themes-get-color-value)
      (let ((bg (modus-themes-get-color-value 'bg-main))
            (fg (modus-themes-get-color-value 'fg-main)))
        (when (and (stringp bg) (stringp fg))
          (dolist (frame (frame-list))
            (unless (display-graphic-p frame)
              (set-face-background 'default bg frame)
              (set-face-foreground 'default fg frame)))))))

  (add-hook 'modus-themes-after-load-theme-hook #'joe/console-sync-default-face)
  ;; Frames made later by emacsclient need it too: a theme loaded inside the
  ;; daemon before any frame existed does not reach them on its own.
  (add-hook 'server-after-make-frame-hook #'joe/console-sync-default-face)
  (add-hook 'after-make-frame-functions #'joe/console-sync-default-face)

  (load-theme 'modus-operandi t)
  (joe/console-sync-default-face))

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
