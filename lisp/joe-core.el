;;; joe-core.el --- Core Emacs configuration -*- lexical-binding: t; -*-

;;;; Package Management
(require 'package)
(setq package-check-signature nil)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
(add-to-list 'package-archives '("nongnu" . "https://elpa.nongnu.org/nongnu/"))
;; No `package-initialize' call: since Emacs 27 `package-activate-all' runs
;; automatically before init.el (`package-enable-at-startup' is left at t), so
;; an explicit call here activated every package a second time. The archives
;; above do not need it — they are only consulted when installing or refreshing.

;;;; Use-package
(require 'use-package)
(setq use-package-enable-imenu-support t)
(setq use-package-always-ensure t)
(setq use-package-always-demand nil)

;; notmuch, pdf-tools and jinx are `:ensure nil' because on Nix hosts Emacs
;; provides them itself (see joe/nix-emacs-p in early-init.el). On every other
;; host they must still come from MELPA exactly as before — install them here so
;; `:ensure nil' does not leave them missing. This mirrors the old `:ensure t'
;; (which installs at config time regardless of :defer/:if), so behaviour on
;; non-Nix hosts is unchanged.
;;
;; Android is excluded for the opposite reason: none of the three can work
;; there. pdf-tools needs an epdfinfo built from C, jinx a jinx-mod.so, and
;; notmuch's elisp is useless without the notmuch CLI and a local maildir. The
;; APK has no compiler, so this would spend a phone's startup downloading three
;; packages that then fail at first use. Every consumer of them is already
;; guarded -- jinx on `executable-find', pdf-tools and notmuch in modules that
;; init.el does not load on Android at all.
(unless (or (bound-and-true-p joe/nix-emacs-p)
            (bound-and-true-p joe/android-p))
  (dolist (pkg '(notmuch pdf-tools jinx))
    (unless (package-installed-p pkg)
      (unless package-archive-contents (package-refresh-contents))
      (package-install pkg))))

;; Disable automatic package refresh on startup
(setq package-auto-update-interval 0)
(setq package-check-update-on-load nil)

;;;;; compile-angel
;; Disabled outright on noexec-home hosts rather than tuned. Two distinct
;; failures came from it on the x270:
;;   1. It calls native-compile EXPLICITLY, ignoring
;;      `native-comp-jit-compilation', so it emitted .eln files into a noexec
;;      /home that then could not be dlopen'd ("failed to map segment from
;;      shared object") - cascading into use-package failing to parse citar,
;;      zotra, pdf-tools and everything else touching the affected files.
;;   2. Even with native compilation off, its byte-compilation of magit
;;      produced a stale .elc calling `magit-auto-revert-mode--after-load',
;;      breaking magit on every startup.
;; package.el already byte-compiles on install, so the value it adds here is
;; small and the failure modes are not. It stays fully enabled elsewhere.
;;
;; Gated on `joe/noexec-home-p', not on the appliance: failure 1 is a property
;; of a noexec /home, so it applies verbatim to the nixdesktop. Note that
;; setting `native-comp-jit-compilation' to nil does NOT cover this — the whole
;; point of failure 1 is that compile-angel ignores that variable.
;;
;; Also off on Android, for cost rather than correctness: byte-compiling every
;; library on load is minutes of phone CPU (and battery) to save a fraction of
;; a second of load time, and package.el's own compile-on-install already
;; covers the packages that matter. Whether failure 1 can arise there depends
;; on whether the APK carries libgccjit — check `native-comp-available-p' on
;; the device rather than assuming; it does not change the decision here.
(use-package compile-angel
  :ensure t
  :unless (or (bound-and-true-p joe/noexec-home-p)
              (bound-and-true-p joe/android-p))
  :demand t
  :config
  (compile-angel-on-load-mode)
  (add-hook 'emacs-lisp-mode-hook #'compile-angel-on-save-local-mode))

;;;;; Byte-compile packages out of process
;; `package--compile' runs `byte-recompile-directory' inside the *running*
;; Emacs. Macros are expanded at compile time from whatever is already resident
;; in that image, and `require' is a no-op once a feature is loaded —
;; `package-activate-1' reloads only the package being installed, never the
;; dependencies it is about to be compiled against. So upgrading a package
;; together with a dependency whose macros it uses compiles it against the OLD
;; macros.
;;
;; Not hypothetical. magit and cond-let were upgraded in one session on
;; 2026-08-08, and magit-git.elc came out with `cond-let--thread$' emitted as a
;; FUNCTION call, leaving `$' as a free variable reference, because the cond-let
;; resident in that Emacs predated that macro. Every `magit-status' then died
;; with "void-variable $" inside `magit-config-get-from-cached-list', five
;; frames down in the status headers.
;;
;; Nothing self-heals from this. The .elc is newer than its .el, so
;; `load-prefer-newer' sees nothing wrong, and restarting cannot help — the bad
;; expansion is baked into the file. Only a forced recompile fixes it, which is
;; what `joe/recompile-package' below is for.
;;
;; Compiling in a fresh `emacs -Q --batch' removes the class outright: the
;; subprocess loads exactly the versions that are on disk now. This is the same
;; reasoning behind the `subemacs' package and behind auto-compile's warning
;; that in-process compilation hides dependency problems.
(defun joe/byte-compile-package-cleanly (dir &optional ignore-regexps)
  "Byte-compile every library under DIR in a clean Emacs subprocess.
IGNORE-REGEXPS is bound to `byte-compile-ignore-files' there, so
.elpaignore is still honoured. Return non-nil if the subprocess ran and
exited successfully."
  (let ((emacs (expand-file-name invocation-name invocation-directory)))
    (and
     (file-executable-p emacs)
     (eq 0 (call-process
            emacs nil (get-buffer-create "*package-compile*") nil
            "-Q" "--batch" "--eval"
            (prin1-to-string
             `(progn
                ;; Byte-compilation only. `-Q' skips early-init.el, so the
                ;; native-comp guards there are absent, and a JIT .eln would
                ;; land in an eln-cache that a noexec /home cannot dlopen from
                ;; — the exact x270 failure documented above.
                (setq native-comp-jit-compilation nil
                      native-comp-enable-subr-trampolines nil)
                (require 'package)
                ;; A stale quickstart file would defeat the whole point.
                (setq package-user-dir ,package-user-dir
                      package-quickstart nil)
                (package-activate-all)
                (let ((byte-compile-ignore-files ',ignore-regexps))
                  (byte-recompile-directory ,dir 0 t)))))))))

(defun joe/package--compile-cleanly (fn pkg-desc)
  "Compile PKG-DESC out of process, falling back to FN.
Intended as :around advice for `package--compile'."
  (let ((dir (package-desc-dir pkg-desc)))
    (unless (and (stringp dir)
                 (file-directory-p dir)
                 (joe/byte-compile-package-cleanly
                  dir (package--parse-elpaignore pkg-desc)))
      (funcall fn pkg-desc))))

(advice-add 'package--compile :around #'joe/package--compile-cleanly)

(defun joe/recompile-package (name)
  "Force a clean recompile of the installed package NAME.
Repairs a package whose .elc was compiled against stale macros. The
symptom is a `void-variable' or `void-function' error naming a macro (or
a macro's anaphoric variable, such as cond-let's `$') from one of its
dependencies, raised from a package that is otherwise up to date."
  (interactive
   (list (intern (completing-read "Recompile package: "
                                  (mapcar #'car package-alist) nil t))))
  (let ((desc (car (alist-get name package-alist))))
    (unless desc
      (user-error "Package `%s' is not installed" name))
    (if (joe/byte-compile-package-cleanly
         (package-desc-dir desc) (package--parse-elpaignore desc))
        (message "Recompiled %s — restart Emacs to load the new byte code" name)
      (user-error "Could not compile `%s' out of process" name))))

;; The notes silo ships a .dir-locals.el with two `eval' forms, so Emacs
;; prompts about unsafe local variables on every org file it opens. These were
;; read straight out of that file, so they match byte-for-byte - a
;; hand-transcribed near-miss would silently keep prompting.
(dolist (v '((eval . (progn (visual-line-mode 1) (auto-fill-mode -1)))
             (eval . (setq-local denote-directory
                                 (or (locate-dominating-file default-directory
                                                             ".dir-locals.el")
                                     default-directory)))))
  (add-to-list 'safe-local-variable-values v))
;;;; auto-package-update
(use-package auto-package-update
  :ensure t
  :defer t
  :config
  (setq auto-package-update-delete-old-versions t)
  (setq auto-package-update-interval 7))

;;;; pdf-view midnight colors
;; Shared by joe-ui.el (auto-dark theme switches) and joe-research.el (pdf open).
(defun joe--sync-pdf-midnight-colors (&rest _)
  "Match `pdf-view-midnight-colors' to the current frame's `default' face.
Reads the `default' face rather than frame parameters, which return the
`unspecified-fg'/`unspecified-bg' symbols (not colors) on the daemon's
initial non-graphical frame.  Skips the update unless both are real colors."
  (let ((fg (face-attribute 'default :foreground))
        (bg (face-attribute 'default :background)))
    (when (and (stringp fg) (stringp bg))
      (setq-default pdf-view-midnight-colors (cons fg bg)))))

;;;; Cross-platform path constants
;; Used by joe-org-notes.el, joe-research.el etc. so they don't hardcode drive letters.
;; NB: the non-Windows branch assumed WSL (/mnt/d/...). On the x270 appliance
;; that path does not exist, and `directory-files-recursively' on a missing
;; directory signals - which aborted org's whole :config block and left
;; `org-capture-templates' void, cascading into zotra/citar failures.
;; The nixdesktop branches are the old Windows D: drive, carried over intact but
;; mounted at /mnt/media rather than given a drive letter. Without them these
;; fall through to the WSL default /mnt/d/... , which does not exist there —
;; costing the agenda (the `file-directory-p' guard below catches that) and
;; silently pointing `denote-directory' at a nonexistent tree (which it does not).
;; Keyed on `joe/nix-emacs-p' the same way the appliance keys on its own
;; constant: it identifies the machine, which is what actually decides the path.
;;
;; Notes and Texts have since moved off that drive onto the encrypted SSD: they
;; are small but latency-sensitive (org-agenda opens ~147 files at startup, and
;; pdf-tools does random reads), and /mnt/media is a spinning disk mounted
;; noexec with no POSIX permission bits — which also meant git could not track a
;; mode on Notes. Syncthing follows them by folder ID, so its config was
;; repointed rather than the files re-shared. Noises is bulk audio and stays put.
;; Symlinks remain at the old /mnt/media paths, so a stale reference still works.
;;
;; The Android branches prefer a directory inside TERMUX's home rather than
;; Emacs's own (/data/data/org.gnu.emacs/files) or a Storage Access Framework
;; mount under /content. That is not a stylistic choice:
;;
;;   - /content is served entirely by Emacs's own file primitives, so a
;;     SUBPROCESS started there silently gets Emacs's home as its working
;;     directory instead. That is why ripgrep and git return nothing on a
;;     Nextcloud/Syncthing folder mounted that way. It is also very slow --
;;     minutes to build an agenda, on Google's document-provider IPC.
;;   - Termux's home is an ordinary Unix directory that both Emacs and its
;;     subprocesses can read, and Syncthing can be run inside Termux to keep it
;;     in step with the desktops. See README.
;;
;; Falls back to a directory in Emacs's own home when Termux is absent, so a
;; non-`termux/' APK still gets a valid (if subprocess-poor) path rather than
;; one that cannot exist. `org-agenda-files' and `denote-directory' are then
;; pointed at whatever this resolves to, and org's own `file-directory-p' guard
;; (joe-org-notes.el) covers the case where neither has been created yet.
(defun joe/android-dir (name)
  "Return the Android path for a sync directory called NAME.
Termux's home when it is reachable, else Emacs's own home."
  (let ((termux (expand-file-name (concat "Sync/" name)
                                  joe/android-termux-home)))
    (if (file-directory-p joe/android-termux-home)
        termux
      (expand-file-name (concat "~/" name)))))

(defconst joe/notes-dir
  (cond ((bound-and-true-p joe/console-appliance-p) (expand-file-name "~/notes"))
        ((bound-and-true-p joe/android-p) (joe/android-dir "Notes"))
        ((bound-and-true-p joe/nix-emacs-p) (expand-file-name "~/Notes"))
        ((eq system-type 'windows-nt) "d:/Notes")
        (t "/mnt/d/Notes"))
  "Root directory for Denote notes.")

(defconst joe/texts-dir
  (cond ((bound-and-true-p joe/console-appliance-p) (expand-file-name "~/texts"))
        ((bound-and-true-p joe/android-p) (joe/android-dir "Texts"))
        ((bound-and-true-p joe/nix-emacs-p) (expand-file-name "~/Texts"))
        ((eq system-type 'windows-nt) "d:/Texts")
        (t "/mnt/d/Texts"))
  "Root directory for PDFs and bibliography.")

(defconst joe/noises-dir
  (cond ((bound-and-true-p joe/console-appliance-p) (expand-file-name "~/noises"))
        ((bound-and-true-p joe/android-p) (joe/android-dir "Noises"))
        ((bound-and-true-p joe/nix-emacs-p) "/mnt/media/Noises")
        ((eq system-type 'windows-nt) "d:/Noises")
        (t "/mnt/d/Noises"))
  "Root directory for ambient/background sound files.")

;;;; WSL <-> Windows path translation helpers
(defun joe/wsl-to-win-path (path)
  "Convert a WSL path like /mnt/d/foo to a Windows path d:/foo."
  (replace-regexp-in-string
   "^/mnt/\\([a-z]\\)/"
   (lambda (_m) (concat (upcase (match-string 1)) ":/"))
   path))

(defun joe/win-to-wsl-path (path)
  "Convert a Windows path like d:/foo to a WSL path /mnt/d/foo."
  (replace-regexp-in-string
   "\\([A-Za-z]\\):[\\/]"
   (lambda (_m) (concat "/mnt/" (downcase (match-string 1)) "/"))
   path))

;;;; Environment settings
;; On Windows, PATH and exec-path are managed explicitly in joe-tools.el.
;; These Linux-only tweaks add the active nvm Node and ~/.local/bin to the
;; path for Linux/WSL Emacs instances only.
(when (memq system-type '(gnu gnu/linux gnu/kfreebsd))
  ;; Dynamically find the newest installed nvm Node instead of a hardcoded version.
  (let* ((nvm-root (expand-file-name "~/.nvm/versions/node"))
         (node-bin
          (when (file-directory-p nvm-root)
            (let ((versions (sort (directory-files nvm-root t "^v" t) #'string>)))
              (when versions
                (expand-file-name "bin" (car versions)))))))
    (dolist (dir (delq nil (list node-bin (expand-file-name "~/.local/bin"))))
      (setenv "PATH" (concat dir ":" (getenv "PATH")))
      (add-to-list 'exec-path dir))))

;;;; Custom lisp code
(let ((default-directory (expand-file-name (concat user-emacs-directory "lisp"))))
  (normal-top-level-add-subdirs-to-load-path))

;;;; Files and Buffers
;;;; Files
;; Disable emacs backup
(setq create-lockfiles nil
      auto-save-default nil
      make-backup-files nil)
;; savehist
(savehist-mode t)

;; Save bookmarks after every change (default only saves on clean exit,
;; which loses them when the daemon is killed abruptly)
(setq bookmark-save-flag 1)

;; Real autosave
(auto-save-visited-mode 1)
(setq auto-save-visited-interval 60)

;; Set custom file
(setq custom-file  (concat user-emacs-directory "custom.el"))
(load custom-file 'noerror)

;; Automatically update file s after external changes
(use-package autorevert
  :ensure nil
  :hook (after-init . global-auto-revert-mode))

(use-package recentf
  :ensure nil
  :hook (after-init . recentf-mode)
  :custom
  (recentf-filename-handlers '(abbreviate-file-name))
  (recentf-max-saved-items 400)
  (recentf-max-menu-items 400)
  ;; Not a literal "~/.emacs.d/recentf": joe-tools.el resets HOME on Windows,
  ;; and this file is loaded first, so the tilde would expand against the old
  ;; HOME and strand the history somewhere else.
  (recentf-save-file (locate-user-emacs-file "recentf")))

;;;; Global keybindings and miscellaneous settings
(keymap-global-set "<f7>" (lambda ()
	    (interactive)
	    (hide-mode-line-mode 'toggle)))
(keymap-global-set "M-<f4>" 'delete-frame)
(keymap-global-set "<f5>" 'call-last-kbd-macro)
(put 'narrow-to-region 'disabled nil)
(put 'downcase-region 'disabled nil)

(delete-selection-mode 1)
;; `use-package-compute-statistics' used to be set here and
;; `package-quickstart' too. The first wraps every use-package form in timing
;; instrumentation and is only wanted while actually reading
;; `use-package-report'; the second now lives in early-init.el, which is the
;; only place it takes effect.

;;;; rainbow-delimiters
(use-package rainbow-delimiters
  :ensure t
  :hook (prog-mode . rainbow-delimiters-mode))

;;;; Custom utility functions
(defun quote-pdf nil
  (interactive)
  (pdf-view-kill-ring-save)
  (ace-window 1)
  (org-insert-structure-template "quote") 
  (org-open-line 1)
  (yank nil)
  (org-yank nil))

(defvar joe/last-untitled-buffer nil
  "The buffer most recently created by `xah-new-empty-buffer'.
Used to decide whether a new emacsclient frame needs a fresh buffer.")

(defun xah-new-empty-buffer ()
  "Switch to an empty buffer, creating one only when needed.
Returns the buffer object.
New buffer is named untitled, untitled<2>, etc.

If the buffer most recently created by this command is still live and
still empty, switch to it instead of creating another one.  This keeps
new emacsclient frames from piling up unused untitled buffers.

Warning: new buffer is not prompted for save when killed, see `kill-buffer'.
Or manually `save-buffer'

URL `http://xahlee.info/emacs/emacs/emacs_new_empty_buffer.html'
Created: 2017-11-01
Version: 2022-04-05"
  (interactive)
  (if (and (buffer-live-p joe/last-untitled-buffer)
           (zerop (buffer-size joe/last-untitled-buffer)))
      (switch-to-buffer joe/last-untitled-buffer)
    (let ((xbuf (generate-new-buffer "untitled")))
      (switch-to-buffer xbuf)
      (funcall initial-major-mode)
      (setq joe/last-untitled-buffer xbuf)))
  joe/last-untitled-buffer)
(keymap-global-set "C-c x" #'xah-new-empty-buffer)

(setq initial-buffer-choice 'xah-new-empty-buffer)

;;;; Jump to this configuration
;; `C-c e' is eww (joe-tools.el), so the config lands on the shifted key.
;; Goes through `completing-read' rather than opening a fixed file, so vertico
;; and orderless do the narrowing: "mail" reaches joe-mail.el in four keys.
(defun joe/find-config-file ()
  "Open one of this configuration's own files, chosen by name."
  (interactive)
  (let* ((files (append (list (locate-user-emacs-file "init.el")
                              (locate-user-emacs-file "early-init.el"))
                        (directory-files (locate-user-emacs-file "lisp")
                                         t "\\.el\\'")))
         (alist (mapcar (lambda (f) (cons (file-name-nondirectory f) f))
                        (seq-filter #'file-exists-p files))))
    (find-file (cdr (assoc (completing-read "Config file: " alist nil t)
                           alist)))))

(keymap-global-set "C-c E" #'joe/find-config-file)

;;;; helpful
(use-package helpful
  :ensure t
  :bind
  ([remap describe-function] . helpful-callable)
  ([remap describe-variable] . helpful-variable)
  ([remap describe-key]      . helpful-key)
  ([remap describe-command]  . helpful-command))

;;;; ace-window
(use-package ace-window
  :ensure t
  :bind
  ("M-o" . ace-window)
  :config
  (setq aw-scope 'global)
  (setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
  (setq aw-background nil)
  (setq aw-leading-char-style 'char)
  (setq aw-dispatch-always t))

;;;; Daemon exit diagnostics
;; The daemon has been dying with no Windows crash dump and no Code
;; Integrity block logged against it, so capture whatever Emacs itself
;; knows at exit time.  Only fires for graceful exits (kill-emacs called
;; for any reason) -- an external TerminateProcess kill won't run this,
;; and that absence is itself a useful signal.
(setq server-log t)

(defun joe/log-daemon-exit ()
  (when (daemonp)
    (ignore-errors
      (with-temp-buffer
        (insert (format "\n===== exiting %s (pid %d) =====\n"
                         (format-time-string "%Y-%m-%d %H:%M:%S")
                         (emacs-pid)))
        (insert "-- last messages --\n")
        (when (get-buffer "*Messages*")
          (insert (with-current-buffer "*Messages*"
                    (buffer-substring (max (point-min) (- (point-max) 4000))
                                       (point-max)))))
        (insert "\n-- server log --\n")
        (when (get-buffer "*server*")
          (insert (with-current-buffer "*server*"
                    (buffer-substring (max (point-min) (- (point-max) 2000))
                                       (point-max)))))
        (write-region (point-min) (point-max)
                       (expand-file-name "daemon-exit.log" user-emacs-directory)
                       t)))))

(add-hook 'kill-emacs-hook #'joe/log-daemon-exit)

(provide 'joe-core)
;;; joe-core.el ends here
