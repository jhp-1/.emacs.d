;;; joe-files.el --- Files and buffers configuration -*- lexical-binding: t; -*-
(setq large-file-warning-threshold nil)
;;;; Dired
(defun joe/dired-toggle-dotfiles ()
  "Toggle showing dotfiles in the current Dired buffer (default: hidden).
Hiding is just the absence of ls's -a flag, so flip it and re-list."
  (interactive)
  (dired-sort-other
   (if (string-prefix-p "-a " dired-actual-switches)
       (substring dired-actual-switches 3)
     (concat "-a " dired-actual-switches))))

(use-package dired
  :ensure nil
  :bind (:map dired-mode-map
              ("C-c ." . joe/dired-toggle-dotfiles))
  :hook
  ((dired-mode . dired-hide-details-mode)
   (dired-mode . hl-line-mode)
   (dired-mode . openwith-mode))

  :config
  (setq dired-recursive-copies 'always
        dired-recursive-deletes 'always
        delete-by-moving-to-trash t
        dired-listing-switches "-lv --group-directories-first -h"
        dired-dwim-target t
        dired-auto-revert-buffer #'dired-directory-changed-p
        wdired-allow-to-change-permissions t
        global-auto-revert-non-file-buffers t)
  (setq dired-clean-confirm-killing-deleted-buffers nil))

(use-package dired-subtree
  :ensure t
  :after dired
  :bind (:map dired-mode-map
              ("<tab>" . dired-subtree-toggle)
              ("<C-tab>" . dired-subtree-cycle)
              ("<backtab>" . dired-subtree-remove))
  :config
  (setq dired-subtree-use-backgrounds nil))

(use-package dired-filter
  :ensure t)

(use-package async
  :ensure t
  :config
  (dired-async-mode 1))

;;;; deadgrep
(use-package deadgrep
  :ensure t
  :defer t
  :bind
  ("C-c g" . deadgrep))

;;;; openwith
(use-package openwith
  :ensure t
  :config
  (setq openwith-associations
        '(("\\.\\(webm\\|mp4\\|mkv\\|avi\\|mp3\\|flac\\|wav\\|aiff\\|opus\\|aif\\)\\'"
           "mpv --force-window"
           (file)))))

;;;;; ibuffer
(use-package ibuffer
  :ensure nil
  :bind
  ("C-x C-b" . ibuffer))

;;;; nerd icons for dired and ibuffer
;; See joe-ui.el: no glyph fallback on the appliance's console.
(use-package nerd-icons-dired
  :ensure t
  :unless (bound-and-true-p joe/console-appliance-p)
  :hook
  (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-ibuffer
  :ensure t
  :unless (bound-and-true-p joe/console-appliance-p)
  :hook (ibuffer-mode . nerd-icons-ibuffer-mode))

;;;; General Dired optimizations
;; dired-listing-switches is set canonically in the dired use-package block above
;; ("-lv --group-directories-first -h" — no -a, so dotfiles are hidden by
;; default; toggle per-buffer with C-c . / joe/dired-toggle-dotfiles).
;; do not duplicate it here.
(add-hook 'dired-mode-hook #'dired-omit-mode)  ; Hide non-essential files per buffer
;; inhibit-compacting-font-caches is now set in early-init.el
(setq nerd-icons-dired-disable-submodule-check t)  ; If this option exists

(provide 'joe-files)
;;; joe-files.el ends here
