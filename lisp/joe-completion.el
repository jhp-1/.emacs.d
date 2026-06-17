;;; joe-completion.el --- Completion and minibuffer configuration -*- lexical-binding: t; -*-

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
  (setq orderless-component-separator " +")
  (setq completion-styles '(orderless basic))
  (setq completion-category-defaults nil)
  (setq completion-category-overrides '((file (styles partial-completion))))
  ;; SPC should never complete: use it for `orderless' groups.
  (let ((map minibuffer-local-completion-map))
    (define-key map (kbd "SPC") nil)
    (define-key map (kbd "?") nil)))


;;;; which-key
(use-package which-key
  :ensure t
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
  (with-eval-after-load 'savehist
    (corfu-history-mode 1)
    (add-to-list 'savehist-additional-variables 'corfu-history))
  :init
  (global-corfu-mode))

;;;; nerd icons for completion
(use-package nerd-icons-completion
  :ensure t
  :after marginalia
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))

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
  (setq consult-buffer-sources
        (delq 'consult--source-bookmark consult-buffer-sources)))

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
