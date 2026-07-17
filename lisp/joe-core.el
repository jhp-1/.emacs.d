;;; joe-core.el --- Core Emacs configuration -*- lexical-binding: t; -*-

;;;; Package Management
(require 'package)
(setq package-check-signature nil)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
(add-to-list 'package-archives '("nongnu" . "https://elpa.nongnu.org/nongnu/"))
(package-initialize)

;;;; Use-package
(require 'use-package)
(setq use-package-enable-imenu-support t)
(setq use-package-always-ensure t)
(setq use-package-always-demand nil)

;; Disable automatic package refresh on startup
(setq package-auto-update-interval 0)
(setq package-check-update-on-load nil)

;;;;; compile-angel
(use-package compile-angel
  :ensure t
  :demand t
  :config
  (compile-angel-on-load-mode)
  (add-hook 'emacs-lisp-mode-hook #'compile-angel-on-save-local-mode))
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
(defconst joe/notes-dir
  (if (eq system-type 'windows-nt) "d:/Notes" "/mnt/d/Notes")
  "Root directory for Denote notes.")

(defconst joe/texts-dir
  (if (eq system-type 'windows-nt) "d:/Texts" "/mnt/d/Texts")
  "Root directory for PDFs and bibliography.")

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
  (recentf-save-file "~/.emacs.d/recentf"))

;;;; Global keybindings and miscellaneous settings
(keymap-global-set "<f7>" (lambda ()
	    (interactive)
	    (hide-mode-line-mode 'toggle)))
(keymap-global-set "M-<f4>" 'delete-frame)
(keymap-global-set "<f5>" 'call-last-kbd-macro)
(put 'narrow-to-region 'disabled nil)
(put 'downcase-region 'disabled nil)

(setq use-package-compute-statistics t)
(delete-selection-mode 1)
(setq package-quickstart t)

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

(setq initial-buffer-choice 'xah-new-empty-buffer)

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
