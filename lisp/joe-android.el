;;; joe-android.el --- The Android port: touchscreen input and storage -*- lexical-binding: t; -*-

;; Everything here is for GNU Emacs's native Android port (the APK, not Termux
;; running a terminal Emacs) used WITHOUT a physical keyboard. The whole file
;; is inside one `when', so it is inert on every other machine; init.el does
;; not load it elsewhere either.
;;
;; The premise is that a phone has no Ctrl, no Alt, no Escape and no reliable
;; way to send a key sequence at all, so the tool bar, the modifier bar and the
;; menu bar stop being decoration and become the input device. Sizing them
;; properly is not cosmetics.
;;
;; Scope on this machine is deliberately two things -- reading and editing org,
;; and reading the web in eww. init.el's Android branch loads only the modules
;; those need. See README ("Android") for what is left out and why.

;;;; Tuning knobs
;; defvars rather than hardcoded values because both are matters of taste and
;; of which phone this is running on, and editing elisp on glass is miserable:
;; `M-x set-variable' from the menu bar beats finding this file.

(defvar joe/android-font-height 140
  "Default face height (1/10 pt) on Android.
The desktop's 120 assumes a monitor at arm's length. Fontaine, which
sets that elsewhere, is skipped here -- see joe-ui.el.")

(defvar joe/android-bind-volume-keys nil
  "When non-nil, bind volume-up to `joe/android-run-dwim'.
Off by default, and the trade is worth stating plainly: Emacs and the
system cannot both have the key. Turning this on means the volume
rocker no longer changes the volume while Emacs has focus. Volume-DOWN
is never bound here whatever this is set to -- pressing it in rapid
succession is the port's `C-g', which is not a gesture to lose.")

;; Declared, not set. These are defined by the Android build's C code and do
;; not exist anywhere else, so without this the byte-compiler reports them as
;; free variables on every other host -- and, worse, `setq-local' on an
;; undeclared symbol would bind lexically rather than buffer-locally under
;; `lexical-binding'. Same pattern as `eshell-buffer-name' in joe-tools.el.
(defvar text-conversion-style)
(defvar android-pass-multimedia-buttons-to-system)

(when (bound-and-true-p joe/android-p)

;;;; The no-keyboard core
  ;; `modifier-bar-mode' (Emacs 30+) is the load-bearing one: a second row of
  ;; buttons that apply Ctrl/Meta/Super/Hyper/Alt/Shift to the NEXT event Emacs
  ;; reads. It exists precisely because phones have no modifier keys. Tapping
  ;; one also momentarily suspends text conversion (see below) and raises the
  ;; on-screen keyboard, which is the designed path for typing a modified
  ;; sequence inside an editable buffer.
  (when (fboundp 'modifier-bar-mode)   ; Emacs 30+
    (modifier-bar-mode 1))
  (tool-bar-mode 1)
  (menu-bar-mode 1)
  ;; Long-press becomes a real context menu.
  (context-menu-mode 1)

  ;; Buttons belong under the thumbs, not above the text. `tool-bar-position'
  ;; was implemented on non-GTK systems at an Android user's request for exactly
  ;; this. `menu-bar-set-tool-bar-position' sets `default-frame-alist' as well as
  ;; the live frame, so later frames inherit it.
  (if (fboundp 'menu-bar-set-tool-bar-position)
      (menu-bar-set-tool-bar-position 'bottom)
    (set-frame-parameter nil 'tool-bar-position 'bottom))

  ;; Emacs hides the on-screen keyboard whenever the current buffer is
  ;; read-only, to save screen space. That is a sound default on a desktop and
  ;; a disaster here: it is what makes eww's URL prompt, dired and the agenda
  ;; feel broken -- you tap, nothing appears, there is no other way to type.
  (setq touch-screen-display-keyboard t)

  ;; FAQ 22 in the port's README: tool bar button margins do not scale with
  ;; display density, so the buttons come out undersized on a high-DPI phone.
  ;; Raise it until they are thumb-sized. This matters more than it sounds when
  ;; the tool bar IS the keyboard.
  (setq tool-bar-button-margin 12)

  ;; Re-applied on every theme activation, not set once. joe-ui.el loads a
  ;; theme on a later idle timer than this file, and <f8> loads another every
  ;; time it is pressed; a theme that specifies `default' at all would silently
  ;; take the height back to its own. Same reasoning as the appliance's face
  ;; hooks in joe-ui.el.
  (defun joe/android-apply-font-height (&rest _)
    "Set the `default' face to `joe/android-font-height'."
    (set-face-attribute 'default nil :height joe/android-font-height))
  (joe/android-apply-font-height)
  (add-hook 'enable-theme-functions #'joe/android-apply-font-height)

;;;; Text conversion
  ;; The single biggest behavioural difference on this port, and the cause of
  ;; most "my keybindings don't work" reports. Android input methods do not
  ;; send key events at all: they call Emacs's buffer-editing primitives
  ;; directly, a mechanism called text conversion. Emacs then infers what
  ;; electric-indent, electric-pair and auto-fill should have done by analysing
  ;; the edit after the fact.
  ;;
  ;; The consequence is that anything reading raw key events -- evil, meow, and
  ;; org's own speed keys -- cannot see your typing while the IME is driving:
  ;; the keystrokes arrive as inserted text instead of as commands. Nothing is
  ;; misconfigured when that happens; it is the design.
  ;;
  ;; Two escape hatches exist: `overriding-text-conversion-style' (global) and
  ;; `text-conversion-style' (buffer-local). Setting the latter to nil puts the
  ;; IME into a dumb mode that sends real key events, at the cost of predictive
  ;; and swipe typing. That is exactly the trade you want for a burst of
  ;; navigation and exactly the wrong one for writing a paragraph, so it is a
  ;; toggle rather than a setting.
  (defun joe/android-toggle-text-conversion ()
    "Toggle Android text conversion in the current buffer.
Off means the input method sends ordinary key events, so `org-mode'
speed keys and other single-letter bindings fire instead of inserting
themselves -- at the price of predictive input. On restores normal
typing.

If the input method does not notice the change immediately, toggling
the on-screen keyboard off and on again forces it to re-read the state."
    (interactive)
    (setq-local text-conversion-style
                (if text-conversion-style nil 'action))
    (message "Text conversion %s%s"
             (if text-conversion-style "on (typing)" "off (key events)")
             (if text-conversion-style "" " — speed keys live")))

  (keymap-global-set "C-c A t" #'joe/android-toggle-text-conversion)

  ;; `org-use-speed-commands' is already t (joe-org-notes.el). It is genuinely
  ;; the largest ergonomic win available here -- n/p/f/b/t/c on a bare letter at
  ;; the start of a headline, no modifier at all -- but per the above it only
  ;; works with text conversion off. Hence the toolbar button below.

;;;; Storage
  ;; Notes live under Termux's home; see the long note on `joe/notes-dir' in
  ;; joe-core.el for why not /content. Nothing to do here but land somewhere
  ;; useful at startup instead of the scratch buffer joe-core.el chooses.
  (setq initial-buffer-choice
        (lambda ()
          (if (file-directory-p joe/notes-dir)
              (dired-noselect joe/notes-dir)
            (get-buffer-create "*scratch*"))))

  ;; Dired shells out to `ls', and the APK ships no userland: without Termux on
  ;; `exec-path' there is no `ls' at all and every dired buffer fails outright.
  ;; ls-lisp reimplements the listing in Elisp -- slower, and entirely adequate
  ;; for browsing a notes directory.
  ;;
  ;; `dired-listing-switches' is NOT set here. It is a defcustom with one
  ;; canonical assignment, in joe-files.el, which already drops
  ;; --group-directories-first (a GNU coreutils flag ls-lisp does not parse) on
  ;; Android. Setting it from here as well would be a race: joe-files.el loads
  ;; on a later idle timer than this file and would simply overwrite it.
  ;; `ls-lisp-dirs-first' is the ls-lisp equivalent of that flag.
  (unless (executable-find insert-directory-program)
    (require 'ls-lisp)
    (setq ls-lisp-use-insert-directory-program nil)
    (setq ls-lisp-dirs-first t))

  ;; Makes Emacs appear in Android's "open with" dialog for text files, which
  ;; dispatch through emacsclient. Cheap, and the only way to get a file from
  ;; another app into this one.
  (require 'server)
  (unless (server-running-p)
    (server-start))

;;;; Tool bar
  ;; `M-x' is reachable from the menu bar (Edit -> Execute Command) and always
  ;; will be, so these are not about possibility but about tap count: the
  ;; things this phone exists to do, one thumb-press away.
  ;;
  ;; `tool-bar-add-item' takes (ICON COMMAND KEY . PROPS) and appends to the
  ;; global tool bar map, after the stock buttons. The stock ones are kept --
  ;; open/save/undo/cut/copy/paste with no keyboard are worth their width.
  ;;
  ;; Icon names are files in etc/images in the Emacs tree; the ones chosen here
  ;; are stock Emacs toolbar icons, so they should all resolve. If one ever
  ;; does not, the button still works and still shows its `:help' on long
  ;; press, it just draws blank -- and `:label' is supplied so that setting
  ;; `tool-bar-style' to `both' or `text' gives readable buttons instead.
  (dolist (item '(("index"  execute-extended-command joe-tb-M-x     "M-x")
                  ("search" eww                      joe-tb-eww     "Web (eww)")
                  ("jump-to" org-agenda              joe-tb-agenda  "Agenda")
                  ("new"    org-capture              joe-tb-capture "Capture")
                  ("lock"   joe/android-toggle-text-conversion
                   joe-tb-textconv "Speed keys")))
    (pcase-let ((`(,icon ,command ,key ,label) item))
      (tool-bar-add-item icon command key :help label :label label)))

;;;; Volume keys
  ;; Two hardware buttons are the only real keys on the device. One of them is
  ;; already spoken for as `C-g' (`android-quit-keycode', volume-down, pressed
  ;; in rapid succession), so this is about the other one.
  ;;
  ;; Dispatching on `major-mode' rather than binding a single command: one
  ;; button covering "do the obvious thing here" is worth far more than one
  ;; button covering one command. `C-h k' on a hardware key reports what Emacs
  ;; calls it, if you want to bind others.
  (defun joe/android-run-dwim ()
    "Do the obvious thing for the current buffer.
Org: `C-c C-c' on whatever point is on -- update a dynamic block,
toggle a checkbox, set tags, evaluate a source block. eww: reload.
Dired: visit the file at point."
    (interactive)
    (cond ((derived-mode-p 'org-mode)
           (call-interactively (or (local-key-binding (kbd "C-c C-c"))
                                   #'org-ctrl-c-ctrl-c)))
          ((derived-mode-p 'eww-mode) (eww-reload))
          ((derived-mode-p 'dired-mode) (dired-find-file))
          ((derived-mode-p 'emacs-lisp-mode)
           (save-buffer)
           (call-interactively #'eval-defun))
          (t (message "No action defined for %s" major-mode))))

  (when joe/android-bind-volume-keys
    ;; Emacs only sees these once it stops handing multimedia keys back to the
    ;; system.
    (setq android-pass-multimedia-buttons-to-system nil)
    (keymap-global-set "<volume-up>" #'joe/android-run-dwim))

;;;; Notes on things deliberately NOT configured here
  ;; - `android-display-depth': for e-ink devices (Boox and friends), where
  ;;   Android reports no monochrome visual class and font-lock colours come
  ;;   out with poor contrast. Set it to 2-8 for grayscale, 1 for monochrome.
  ;;   Irrelevant on an ordinary phone.
  ;; - `android-intercept-control-space': only needed if the IME swallows
  ;;   `C-SPC' before Emacs sees it. Left at its default until it bites.
  ;; - Fonts: drop .ttf files in ~/fonts -- NOT a subdirectory, that tree is
  ;;   not searched recursively. Ignore Options -> Set Default Font, an X-era
  ;;   vestige that lists fonts which are not present on Android; use
  ;;   `set-frame-font' or Customize.
  )

(provide 'joe-android)
;;; joe-android.el ends here
