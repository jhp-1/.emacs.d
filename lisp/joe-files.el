;;; joe-files.el --- Files and buffers configuration -*- lexical-binding: t; -*-
(setq large-file-warning-threshold nil)
;;;; Dired
(use-package dired
  :ensure nil  
  :hook
  ((dired-mode . dired-hide-details-mode)
   (dired-mode . hl-line-mode)
   (dired-mode . openwith-mode))

  :config
  (setq dired-recursive-copies 'always
        dired-recursive-deletes 'always
        delete-by-moving-to-trash t
        dired-listing-switches "-lav --group-directories-first -h"
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
  :ensure t
  :bind
  ("C-x C-b" . ibuffer))

;;;; nerd icons for dired and ibuffer
(use-package nerd-icons-dired
  :ensure t
  :hook
  (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-ibuffer
  :ensure t
  :hook (ibuffer-mode . nerd-icons-ibuffer-mode))

;;;; General Dired optimizations
;; dired-listing-switches is set canonically in the dired use-package block above
;; ("-lav --group-directories-first -h"); do not duplicate it here.
(add-hook 'dired-mode-hook #'dired-omit-mode)  ; Hide non-essential files per buffer
;; inhibit-compacting-font-caches is now set in early-init.el
(setq nerd-icons-dired-disable-submodule-check t)  ; If this option exists

(provide 'joe-files)
;;; joe-files.el ends here
