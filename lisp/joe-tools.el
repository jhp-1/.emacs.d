;;; joe-tools.el --- Shells, AI, and external tools configuration -*- lexical-binding: t; -*-

;;;; rg
(use-package rg
  :ensure t
  :defer t
  :bind
  ("C-c r" . rg-menu))

;;;; magit
(use-package magit
  :ensure t
  :defer t
  :bind
  ("C-x g" . magit-status)
  :config
  (setq magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1))

;;;; vterm
(use-package vterm
  :ensure t
  :defer t
  :bind (("C-c s" . vterm)
         :map vterm-mode-map
         ("C-q" . vterm-send-next-key)
         ("C-c C-t" . vterm-copy-mode))
  :config
  ;; Speed up scrolling
  (setq vterm-max-scrollback 10000)

  ;; Kill buffer when vterm process exits
  (setq vterm-kill-buffer-on-exit t)

  ;; Better buffer names
  (setq vterm-buffer-name-string "vterm %s")

  ;; Use full window width
  (setq vterm-min-window-width 80)

  ;; Enable bracketed paste
  (setq vterm-enable-manipulate-selection-data-by-osc52 t)

  ;; Better integration with Emacs kill ring
  (setq vterm-copy-exclude-prompt t)

  ;; Open new vterm in current directory
  (defun vterm-here ()
    "Open vterm in the current buffer's directory."
    (interactive)
    (let ((default-directory default-directory))
      (vterm)))

  ;; Quick switch between multiple vterms
  (defun vterm-toggle ()
    "Toggle between vterm and previous buffer."
    (interactive)
    (if (eq major-mode 'vterm-mode)
        (switch-to-buffer (other-buffer))
      (if-let* ((vterm-buf (seq-find (lambda (buf)
                                      (with-current-buffer buf
                                        (eq major-mode 'vterm-mode)))
                                    (buffer-list))))
          (switch-to-buffer vterm-buf)
        (vterm))))

  :bind ("C-c S" . vterm-toggle))

;;;;; eshell
(defun eshell-at-home ()
  "Opens or creates an eshell buffer at ~/."
  (interactive)
  (if (equal (get-buffer "*eshell ~/*") nil)
      (let ((default-directory "~/"))
        (let ((new-buffer (get-buffer-create "*eshell ~/*")))
          (with-current-buffer new-buffer
            (eshell-mode)
            (switch-to-buffer new-buffer))))
    (switch-to-buffer "*eshell ~/*")))

(use-package eshell
  :ensure nil)

;;;; gptel
(use-package gptel
  :ensure t
  :defer t
  :bind
  ("C-c i" . gptel)
  :config
  ;; OpenRouter backend (free DeepSeek as default)
  (gptel-make-openai "OpenRouter"
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key (lambda () (getenv "OPENROUTER_API_KEY"))
    :models '(deepseek/deepseek-r1:free
              openai/gpt-4o
              google/gemini-2.0-flash-001))

  ;; Anthropic / Claude backend — uses ANTHROPIC_API_KEY from environment.
  (gptel-make-anthropic "Claude"
    :stream t
    :key (lambda () (getenv "ANTHROPIC_API_KEY"))
    :models '(claude-sonnet-4-6
              claude-opus-4-7
              claude-haiku-4-5-20251001))

  ;; Default to Claude Sonnet; fall back to OpenRouter if no key is set.
  (setq gptel-backend
        (if (and (getenv "ANTHROPIC_API_KEY")
                 (not (string-empty-p (getenv "ANTHROPIC_API_KEY"))))
            (alist-get "Claude" gptel--backends nil nil #'equal)
          (alist-get "OpenRouter" gptel--backends nil nil #'equal)))
  (setq gptel-model 'claude-sonnet-4-6)
  (setq gptel-default-mode 'markdown-mode))

;;;; eww
(use-package eww
  :ensure nil
  :config
  (setq eww-search-prefix "https://duckduckgo.com/html/?q=")
  (setq eww-download-directory "~/Downloads/")
  :bind
  (:map eww-mode-map
        ("M-n" . eww-next-url)
        ("M-p" . eww-previous-url)))

;;;; Windows-only: explicit PATH and exec-path additions
;; On Windows, exec-path-from-shell is not used (it requires a POSIX shell).
;; C:/Users/Joe/bin contains .cmd wrappers that bridge to WSL tools
;; (notmuch.cmd, mbsync.cmd, msmtp.cmd, claude-code-acp.cmd, etc.).
(when (eq system-type 'windows-nt)
  (setenv "HOME" "C:/Users/Joe")
  (dolist (p '("C:/Program Files/Git/usr/bin"
               "C:/msys64/usr/bin"
               "C:/msys64/mingw64/bin"
               "C:/Users/Joe/bin"))
    (add-to-list 'exec-path p t))
  ;; Pipe performance: eliminate the ~50 ms per-read latency Emacs adds by
  ;; default on Windows.  This significantly speeds up magit, rg, notmuch and
  ;; any other subprocess-heavy workflow.
  (setq w32-pipe-read-delay 0)
  (setq w32-pipe-buffer-size (* 64 1024))
  (setq process-adaptive-read-buffering nil))

;;;; agent-shell / ACP / Claude Code via OpenRouter / Goose

(use-package shell-maker
  :vc (:url "https://github.com/xenodium/shell-maker"))

(use-package acp
  :vc (:url "https://github.com/xenodium/acp.el"))

;; exec-path-from-shell: only active on Linux/macOS GUI Emacs.
;; On Windows, exec-path-from-shell cannot call a POSIX shell (printf is missing
;; from cmd.exe/cmdproxy.exe) and will error.  Environment vars on Windows are
;; set at the OS level and inherited by the Emacs daemon at login.
(use-package exec-path-from-shell
  :if (memq system-type '(gnu gnu/linux gnu/kfreebsd darwin))
  :ensure t
  :init
  (setq exec-path-from-shell-arguments '("-l"))
  ;; Pin to bash so this works regardless of the user's default WSL shell.
  (setq exec-path-from-shell-shell-name "/bin/bash")
  :config
  ;; fish is supported directly
  (dolist (var '("PATH"
                 "OPENROUTER_API_KEY"
                 "ANTHROPIC_BASE_URL"
                 "ANTHROPIC_AUTH_TOKEN"
                 "ANTHROPIC_API_KEY"
                 "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS"
                 "DISABLE_PROMPT_CACHING"
                 "CLAUDE_CODE_MAX_OUTPUT_TOKENS"))
    (exec-path-from-shell-copy-env var)))

(use-package agent-shell
  :vc (:url "https://github.com/xenodium/agent-shell")
  ;; exec-path-from-shell is not loaded on Windows (guarded by :if above),
  ;; so it cannot be listed as an :after dependency here.
  :after (shell-maker acp)
  :commands
  (agent-shell-goose-start-agent
   agent-shell-anthropic-start-claude-code)
  :bind
  (("C-c C-q" . agent-shell-goose-start-agent)
   ("C-c C-a" . agent-shell-anthropic-start-claude-code))
  :config
  (setq agent-shell-goose-authentication
        (agent-shell-make-goose-authentication :none t))

  ;; On Windows, claude-code-acp lives inside WSL, so we call it via wsl.exe.
  ;; On Linux/macOS the binary is on PATH directly.
  (setq agent-shell-anthropic-claude-acp-command
        (if (eq system-type 'windows-nt)
            '("wsl" "claude-code-acp")
          '("claude-code-acp")))

  (setq agent-shell-anthropic-claude-command nil)

  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication
         :api-key (lambda () "")))

  ;; On Windows, OPENROUTER_API_KEY / ANTHROPIC_BASE_URL / ANTHROPIC_API_KEY
  ;; must be set as Windows user environment variables.
  (setq agent-shell-anthropic-claude-environment
        (agent-shell-make-environment-variables
         :inherit-env t)))

;;;; pass
(use-package pass
  :ensure t
  :bind
  ("C-c p p" . pass)
  ("C-c p i" . pass-insert)
  ("C-c p g" . pass-generate))

;;;; elfeed
(use-package elfeed
  :ensure t
  :bind
  ("C-c e" . elfeed)
  :config
  (setq-default elfeed-search-filter "@6-months-ago ")
  (setq elfeed-use-curl t)
  (setq elfeed-curl-max-connections 10)
  (setq elfeed-curl-timeout 10))

(use-package elfeed-org
  :after elfeed
  :ensure t
  :config
  (elfeed-org)
  (setq rmh-elfeed-org-files (list "~/.elfeed/elfeed.org")))

;;;; tmr
(use-package tmr
  :ensure t
  :bind
  ("C-c t t" . tmr)
  ("C-c t r" . tmr-timer-remove)
  ("C-c t s" . tmr-timer-start))

(provide 'joe-tools)
;;; joe-tools.el ends here
