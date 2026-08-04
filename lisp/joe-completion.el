;;; joe-completion.el --- Completion and minibuffer configuration -*- lexical-binding: t; -*-

;; Don't let GC fire while a minibuffer is open. consult-dir builds a big
;; candidate list (recentf + project + bookmarks) that trips the 16MB
;; threshold mid-command, causing intermittent lag.
(add-hook 'minibuffer-setup-hook
          (lambda () (setq gc-cons-threshold most-positive-fixnum)))
(add-hook 'minibuffer-exit-hook
          (lambda () (setq gc-cons-threshold (* 16 1024 1024))))
;;;; Built-in completion settings
;; TAB indents, then completes once indentation is already correct.  Without
;; this Corfu is only reachable through `completion-at-point' (C-M-i).
(setq tab-always-indent 'complete)

;; Emacs 30+: drop the Ispell Capf from text modes.  It shadows more useful
;; completions in prose buffers; a dictionary Capf covers the same ground.
(setq text-mode-ispell-word-completion nil)

;; Hide commands in M-x which do not apply to the current mode.
(setq read-extended-command-predicate #'command-completion-default-include-p)

;;;; vertico
(use-package vertico
  :ensure t
  :custom
  (vertico-cycle t)
  :init
  (vertico-mode))

;;;; marginalia
(use-package marginalia
  :ensure t
  :init
  (marginalia-mode))

;;;; orderless
(use-package orderless
  :ensure t
  :config
  ;; `orderless-component-separator' is left at its default
  ;; (`orderless-escapable-split'), which splits on spaces like " +" but also
  ;; allows a literal space to be matched by escaping it as "\ ".
  (setq completion-styles '(orderless basic))
  (setq completion-category-defaults nil)
  ;; `basic' first so dynamic completion tables (TRAMP hosts and remote paths)
  ;; keep working; `partial-completion' supplies wildcard expansion in find-file.
  (setq completion-category-overrides '((file (styles basic partial-completion))))
  ;; SPC should never complete: use it for `orderless' groups.
  (keymap-set minibuffer-local-completion-map "SPC" nil)
  (keymap-set minibuffer-local-completion-map "?" nil))


;;;; which-key
;; Built into Emacs 30, so no need to pull the ELPA copy.
(use-package which-key
  :ensure nil
  :init
  (which-key-mode))

;;;; Recursive minibuffers
(minibuffer-depth-indicate-mode 1)
(setq enable-recursive-minibuffers t)

