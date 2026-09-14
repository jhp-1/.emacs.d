;;; joe-windows.el --- Window, buffer and movement management -*- lexical-binding: t; -*-

;; Everything about getting focus into the right window, getting buffers into
;; the right windows, and — more often — not having to switch windows at all.
;; Built from Karthik Chikmagalur's "Emacs Window Management Almanac"
;; <https://karthinks.com/software/emacs-window-management-almanac/>, keeping
;; the parts that fit this configuration.
;;
;; Loaded eagerly from init.el immediately after joe-core, ahead of the
;; idle-timer tiers: these are movement keys, and a daemon that is up but whose
;; movement keys are not is worse than a daemon that is not up yet. The module
;; is small and depends only on built-ins plus ace-window.

(require 'cl-lib)                       ;`cl-letf', in the pop-global-mark advice

;;;; ace-window
;; Moved here from joe-core.el — this is window management, not "core", and
;; `joe/ace-window-prefix' / `joe/ace-window-one-command' below call `aw-select'
;; directly, so the package and its consumers belong in one place.
;;
;; `aw-dispatch-always' is what makes `?' (the dispatch menu) reachable with two
;; or fewer windows on screen; without it ace-window silently degrades to a
;; plain window switcher exactly when you have the fewest windows to switch to.
(use-package ace-window
  :ensure t
  :bind
  ("M-o" . ace-window)
  :config
  (setq aw-scope 'global)
  (setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
  (setq aw-background nil)
  (setq aw-leading-char-style 'char)
  (setq aw-dispatch-always t)

  ;; `?j' is both a window label (it is in `aw-keys' above) and a dispatch
  ;; action ("Select Buffer") in the stock `aw-dispatch-alist'. ace-window
  ;; checks the labels first, so the action has never been reachable — pressing
  ;; `j' has always just jumped to window j. Move it to `?B', which nothing
  ;; else claims.
  (setq aw-dispatch-alist
        (cons '(?B aw-switch-buffer-in-window "Select Buffer")
              (assq-delete-all ?j (copy-sequence aw-dispatch-alist)))))

;; `aw-select' is the ace-window equivalent of `completing-read': it returns a
;; window rather than acting on one. It is not autoloaded, so every caller
;; below requires ace-window first; this declaration only quiets the compiler.
(declare-function aw-select "ace-window" (mode-line &optional action))

;;;; Selecting windows

;;;;; The back-and-forth method
;; However many windows are on screen, almost every switch is a bounce between
;; two of them: prose and notes, PDF and literature note, code and REPL, agenda
;; and the entry it expands. `other-window' cannot express that — it walks a
;; clockwise cycle, so with three or more windows "go back to where I just was"
;; costs a variable and unpredictable number of presses.
;;
;; This takes `C-x o' because that is the key the hand already reaches for.
;; `M-o' stays on `ace-window', which is the O(1) go-anywhere selector; the two
;; cover different jobs and neither replaces the other.
(defun joe/other-window-mru (&optional arg)
  "Select the most recently used other window on this frame.
With one window on the frame, split it first, so this key always does
something.  With a prefix ARG, fall back to plain `other-window' with
that count, which is still the way to walk a specific number of windows.

The `or' fallback to `next-window' matters: `get-mru-window' returns nil
whenever no other window qualifies, and an earlier version of this
command wrapped it in `when-let*' — so `C-x o' silently did nothing."
  (interactive "P")
  (cond
   (arg
    (other-window (prefix-numeric-value arg)))
   ((one-window-p 'no-mini)
    (select-window (or (split-window-sensibly) (split-window-right))))
   (t
    (select-window (or (get-mru-window nil nil 'not-selected)
                       (next-window nil 'nomini))))))

(keymap-global-set "C-x o" #'joe/other-window-mru)

;;;;; repeat-mode
;; Nothing in this configuration enabled it, which left a good deal of built-in
;; ergonomics switched off — `other-window-repeat-map', `winner-repeat-map' and
;; the resize/page maps all ship with `:repeat t' and do nothing without it.
;;
;; `repeat-exit-key' is deliberately left at nil: the obvious value, ESC, is
;; also the meta prefix, so binding it would eat `M-'-prefixed keys pressed
;; while a repeat map is active. Any unbound key already exits.
(require 'repeat)
(repeat-mode 1)

;; Cyclic `other-window' is still worth having for walking a busy frame, and
;; under repeat-mode it is cheap: `C-x o' then `o o o' (or `O' backwards).
;; Registering the MRU command in the same map means a second `o' bounces back,
;; which is the behaviour you want from a back-and-forth key anyway.
(put 'joe/other-window-mru 'repeat-map 'other-window-repeat-map)
(keymap-set other-window-repeat-map "o" #'joe/other-window-mru)

;; The almanac gives "split when there is only one window" as `:before' advice
;; on `other-window'. Deliberately not done that way here, for two reasons.
;; It would not fire for `C-x o' at all, which is now `joe/other-window-mru'
;; and never calls `other-window'; and `other-window' is called
;; *programmatically* by plenty of library code, which would then find itself
;; splitting the user's frame as a side effect. The behaviour belongs in the
;; interactive command — see the `one-window-p' branch above — which is the
;; half you actually press.

;;;;; windmove
;; Directional selection, and directional *movement of buffers between*
;; windows, which is the part people forget exists.
;;
;; On `C-M-<arrows>' rather than the more usual `S-' or `M-' arrows, because
;; both of those are org's: `S-<left>' is `org-shiftleft' (timestamps, TODO
;; state, list bullets) and `M-<left>' is `org-metaleft' (promote/demote,
;; move subtree). `C-M-<arrows>' are unbound in org, dired, prog-mode,
;; text-mode and emacs-lisp-mode — checked, not assumed — and the four global
;; commands they displace (backward-sexp, forward-sexp, backward-up-list,
;; down-list) all keep their letter forms on `C-M-b/f/u/d', so nothing is lost.
;;
;; The reason that check matters: `windmove-default-keybindings' does NOT bind
;; globally. It binds into `windmove-mode-map', the keymap of a global minor
;; mode (windmove.el:446-454) — and a minor-mode map outranks the major mode's.
;; So a windmove binding silently wins over org, magit, dired and everything
;; else, rather than politely losing to them.
;;
;; That is exactly why swap-states is NOT on `C-M-S-<arrows>', the obvious
;; choice: `C-M-S-<left>' / `C-M-S-<right>' are `org-decrease-number-at-point'
;; and `org-increase-number-at-point', and windmove would have eaten both
;; without a word. Swap lives on `C-x w H/J/K/L' below instead.
(require 'windmove)
(windmove-default-keybindings '(control meta))

;;;; Displaying buffers where you want them

;; The `*-prefix' commands — `C-x 4 4' (other window), `C-x 4 1' (this window),
;; `C-x 5 5' (other frame), `C-x t t' (other tab) — redirect wherever the *next*
;; command decides to display a buffer. They make the whole
;; `find-file-other-window' / `switch-to-buffer-other-window' family redundant,
;; and more importantly they work on commands that offer no such choice at all:
;; RET on a notmuch thread, an elfeed entry, an org link, a citar candidate.
;;
;; They are already bound by Emacs. This setting is the piece that was missing:
;; without it `switch-to-buffer' ignores display actions entirely, so the
;; prefixes silently do nothing for the single most common buffer command.
(setq switch-to-buffer-obey-display-actions t)

(defun joe/ace-window-prefix ()
  "Use `ace-window' to choose where the next command displays its buffer.
Like `other-window-prefix' (\\[other-window-prefix]), but the window is
picked rather than guessed — including windows on other frames, and
windows created on the spot with an ace-window dispatch action."
  (interactive)
  (require 'ace-window)
  (display-buffer-override-next-command
   (lambda (_buffer _alist)
     (cons (aw-select (propertize " ACE" 'face 'mode-line-highlight)) 'reuse))
   nil "[ace-window]")
  (message "Use `ace-window' to display next command buffer..."))

(defun joe/ace-window-one-command ()
  "Run a single command in an ace-window-selected window, then return.
Reads one key sequence and executes its binding in the chosen window.
Point and the selected window are left where they were, so this covers
the whole switch → act → switch-back dance without configuring anything
per-action."
  (interactive)
  (require 'ace-window)
  (let ((win (aw-select " ACE")))
    (when (windowp win)
      (with-selected-window win
        (let* ((command (key-binding
                         (read-key-sequence
                          (format "Run in %s..." (buffer-name)))))
               (this-command command))
          (call-interactively command))))))

;; `C-x 4 o' follows the ctl-x-4-map convention (commands that use another
;; window); `C-x O' is the shifted sibling of the window-selection key.
(keymap-global-set "C-x 4 o" #'joe/ace-window-prefix)
(keymap-global-set "C-x O"   #'joe/ace-window-one-command)

;;;; Acting in another window without leaving this one

;; Which window `scroll-other-window' (C-M-v) and friends operate on. The
;; default is the *next* window clockwise, which breaks down as soon as there
;; are three: with a reference buffer plus two working buffers, C-M-v from one
;; working buffer scrolls the other rather than the reference.
;;
;; Most-recently-used matches the back-and-forth model above: the window you
;; last came from is the one you want to scroll.
(setq other-window-scroll-default
      (lambda ()
        (or (get-mru-window nil nil 'not-this-one-dummy)
            (next-window)
            (next-window nil nil 'visible))))

;; The almanac suggests remapping `scroll-up-command' / `scroll-down-command'
;; in `pdf-view-mode-map' so that `scroll-other-window' — which since Emacs 29
;; dispatches through whatever those commands are bound to in the target
;; window — pages a PDF rather than doing nothing. Do NOT add that here:
;; pdf-tools has carried it upstream since well before the version Nix builds
;; (pdf-view.el:329-330 in pdf-tools-20260102). C-M-v already pages the PDF
;; from the note beside it; the only piece that was missing is the
;; `other-window-scroll-default' above, which is what makes it aim at the right
;; window once a third one appears.

(defmacro joe/with-other-window (&rest body)
  "Execute BODY in the window `other-window-scroll-default' picks.
The elisp counterpart to `joe/ace-window-one-command': the same
switch → act → switch-back dance, but written once rather than per
command.  Uses `with-selected-window' rather than
`save-window-excursion', so changes BODY makes to the other window
persist — which is the entire point."
  (declare (indent 0) (debug t))
  `(unless (one-window-p)
     (with-selected-window (other-window-for-scrolling) ,@body)))

(defun joe/isearch-other-window (regexp-p)
  "Search forward in the other window without leaving this one.
With prefix arg REGEXP-P, search for a regular expression."
  (interactive "P")
  (joe/with-other-window (isearch-forward regexp-p)))

(defun joe/isearch-other-window-backward (regexp-p)
  "Search backward in the other window without leaving this one.
With prefix arg REGEXP-P, search for a regular expression."
  (interactive "P")
  (joe/with-other-window (isearch-backward regexp-p)))

;;;; Buffer cycling, optionally in the other window

;; There are hundreds of buffers and a handful of windows, so changing which
;; buffer a window shows is as much "window management" as moving between
;; windows. These wrap the built-ins rather than adding
;; `next-buffer-other-window'-style commands: one key, and `C-u' redirects it.
;;
;; They take `C-x C-n' and `C-x C-p', which by default are `set-goal-column'
;; and `mark-page' — two of the least-used bindings in stock Emacs, and both
;; still reachable by name.
(defun joe/next-buffer (&optional arg)
  "Switch to the next ARGth buffer.
With a universal prefix arg, switch buffers in the other window instead."
  (interactive "P")
  (if-let* (((equal arg '(4)))
            (win (other-window-for-scrolling)))
      (with-selected-window win
        (next-buffer)
        (setq prefix-arg current-prefix-arg))
    (next-buffer arg)))

(defun joe/previous-buffer (&optional arg)
  "Switch to the previous ARGth buffer.
With a universal prefix arg, switch buffers in the other window instead."
  (interactive "P")
  (if-let* (((equal arg '(4)))
            (win (other-window-for-scrolling)))
      (with-selected-window win
        (previous-buffer)
        (setq prefix-arg current-prefix-arg))
    (previous-buffer arg)))

(defun joe/switch-buffer (&optional arg)
  "Switch buffer, in the other window with a universal prefix ARG.
The fallback for when the buffer you want is not one or two steps away
in the window's history.  Deferred through `run-at-time' so that it
reads from the minibuffer after the repeat map has exited."
  (interactive "P")
  (run-at-time
   0 nil
   (lambda (arg)
     (if-let* (((equal arg '(4)))
               (win (other-window-for-scrolling)))
         (with-selected-window win
           (switch-to-buffer
            (read-buffer-to-switch (format "Switch to buffer (%S)" win))))
       (call-interactively #'switch-to-buffer)))
   arg))

(defvar-keymap joe/buffer-cycle-map
  :doc "Keymap for cycling buffers, for `repeat-mode'."
  :repeat t
  "n" #'joe/next-buffer
  "p" #'joe/previous-buffer
  "b" #'joe/switch-buffer)

(keymap-global-set "C-x C-n" #'joe/next-buffer)
(keymap-global-set "C-x C-p" #'joe/previous-buffer)

;;;; The window prefix map (C-x w)

;; `window-prefix-map' already holds the genuinely useful and genuinely obscure
;; window commands — `split-root-window-right' / `-below' (C-x w 3 / 2), which
;; split the frame root rather than dicing up the current window, and
;; `window-toggle-side-windows' (C-x w s). It is the natural home for the rest
;; of this file's window verbs, and which-key makes the whole set discoverable
;; from one prefix.

;; Directional movement again, this time spelled without modifiers on the arrow
;; keys. Two reasons, either sufficient on its own:
;;
;;   1. kmscon on the x270 drops Control and Meta from arrow keys before Emacs
;;      sees them — the same failure documented for `C-<tab>' in joe-ui.el, and
;;      confirmed there from `recent-keys'. `C-M-<right>' is simply untypeable
;;      on that machine; `C-x w l' is not.
;;   2. which-key turns `C-x w' into a printed menu of every window verb,
;;      which the modifier chords can never be.
;;
;; Shifted for swap, matching the arrow/shifted-arrow convention elsewhere.
(pcase-dolist (`(,key . ,cmd)
               '(("h" . windmove-left)
                 ("j" . windmove-down)
                 ("k" . windmove-up)
                 ("l" . windmove-right)
                 ("H" . windmove-swap-states-left)
                 ("J" . windmove-swap-states-down)
                 ("K" . windmove-swap-states-up)
                 ("L" . windmove-swap-states-right)))
  (keymap-set window-prefix-map key cmd))

;; Under repeat-mode this amortises the prefix away: `C-x w l l l' walks right,
;; `H' swaps. The bare arrow keys are deliberately absent from this map — a
;; `<left>' that moves windows instead of point, seconds after a windmove, is
;; worse than the prefix it would save.
(defvar-keymap joe/windmove-repeat-map
  :doc "Repeat map for windmove: hjkl select, HJKL swap."
  :repeat t
  "h" #'windmove-left
  "j" #'windmove-down
  "k" #'windmove-up
  "l" #'windmove-right
  "H" #'windmove-swap-states-left
  "J" #'windmove-swap-states-down
  "K" #'windmove-swap-states-up
  "L" #'windmove-swap-states-right)

;; `tear-off-window' and `tab-window-detach' ship on `C-x w ^ f' and `C-x w ^ t'.
;; The `^' level holds nothing else; these are the saner spellings.
(keymap-set window-prefix-map "f" #'tear-off-window)
(keymap-set window-prefix-map "t" #'tab-window-detach)

;; `C-M-s' is `consult-ripgrep' in joe-completion.el, so the isearch-other-window
;; pair lives here instead. Three keystrokes, but grouped and discoverable.
(keymap-set window-prefix-map "i" #'joe/isearch-other-window)
(keymap-set window-prefix-map "I" #'joe/isearch-other-window-backward)

;;;; The "oops" layer

;; `winner-dont-bind-my-keys' MUST be set before winner.el loads: its default
;; keymap is built at load time, not when the mode is enabled. And it must be
;; set at all, because winner binds `C-c <left>' / `C-c <right>' — which in org
;; are `org-shiftleft' / `org-shiftright' — and a minor-mode map shadows a
;; major-mode map, so winner would win every time.
;;
;; `winner-mode' rather than `tab-bar-history-mode': that one keeps a history
;; per tab, and there is no tab-bar configuration here. Winner keeps one per
;; frame, which suits a multi-frame emacsclient setup.
(defvar winner-dont-bind-my-keys)       ;set before winner.el defines it
(setq winner-dont-bind-my-keys t)
(require 'winner)
(winner-mode 1)

(keymap-set window-prefix-map "u" #'winner-undo)
(keymap-set window-prefix-map "U" #'winner-redo)
;; winner ships `winner-repeat-map' (`:repeat t', `<left>' / `<right>'), so
;; under repeat-mode the first undo above hands off to arrow keys to continue.

;; Frames are created and destroyed freely here (`M-<f4>' is `delete-frame' in
;; joe-core.el, and emacsclient makes new ones), so make that undoable too:
;; `C-x 5 u' restores the last deleted frame.
(undelete-frame-mode 1)

;;;; Layout transformations

;; Rotating and mirroring the whole frame. `transpose-frame' itself — which
;; reflects along the main diagonal — is rarely what you want; the other three
;; are. Pure elisp, no build step, so it installs from MELPA on every host.
(use-package transpose-frame
  :ensure t
  :bind (:map window-prefix-map
              ("r" . rotate-frame)
              ("|" . flop-frame)
              ("_" . flip-frame)))

;;;; Mouse

;; `mouse-autoselect-window' is already on (joe-ui.el). Once the hand is on the
;; mouse for something else, driving windows with it is the path of least
;; resistance, so make the rest of that path exist.
(context-menu-mode 1)

;; Bare `<mouse-9>' is `pdf-view-next-page' in joe-research.el; the meta
;; variant is free, and tearing a window off into its own frame is a natural
;; drag-like gesture.
(keymap-global-set "M-<mouse-9>" #'tear-off-window)

;;;; Ignoring windows entirely

;; The cheapest window switch is the one you do not make. Avy treats every
;; visible window as one pool of jump targets, so moving point across a window
;; boundary stops being a distinct action you have to think about.
;;
;; Free on the Nix hosts — avy is already pulled in as an ace-window dependency
;; (both come from `emacs-packages-deps'); `:ensure t' covers the others.
;;
;; `M-j' duplicates `C-M-j' (`default-indent-new-line') in stock Emacs, so it is
;; the cheapest usable key, and unlike `C-;' or `C-,' it is typeable on the
;; x270's console — the same constraint that moved embark to `C-c .' in
;; joe-completion.el.
(use-package avy
  :ensure t
  :custom
  (avy-all-windows t)
  :bind
  ("M-j" . avy-goto-char-timer))

;; `pop-global-mark' (C-x C-SPC) jumps back across buffers, but always in the
;; current window — so returning to a location that is already visible next
;; door duplicates it here instead of moving there. Routing it through
;; `display-buffer' makes it a window switcher as well as a mark ring.
(define-advice pop-global-mark (:around (pgm) joe/use-display-buffer)
  "Let `pop-global-mark' reuse a window already showing the target buffer."
  (cl-letf (((symbol-function 'switch-to-buffer) #'pop-to-buffer))
    (funcall pgm)))

;;;; Automatic window placement

;; popper used to live here, and was removed deliberately. Two reasons:
;;
;;   1. Its dismiss key was redundant. Every buffer it managed already binds
;;      `q' to `quit-window' — help-mode, compilation-mode, eshell and
;;      everything deriving from special-mode — so the popup-hiding half of
;;      popper duplicated a key the hand already knew.
;;   2. Its summon/cycle half (`C-`' / `M-`') went unused, and neither key is
;;      typeable on the x270 console anyway (see the kmscon note above), so
;;      the feature was never reachable from half this configuration's hosts.
;;
;; It also left `*Warnings*' half-managed: the diagnostics rule below owns that
;; buffer's *display*, but `"\\*Warnings\\*"' was in `popper-reference-buffers'
;; too, so popper *tracked* it as an open popup it could not actually place.
;; `C-`' and `M-`' therefore operated on a buffer popper did not control.
;;
;; What popper did genuinely provide was one placement policy for transient
;; buffers instead of a rule per package. That part is kept, expressed with the
;; built-in side-window system — which also hands back the banish key for free:
;; `C-x w s' (`window-toggle-side-windows', already on the window prefix map)
;; hides and restores every side window at once.
;;
;; `no-delete-other-windows' is what makes that division of labour hold, and it
;; is not optional: contrary to the usual claim that side windows are exempt
;; from `delete-other-windows', on Emacs 30.2 they are deleted along with
;; everything else — verified, twice, because the comment here originally
;; asserted the opposite. `window-side' governs *placement*, not survival. With
;; the parameter set, `C-x 1' collapses the working windows and leaves the
;; popups alone, and `C-x w s' is the only thing that dismisses them.

;; The diagnostics: they appear unbidden, they are read rather than worked in,
;; and they should never take over the frame. `no-other-window' keeps `C-x o'
;; out of them — there is nothing in a Warnings buffer to do.
(add-to-list 'display-buffer-alist
             '("\\*\\(Warnings\\|Compile-Log\\|Native-compile-Log\\)\\*"
               (display-buffer-in-side-window)
               (side . bottom)
               (slot . 1)
               (window-height . 0.25)
               (window-parameters . ((no-other-window . t)
                                     (no-delete-other-windows . t)))))

;; Transient output, which is the other half of what popper was covering.
;; `*Async Shell Command*' and `Output*' arrive unannounced and would otherwise
;; split a working window; `*Messages*' and `*Backtrace*' are summoned but are
;; still read-and-leave buffers. One shared slot, so they reuse a single window
;; rather than stacking side windows down the frame.
;;
;; Unlike the diagnostics above these stay selectable — no `no-other-window' —
;; because reading a backtrace means scrolling it.
(add-to-list 'display-buffer-alist
             '("\\*\\(Messages\\|Backtrace\\|Async Shell Command\\|eldoc\\)\\*\\|Output\\*\\'"
               (display-buffer-in-side-window)
               (side . bottom)
               (slot . 0)
               (window-height . 0.3)
               (window-parameters . ((no-delete-other-windows . t)))))

;; Left to stock `display-buffer' behaviour on purpose, having been popper's
;; before: help-mode and helpful-mode (navigated, not glanced at — and
;; `help-window-select' already governs them), compilation-mode (magit and the
;; mail-sync buffer manage their own, joe-tools.el / joe-mail.el),
;; eshell-mode (worked in, not read), and deadgrep-mode / rg-mode /
;; tmr-tabulated-mode (result lists you move through). If any of those starts
;; stealing a window it should get its own rule here, not a popup manager.

(provide 'joe-windows)
;;; joe-windows.el ends here
