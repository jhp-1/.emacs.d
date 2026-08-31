;;; joe-ui.el --- UI-related configuration -*- lexical-binding: t; -*-

;;;; Follow mouse
;; Focus-follows-mouse conflicts with Windows' own focus system when using
;; multiple frames; disable it there.
;; Off on Android too, where there is no mouse to follow: the port synthesises
;; mouse motion from touch events, so this turns an incidental drag of the
;; thumb across a window boundary into a window switch.
(when (not (or (eq system-type 'windows-nt)
               (bound-and-true-p joe/android-p)))
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
  ;; A phone in portrait is narrower than the 80-column floor, so olivetti
  ;; would refuse to narrow anything and <f6> would look like a no-op.
  (setq olivetti-minimum-body-width
        (if (bound-and-true-p joe/android-p) 30 80))
  (setq olivetti-recall-visual-line-mode-entry-state t)
  :bind
  ("<f6>" . olivetti-mode))

;;;; fontaine
;; Font faces are a window-system concept; on the appliance's TTY fontaine
;; warns "Cannot use Fontaine in a terminal emulator". The console font is set
;; system-wide instead (services.kmscon -> Aporetic Serif Mono).
;; Skipped on Android for a different reason: Aporetic is not installed there
;; (Android fonts come from ~/fonts and nothing else), and fontaine would set
;; the face to a family that does not exist. joe-android.el sets the default
;; height directly instead, which is the only part of the preset that matters
;; on one small screen.
(use-package fontaine
  :ensure t
  :unless (or (bound-and-true-p joe/console-appliance-p)
              (bound-and-true-p joe/android-p))
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
;; `joe/no-icon-font-p' (early-init.el) covers the appliance's console and
;; Android alike -- same symptom, replacement boxes, for unrelated reasons.
(use-package nerd-icons
  :ensure t
  :unless (bound-and-true-p joe/no-icon-font-p))
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
;; Android is skipped for the same reason as the console: auto-dark has no
;; detection mechanism there either, so it errors out and strands whichever
;; theme loaded first. The theme is pinned explicitly just below.
(use-package auto-dark
  :ensure t
  :unless (or (bound-and-true-p joe/console-appliance-p)
              (bound-and-true-p joe/android-p))
  :custom
  (custom-safe-themes t)
  (auto-dark-themes '((modus-vivendi) (modus-operandi)))
  (auto-dark-polling-interval-seconds 5)
  :hook
  ((auto-dark-dark-mode auto-dark-light-mode) . joe--sync-pdf-midnight-colors)
  :init (auto-dark-mode))

;; Standing in for auto-dark above. <f8> (`modus-themes-toggle') still switches
;; by hand, which on a phone -- where you can see the screen and the OS setting
;; is one swipe away anyway -- is enough.
(when (bound-and-true-p joe/android-p)
  (load-theme 'modus-operandi t))

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

  ;; Modus draws the mode line's border as an :underline on a TTY (confirmed:
  ;; :underline "#5a5a5a" on mode-line/mode-line-active, "#a3a3a3" on
  ;; -inactive, with :box unspecified) - it substitutes one for the box it
  ;; cannot draw in a terminal. The mode line already reads as a distinct band
  ;; from its own background, so the underline is pure noise here. Must run on
  ;; the same hook as the face sync: modus reapplies its own faces on every
  ;; theme load, so a one-shot set-face-attribute would be undone by <f8>.
  (defun joe/console-flatten-mode-line (&rest _)
    "Strip modus's TTY mode-line underline."
    (dolist (face '(mode-line mode-line-active mode-line-inactive))
      (when (facep face)
        (set-face-attribute face nil :underline nil :overline nil))))

  ;; `enable-theme-functions' (Emacs 29+) rather than
  ;; `modus-themes-after-load-theme-hook': modus does NOT advise `load-theme'
  ;; (checked its source - the hook is only run from its own commands like
  ;; modus-themes-toggle). Anything calling plain `load-theme' - the sunset
  ;; timer below, `M-x load-theme', a future package - would otherwise switch
  ;; the theme while silently skipping both fixes, leaving the TTY background
  ;; stranded and the mode-line underline back. enable-theme-functions is run
  ;; by the theme machinery itself for every activation, whoever triggered it.
  (add-hook 'enable-theme-functions #'joe/console-sync-default-face)
  (add-hook 'enable-theme-functions #'joe/console-flatten-mode-line)
  ;; Frames made later by emacsclient need it too: a theme loaded inside the
  ;; daemon before any frame existed does not reach them on its own.
  (add-hook 'server-after-make-frame-hook #'joe/console-sync-default-face)
  (add-hook 'server-after-make-frame-hook #'joe/console-flatten-mode-line)
  (add-hook 'after-make-frame-functions #'joe/console-sync-default-face)
  (add-hook 'after-make-frame-functions #'joe/console-flatten-mode-line)

  ;; The trailing "-------" is not modus and not a theme: stock Emacs defaults
  ;; `mode-line-end-spaces' to (:eval (unless (display-graphic-p) "-%-")),
  ;; where %- means "fill the rest of the line with dashes". It is gated on
  ;; display-graphic-p, which is exactly why it never appears in the GUI on
  ;; Windows and only showed up here. The mode-line face already spans the
  ;; full window width, so nothing needs filling.
  (setq-default mode-line-end-spaces "")

  ;;;; Sunrise/sunset theme switching
  ;; Replaces auto-dark on this box, which has no OS appearance setting to
  ;; poll. Uses built-in solar.el rather than the `circadian' package - it is
  ;; ~25 lines and avoids a dependency on a machine where installing things is
  ;; deliberately awkward. Coordinates are approximate on purpose: 0.1 degree
  ;; is well under a minute of error, and being 50km out moves sunrise by
  ;; about two minutes.
  (require 'solar)
  (setq calendar-latitude 51.5
        calendar-longitude -0.1
        calendar-location-name "London")

  (defun joe/console--solar-times ()
    "Return (SUNRISE . SUNSET) today as float hours, or nil if unavailable.
Polar day/night and other edge cases make `solar-sunrise-sunset' return a
list without usable times; callers must handle nil."
    (let* ((data (solar-sunrise-sunset (calendar-current-date)))
           (rise (caar data))
           (set (car (cadr data))))
      (when (and (numberp rise) (numberp set))
        (cons rise set))))

  (defun joe/console-theme-for-now ()
    "Return the theme appropriate to the current time of day."
    (let ((times (joe/console--solar-times)))
      (if (null times)
          'modus-operandi          ; no sun data: default to light
        (let* ((now (decode-time))
               (hour (+ (nth 2 now) (/ (nth 1 now) 60.0))))
          (if (and (>= hour (car times)) (< hour (cdr times)))
              'modus-operandi
            'modus-vivendi)))))

  (defun joe/console-apply-solar-theme ()
    "Load whichever theme suits the current time, if not already active."
    (interactive)
    (let ((want (joe/console-theme-for-now)))
      (unless (memq want custom-enabled-themes)
        ;; Disable the other one first, or its faces linger underneath and
        ;; show through wherever the incoming theme does not override them.
        (mapc #'disable-theme custom-enabled-themes)
        (load-theme want t))))

  ;; Re-evaluated hourly rather than scheduled precisely at each event: the
  ;; times shift daily, the machine sleeps and wakes across boundaries, and a
  ;; timer that fired while suspended is simply missed. Polling is a few
  ;; microseconds and cannot drift out of step. Worst case the switch is up to
  ;; an hour late; <f8> still overrides manually until the next check.
  (run-at-time t 3600 #'joe/console-apply-solar-theme)

  (joe/console-apply-solar-theme)
  (joe/console-sync-default-face)
  (joe/console-flatten-mode-line))

;;;; ultra-scroll
;; Not on Android: it retrofits pixel-precise scrolling onto mouse wheel and
;; trackpad events, and the port already does its own precision scrolling from
;; touch events (`touch-screen-precision-scroll'). Two systems driving the same
;; window is how you get scroll that fights the finger.
(use-package ultra-scroll
  :ensure t
  :unless (bound-and-true-p joe/android-p)
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

;; C-<tab> cannot be typed in a terminal. Confirmed from `recent-keys' on the
;; appliance: pressing Ctrl+Tab in kmscon delivers a bare TAB - the Control
;; modifier is dropped before Emacs ever sees it - so the keypress ran
;; `indent-for-tab-command' and folding appeared broken. The command itself is
;; fine; only the binding was unreachable. Same class as the embark C-. / C-;
;; / C-, chords rebound in joe-completion.el.
;;
;; C-c TAB keeps the muscle memory (still "control, then tab") while being
;; expressible in a terminal, and C-c S-TAB mirrors org's whole-buffer cycle.
;; The GUI keeps C-<tab> above, where it works.
(when (bound-and-true-p joe/console-appliance-p)
  (keymap-global-set "C-c TAB" #'outline-cycle)
  (keymap-global-set "C-c <backtab>" #'outline-cycle-buffer))

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
