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
        ;; Android always lists directories with ls-lisp, whatever is on
        ;; `exec-path': ls-lisp.el defaults
        ;; `ls-lisp-use-insert-directory-program' to nil there, the same as on
        ;; Windows. ls-lisp sanitises away long GNU options that have no short
        ;; equivalent, so --group-directories-first is silently dropped rather
        ;; than misparsed -- nothing breaks, listings just lose the grouping.
        ;; Dropping it here keeps the value honest about what will happen;
        ;; joe-android.el sets `ls-lisp-dirs-first', which is the equivalent.
        dired-listing-switches
        (if (bound-and-true-p joe/android-p) "-lh"
          "-lv --group-directories-first -h")
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

;; `dired-async-mode' does its work by starting a fresh Emacs subprocess. The
;; Android APK cannot: `invocation-directory'/`invocation-name' do not name a
;; runnable binary there. Same constraint that makes
;; `joe/byte-compile-package-cleanly' (joe-core.el) fall back. Left off rather
;; than left to fail silently mid-copy; dired's synchronous path still works.
(use-package async
  :ensure t
  :config
  (unless (bound-and-true-p joe/android-p)
    (dired-async-mode 1)))

;;;; deadgrep
(use-package deadgrep
  :ensure t
  :defer t
  :bind
  ("C-c g" . deadgrep))

;;;; openwith
;; Kept loaded but empty on Android rather than skipped: `openwith-mode' is on
;; `dired-mode-hook' above, so not loading the package would make every dired
;; buffer fail on a void function. There is no mpv there, and handing a file://
;; URI to Android's VIEW intent raises FileUriExposedException on anything
;; modern, so there is nothing useful to associate -- an empty list makes the
;; mode an honest no-op.
(use-package openwith
  :ensure t
  :config
  (setq openwith-associations
        (unless (bound-and-true-p joe/android-p)
          '(("\\.\\(webm\\|mp4\\|mkv\\|avi\\|mp3\\|flac\\|wav\\|aiff\\|opus\\|aif\\)\\'"
             "mpv --force-window"
             (file))))))

;;;;; ibuffer
(use-package ibuffer
  :ensure nil
  :bind
  ("C-x C-b" . ibuffer))

;;;; nerd icons for dired and ibuffer
;; See joe-ui.el: no glyph fallback on the appliance's console, and no
;; nerd-patched font on Android. `joe/no-icon-font-p' covers both.
(use-package nerd-icons-dired
  :ensure t
  :unless (bound-and-true-p joe/no-icon-font-p)
  :hook
  (dired-mode . nerd-icons-dired-mode))

(use-package nerd-icons-ibuffer
  :ensure t
  :unless (bound-and-true-p joe/no-icon-font-p)
  :hook (ibuffer-mode . nerd-icons-ibuffer-mode))

;;;; General Dired optimizations
;; dired-listing-switches is set canonically in the dired use-package block above
;; ("-lv --group-directories-first -h" — no -a, so dotfiles are hidden by
;; default; toggle per-buffer with C-c . / joe/dired-toggle-dotfiles).
;; do not duplicate it here.
(add-hook 'dired-mode-hook #'dired-omit-mode)  ; Hide non-essential files per buffer
;; inhibit-compacting-font-caches is now set in early-init.el
(setq nerd-icons-dired-disable-submodule-check t)  ; If this option exists

;;;; Adopt Dired buffers that predate this file
;; init.el requires joe-files on a 0.5s idle timer, and `add-hook' is not
;; retroactive: a Dired buffer opened before that fires runs none of the hooks
;; above and keeps stock Dired for as long as it lives. Reverting it later does
;; not help either, because `dired-mode-hook' runs at mode init, not on revert.
;; The symptom is one directory looking configured while another -- opened
;; seconds earlier -- shows raw `-al' output: permissions, owner, dotfiles, no
;; icons, no hidden details, no denote fontification.
;;
;; This is not a race that can be won by moving the timer, since Dired can
;; always be opened sooner; so adopt whatever already exists instead. Both
;; steps are needed: `run-hooks' switches on the minor modes that come from
;; `dired-mode-hook', while reverting re-lists with the configured switches and
;; fires `dired-after-readin-hook' for the icons. Everything invoked is
;; idempotent, so buffers created after this point are unaffected.
(defun joe/dired-adopt-existing-buffers ()
  "Apply this file's Dired configuration to buffers that predate it."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (derived-mode-p 'dired-mode)
        (setq dired-actual-switches dired-listing-switches)
        (run-hooks 'dired-mode-hook)
        (revert-buffer t t)))))

(joe/dired-adopt-existing-buffers)

(provide 'joe-files)
;;; joe-files.el ends here