;;;; corfu
(use-package corfu
  :ensure t
  ;; I also have (setq tab-always-indent 'complete) for TAB to complete
  ;; when it does not need to perform an indentation change.
  :bind (:map corfu-map ("<tab>" . corfu-complete))
  :config
  (setq corfu-preview-current nil)
  (setq corfu-min-width 20)
  (setq corfu-popupinfo-delay '(1.25 . 0.5))
  (corfu-popupinfo-mode 1) ; shows documentation after `corfu-popupinfo-delay'

  ;; Sort by input history (no need to modify `corfu-sort-function').
  ;; Corfu 2.1+ registers `corfu-history' with savehist itself, provided
  ;; `savehist-mode' is already on -- joe-core.el enables it before this file
  ;; is loaded.
  (corfu-history-mode 1)
  :init
  (global-corfu-mode))

;;;; cape -- extra completion-at-point functions
(defun joe/cape-dict-setup ()
  "Add `cape-dict' to the local Capfs, for prose buffers."
  (add-hook 'completion-at-point-functions #'cape-dict 90 t))

(use-package cape
  :ensure t
  ;; C-c p is a prefix map of every Capf as a directly callable command,
  ;; e.g. C-c p d for Dabbrev, C-c p f for file paths.
  :bind ("C-c p" . cape-prefix-map)
  :init
  ;; These go on the *global* value of `completion-at-point-functions', so
  ;; mode-specific Capfs (elisp, org, eglot) still win: the buffer-local list
  ;; is always consulted first.
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-elisp-block) ; org-babel src blocks
  :config
  ;; Word completion from a system word list, replacing the Ispell Capf turned
  ;; off at the top of this file.  There is no word list on Windows, where this
  ;; simply stays off.
  (when (and (stringp cape-dict-file) (file-readable-p cape-dict-file))
    (add-hook 'text-mode-hook #'joe/cape-dict-setup)))

;;;; dabbrev
;; cape-dabbrev and M-/ both scrape buffer text, so keep them away from
;; buffers whose "text" is really a rendering of something binary.
(use-package dabbrev
  :ensure nil
  ;; Swap the two: completion (which goes through Corfu) on the easier key.
  :bind (("M-/" . dabbrev-completion)
         ("C-M-/" . dabbrev-expand))
  :config
  (add-to-list 'dabbrev-ignored-buffer-regexps "\\` ")
  (dolist (mode '(authinfo-mode doc-view-mode pdf-view-mode tags-table-mode))
    (add-to-list 'dabbrev-ignored-buffer-modes mode)))

;;;; nerd icons for completion
(use-package nerd-icons-completion
  :ensure t
  :after marginalia
  :config
  ;; `nerd-icons-completion-mode' installs the marginalia hook itself.
  (nerd-icons-completion-mode))

(use-package nerd-icons-corfu
  :ensure t
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

;;;; embark
(use-package embark
  :ensure t
  :bind
  ("C-." . embark-act)
  ("C-," . embark-collect))

;;;; consult
(use-package consult
  :ensure t
  :bind
  (("C-x b" . consult-buffer)               ;; Switch buffers to consult-buffer
   ("M-y" . consult-yank-pop)               ;; Replace yank-pop with consult-yank-pop
   ("M-g o" . consult-outline)              ;; Replace outline navigation
   ("M-g m" . consult-mark)                 ;; Go to mark
   ("M-g k" . consult-global-mark)          ;; Go to global mark
   ("M-g i" . consult-imenu)                ;; Replace imenu
   ("C-M-s" . consult-ripgrep)              ;; Replace search with ripgrep
   ("M-s l" . consult-line)                 ;; Search lines in this buffer
   ("M-s L" . consult-line-multi)           ;; ... across all open buffers
   ("C-c h" . consult-history)              ;; Command history
   ("C-c m" . consult-mode-command)         ;; Mode-specific commands
   ("C-c k" . consult-kmacro) ;; Keyboard macros
   ("C-x r b" . consult-bookmark)
   ;; Isearch integration
   ("M-s e" . consult-isearch-history)
   :map isearch-mode-map
   ("M-e" . consult-isearch-history)         ;; orig. isearch-edit-string
   ("M-s e" . consult-isearch-history)       ;; orig. isearch-edit-string
   ("M-s l" . consult-line)                  ;; needed by consult-line to detect isearch
   ("M-s L" . consult-line-multi)            ;; needed by consult-line to detect isearch
   ;; Minibuffer history
   :map minibuffer-local-map
   ("M-s" . consult-history)                 ;; orig. next-matching-history-element
   ("M-r" . consult-history))              
  :config
  (setq consult-preview-key nil)
  ;; Bookmarks live on C-x r b; keep them out of the buffer list.  Consult 3.0
  ;; renamed the source variables (consult--source-* -> consult-source-*) and
  ;; 3.3 deleted the old names, so remove both and stay version-agnostic.
  (setq consult-buffer-sources
        (seq-difference consult-buffer-sources
                        '(consult--source-bookmark consult-source-bookmark))))

;;;; consult-denote
(use-package consult-denote
  :ensure t
  :bind
  (("C-c n f" . consult-denote-find)
   ("C-c n g" . consult-denote-grep))
  :config
  (consult-denote-mode 1))

;;;; consult-dir
(use-package consult-dir
  :ensure t
  :bind (("C-x C-d" . consult-dir)
         :map vertico-map
         ("C-x C-d" . consult-dir)
         ("C-x C-j" . consult-dir-jump-file)))

;;;; embark-consult
(use-package embark-consult
  :ensure t)

(provide 'joe-completion)
;;; joe-completion.el ends here
