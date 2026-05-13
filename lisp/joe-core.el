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

;;;; auto-package-update
(use-package auto-package-update
  :ensure t
  :defer t
  :config
  (setq auto-package-update-delete-old-versions t)
  (setq auto-package-update-interval 7))

;;;; Environment settings
;; On Windows, PATH and exec-path are managed explicitly in joe-tools.el.
;; These Linux-only tweaks add nvm Node and ~/.local/bin to the path for
;; Linux/WSL Emacs instances only.
(when (memq system-type '(gnu gnu/linux gnu/kfreebsd))
  (setenv "PATH" (concat (expand-file-name "~/.nvm/versions/node/v14.21.3/bin") ":"
                         (expand-file-name "~/.local/bin") ":"
                         (getenv "PATH")))
  (setq exec-path (append (list (expand-file-name "~/.nvm/versions/node/v14.21.3/bin")
                                (expand-file-name "~/.local/bin"))
                          exec-path)))

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

(defun xah-new-empty-buffer ()
  "Create a new empty buffer.
Returns the buffer object.
New buffer is named untitled, untitled<2>, etc.

Warning: new buffer is not prompted for save when killed, see `kill-buffer'.
Or manually `save-buffer'

URL `http://xahlee.info/emacs/emacs/emacs_new_empty_buffer.html'
Created: 2017-11-01
Version: 2022-04-05"
  (interactive)
  (let ((xbuf (generate-new-buffer "untitled")))
    (switch-to-buffer xbuf)
    (funcall initial-major-mode)
    xbuf
    ))

(setq initial-buffer-choice 'xah-new-empty-buffer)
(use-package quelpa
  :ensure t)
(use-package quelpa-use-package
  :ensure t)

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

;;;; centered-cursor-mode
(use-package centered-cursor-mode
  :ensure t)

(provide 'joe-core)
;;; joe-core.el ends here
