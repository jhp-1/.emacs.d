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

(defvar joe/android-font-family "JetBrainsMono Nerd Font Mono"
  "Family for the `default' face on Android, or nil to leave it alone.
Android enumerates ~/fonts and nothing else, so without an installed
font Emacs falls back to Droid Sans Mono -- which is why the phone
looked nothing like the desktops.  The Nerd Font variant is chosen so
one file serves as both the text font and the source of the icon
glyphs; see `joe/android-nerd-font-p' in early-init.el.  Applied only
when `font-family-list' actually reports it, so an uninstalled font is
a no-op rather than an invisible-text bug.")

(defvar joe/android-font-height 140
  "Default face height (1/10 pt) on Android.
The desktop's 120 assumes a monitor at arm's length. Fontaine, which
sets that elsewhere, is skipped here -- see joe-ui.el.")

(defvar joe/android-auto-dark nil
  "When non-nil, let auto-dark follow the Android system theme.
Leave this off.  It was written as \"off until verified on the device\";
it has now been verified, on a Pixel 7a running Android 17, and it
CANNOT work from this APK.  Both ways of reading the system setting are
refused to an ordinary app UID:

    $ cmd uimode night
    SecurityException: ... requires android.permission.MODIFY_DAY_NIGHT_MODE
    $ settings get secure ui_night_mode
    SecurityException: getCurrentUser() ... requires INTERACT_ACROSS_USERS

Both permissions are signature-level, so `pm grant\=' will not hand them
over even with root on the device.  The port exposes no native
alternative either -- there is no appearance or night-mode function
anywhere in its `android-*\=' namespace.

So joe-ui.el uses `joe/solar-enable\=' on Android instead: sunrise/sunset
from built-in solar.el, the same switcher the console appliance uses.
It needs no permissions and no subprocess at all, which also disposes of
the battery question this variable used to raise.

Kept, rather than deleted, because the obstacle is a permission policy
and not a fact about Emacs: should a future release expose the ui mode
to apps, setting this to t re-enables the auto-dark path, which
joe-ui.el still configures with `auto-dark-detection-method\=' set to
`termux\=' (auto-dark will not pick that itself -- its detector requires
`system-type\=' to be gnu/linux, true of Emacs running INSIDE Termux but
not of this APK, where it is `android\=').")

(defvar joe/android-notifications nil
  "When non-nil, send `alert\=' notifications to Android's shade.
Off until verified on the device.  The Emacs side is solid -- the port
has a native `android-notifications-notify\=', so no Termux, no
termux-api and no D-Bus -- but the useful part is org-alert\='s repeating
timer, and a timer only fires while the process is alive.  Android doze
suspends backgrounded apps, so exempt Emacs from battery optimisation
and confirm alerts still arrive before relying on this.")

(defvar joe/android-bind-volume-keys t
  "When non-nil, bind volume-up to `joe/android-run-dwim'.
On by default, because it costs almost nothing. Emacs on Android
already reserves BOTH volume keys for itself -- that is the default of
`android-pass-multimedia-buttons-to-system', and it is how the port
provides a `C-g' without a keyboard -- so the volume rocker has already
stopped adjusting the volume the moment Emacs has focus, bound or not.
The manual's own suggestion for changing the volume here is to pull
down the notification shade, which takes focus away from Emacs.

Volume-DOWN is never bound whatever this is set to: pressed in rapid
succession it is the quit gesture, and it is the default of
`android-quit-keycode'. Only volume-up is claimed.

Set this to nil to leave both keys alone.")

;; Declared, not set. `text-conversion-style' is defined by the Android build's
;; C code and does not exist anywhere else, so without this the byte-compiler
;; reports it as a free variable on every other host. Same pattern as
;; `eshell-buffer-name' in joe-tools.el. `set-text-conversion-style' likewise
;; lives in textconv.c, which is only built for ports that have an IME.
(defvar text-conversion-style)
(declare-function set-text-conversion-style "textconv.c" (value &optional after))

(defvar-local joe/android--text-conversion-saved nil
  "Value `text-conversion-style' held before this buffer last toggled it.")

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

;;;; Touch selection
  ;; All three are off by default and all three are worth having. Selecting text
  ;; with a fingertip is the single clumsiest thing about this machine, and
  ;; character-granularity dragging on a phone is a losing game.
  (setq touch-screen-word-select t)        ; drag after a long press takes whole
                                           ; words, not characters
  (setq touch-screen-extend-selection t)   ; tap point or mark to resume a region
  (setq touch-screen-preview-select t)     ; show the selection in the echo area

;;;; repeat-mode
  ;; Built in since Emacs 28, and worth more here than on any desktop: after
  ;; `C-x o' a bare `o' switches windows again, after `C-x {' a bare `{' keeps
  ;; resizing. Every repeat is one modifier-bar round trip -- tap Ctrl, tap x,
  ;; tap o -- that does not have to happen.
  (repeat-mode 1)

  ;; Re-applied on every theme activation, not set once. joe-ui.el loads a
  ;; theme on a later idle timer than this file, and <f8> loads another every
  ;; time it is pressed; a theme that specifies `default' at all would silently
  ;; take the height back to its own. Same reasoning as the appliance's face
  ;; hooks in joe-ui.el.
  (defun joe/android-apply-font-height (&rest _)
    "Set the `default' face to `joe/android-font-height'.
Also set the family to `joe/android-font-family' when that font is
actually installed, so the phone is not left on Android's fallback."
    (set-face-attribute 'default nil :height joe/android-font-height)
    (when (and joe/android-font-family
               (member joe/android-font-family (font-family-list)))
      (set-face-attribute 'default nil :family joe/android-font-family)))
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
  ;;
  ;; `set-text-conversion-style', NOT `setq-local'. Its whole job over a plain
  ;; assignment is the second half: after setting the variable it forces the
  ;; input method in any window showing this buffer to stop and restart itself.
  ;; A bare `setq-local' changes what redisplay will do NEXT time it reconsiders
  ;; the buffer, which for a toggle you just pressed is not now -- the IME keeps
  ;; swallowing your keys and the command looks broken. Its own docstring warns
  ;; the reset is expensive and that you should normally set the variable before
  ;; the buffer is displayed; that caveat is about mode setup, not about an
  ;; explicit toggle a human just asked for.
  ;;
  ;; The old value is saved and restored rather than a constant being written
  ;; back. `text-mode' sets this to t and the minibuffer wants `action' (which
  ;; makes the IME's Go/Done key run the buffer's action instead of inserting a
  ;; newline), so there is no single correct "on" value to hardcode.
  (defun joe/android-toggle-text-conversion ()
    "Toggle Android text conversion in the current buffer.
Off means the input method sends ordinary key events, so `org-mode'
speed keys and other single-letter bindings fire instead of inserting
themselves -- at the price of predictive and swipe input. Turning it
back on restores whatever style this buffer had before."
    (interactive)
    (if text-conversion-style
        (progn
          (setq joe/android--text-conversion-saved text-conversion-style)
          (set-text-conversion-style nil))
      (set-text-conversion-style (or joe/android--text-conversion-saved t)))
    (message "Text conversion %s"
             (if text-conversion-style
                 "on — normal typing"
               "off — key events, so speed keys fire")))

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

  ;; Dired needs no help here, contrary to the obvious worry that the APK ships
  ;; no `ls'. Emacs already handles it: ls-lisp.el defaults
  ;; `ls-lisp-use-insert-directory-program' to
  ;;     (not (memq system-type '(ms-dos windows-nt android)))
  ;; so on Android the listing is generated in Elisp and no subprocess is
  ;; involved, exactly as on Windows. Forcing that here would be redundant, and
  ;; keying it off (executable-find "ls") would be actively wrong -- with Termux
  ;; installed `ls' IS found, and Emacs still uses ls-lisp.
  ;;
  ;; What IS lost is `--group-directories-first'. ls-lisp sanitises long GNU
  ;; options away (it keeps only those with a short equivalent), so the flag is
  ;; silently dropped rather than misparsed -- no breakage, just ungrouped
  ;; listings. `ls-lisp-dirs-first' is its native equivalent and restores the
  ;; desktop behaviour.
  ;;
  ;; `dired-listing-switches' is deliberately NOT set here. It has one canonical
  ;; assignment, in joe-files.el, which carries the Android branch; setting it
  ;; from here too would be a race, since that file loads on a later idle timer
  ;; and would simply overwrite this.
  (with-eval-after-load 'ls-lisp
    (setq ls-lisp-dirs-first t)
    ;; ls-lisp only consults `ls-lisp-format-time-list' when this is non-nil;
    ;; left at its default it formats times from the locale instead, which here
    ;; produced "09-05 13:14" where GNU ls (and therefore every desktop dired)
    ;; gives "Sep  5 13:14". The variable is named for localisation but the
    ;; effect is the opposite of what that suggests: setting it is what pins
    ;; the format to the list, and the list already holds the conventional
    ;; "%b %e %H:%M" / "%b %e  %Y" pair.
    (setq ls-lisp-use-localized-time-format t))

  ;; Makes Emacs appear in Android's "open with" dialog for text files, which
  ;; dispatch through emacsclient. Cheap, and the only way to get a file from
  ;; another app into this one.
  (require 'server)
  (unless (server-running-p)
    (server-start))

;;;; Notifications
  ;; The port defines `android-notifications-notify' in C (src/androidselect.c),
  ;; so the notification shade is reachable with no Termux, no termux-api and no
  ;; D-Bus. It takes :title :body :urgency :icon :group :replaces-id :actions
  ;; :timeout :resident :on-action :on-close -- a notification can carry buttons
  ;; that call back into Emacs.
  ;;
  ;; org-alert drives the `alert' package, and `alert' takes custom styles, so
  ;; the whole job is one style that forwards to that function. See
  ;; `joe/android-notifications' for why this is off by default: the Emacs half
  ;; is sound, and Android doze is the part that is not.
  (declare-function android-notifications-notify "androidselect.c")
  (declare-function alert-define-style "alert")
  (declare-function org-alert-enable "org-alert")
  (defvar alert-default-style)

  (defun joe/android--alert-notifier (info)
    "Send the `alert' plist INFO to the Android notification shade."
    (android-notifications-notify
     :title (or (plist-get info :title) "Emacs")
     :body (or (plist-get info :message) "")
     ;; `alert' severities are urgent/high/moderate/normal/low/trivial;
     ;; `android-notifications-notify' takes low/normal/critical.
     :urgency (pcase (plist-get info :severity)
                ((or 'urgent 'high) 'critical)
                ((or 'low 'trivial) 'low)
                (_ 'normal))
     ;; One group, so a run of agenda alerts stacks instead of filling the
     ;; shade with separate cards.
     :group "org-agenda"))

  (defun joe/android-enable-notifications ()
    "Route `alert' to Android, and start org-alert's timer.
Deferred rather than run at load: `org-alert' pulls in org, and requiring
org eagerly would undo the idle-timer staging in init.el."
    (interactive)
    ;; Imperative install, not `:ensure t' inside a guard -- use-package
    ;; resolves :ensure at macro-expansion time, so a guarded use-package form
    ;; installs the package on every host that byte-compiles this file. Same
    ;; reasoning as the notmuch/pdf-tools/jinx block in joe-core.el.
    (unless (package-installed-p 'org-alert)
      (unless package-archive-contents (package-refresh-contents))
      (package-install 'org-alert))
    (require 'org-alert)                        ; pulls in `alert' as well
    (alert-define-style 'android
                        :title "Android notification shade"
                        :notifier #'joe/android--alert-notifier)
    (setq alert-default-style 'android)
    (setq org-alert-interval 300)                ; recheck every five minutes
    (setq org-alert-notify-cutoff 10)            ; warn ten minutes ahead
    (setq org-alert-notify-after-event-cutoff 30); and stop half an hour after
    (org-alert-enable)
    (message "Android notifications enabled"))

  (when joe/android-notifications
    (run-with-idle-timer 2 nil #'joe/android-enable-notifications))

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

  ;; No need to touch `android-pass-multimedia-buttons-to-system': its default
  ;; is nil, which is the value that makes Emacs keep the volume keys. Setting
  ;; it non-nil would hand them to the system and cost the quit gesture. An
  ;; earlier revision set it to nil "so Emacs can see the keys", which was a
  ;; no-op resting on the variable meaning the opposite of what it does.
  (when joe/android-bind-volume-keys
    (keymap-global-set "<volume-up>" #'joe/android-run-dwim))

;;;; Notes on things deliberately NOT configured here
  ;; - Display depth, for e-ink devices (Boox and friends), where Android
  ;;   reports no monochrome visual class and font-lock colours come out with
  ;;   poor contrast. 2-8 for grayscale, 1 for monochrome. Two names are in
  ;;   circulation and they disagree: the Emacs manual (both the emacs-30
  ;;   branch and master) documents `android-display-planes', while the port's
  ;;   own SourceForge FAQ says `android-display-depth'. Check which one your
  ;;   build actually has with `C-h v' before setting either. Irrelevant on an
  ;;   ordinary phone.
  ;; - `android-intercept-control-space': only needed if the IME swallows
  ;;   `C-SPC' before Emacs sees it. Left at its default until it bites.
  ;; - Fonts: drop .ttf files in ~/fonts -- NOT a subdirectory, that tree is
  ;;   not searched recursively. Ignore Options -> Set Default Font, an X-era
  ;;   vestige that lists fonts which are not present on Android; use
  ;;   `set-frame-font' or Customize.
  )

(provide 'joe-android)
;;; joe-android.el ends here
