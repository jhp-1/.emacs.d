;;; joe-ai.el --- Coding agents in Emacs buffers -*- lexical-binding: t; -*-

;;; Commentary:
;; Codex (and any other ACP-speaking agent) in a native Emacs buffer,
;; via agent-shell.  Chosen over claude-code-ide.el and claude-code.el
;; specifically because of this machine: both of those drive the real CLI TUI
;; inside a terminal emulator, and every terminal backend they support is
;; either a native module we cannot build here (vterm — see the
;; `joe/nix-emacs-p' note in early-init.el) or the visibly glitchier `eat'.
;; agent-shell renders the conversation itself, so its whole dependency chain
;; — shell-maker, acp — is pure Elisp and installs from MELPA unchanged.
;;
;; The trade-off to remember: ACP is a layer behind the CLI, so newly shipped
;; Claude Code features (skills, hooks, new slash commands) can take a while to
;; surface here.  When something is missing, the CLI in a terminal is the
;; fallback, not a bug in this file.

;;; Code:

;; Called from `:config', so it is genuinely defined by the time it runs — the
;; declaration only quiets the byte-compiler, which matters wherever
;; compile-angel is enabled.
;; (declare-function agent-shell-openai-make-authentication
;;                   "agent-shell-openai")
(declare-function agent-shell-anthropic-make-authentication "agent-shell-anthropic")
(declare-function agent-shell-make-environment-variables "agent-shell")

;;;; agent-shell
;; agent-shell talks to Claude through the ACP adapter, an npm package, NOT to
;; the `claude' binary directly.  Install it with:
;;
;;   npm install -g --prefix ~/.npm-global @agentclientprotocol/claude-agent-acp
;;
;; The `--prefix' is required: npm's default prefix is the nodejs derivation in
;; /nix/store, which is read-only.  (The package was called `claude-code-acp'
;; until mid-2026; anything still naming that is stale.)
;;
;; Two further notes for this host, both consequences of a noexec /home:
;;
;;   - npm's ~/.npm-global/bin/claude-agent-acp is a symlink to dist/index.js
;;     with a shebang.  Running it dies with EACCES, and `executable-find'
;;     never sees it, so agent-shell's default command cannot work.  Invoking
;;     `node' on the .js explicitly sidesteps this: node is in the store and
;;     executable, and it reads the script as data.
;;   - The adapter then spawns the real `claude' CLI, which lives in
;;     /run/current-system/sw/bin — in the store, so exec is fine there.
;;
;; Version skew between the Elisp and the adapter is the likeliest breakage:
;; auto-package-update moves agent-shell/acp/shell-maker on its 7-day timer and
;; knows nothing about npm.  If a session stops handshaking, re-run the npm
;; command above before debugging anything else.
(defvar joe/claude-acp-program
  (expand-file-name
   "lib/node_modules/@agentclientprotocol/claude-agent-acp/dist/index.js"
   "~/.npm-global")
  "Path to the ACP adapter's entry script.")

(use-package agent-shell
  :ensure t
  :defer t
  :hook (agent-shell-mode . olivetti-mode)
  ;; `:config', not `:init'.  All three settings live in agent-shell-anthropic,
  ;; which agent-shell.el requires — so in `:init' the constructor below is a
  ;; void function and startup dies with a use-package error.  Nothing reads
  ;; these before the package loads, so deferring them costs nothing.
  :config
  (setq agent-shell-header-style 'text)
  ;; Reuse the subscription login the `claude' CLI already holds, rather than
  ;; putting an API key in a file that lives in a public git repo.  Refresh it
  ;; with `claude setup-token' if sessions start failing to authenticate.
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t))
  ;; (setq agent-shell-openai-authentication
  ;;     (agent-shell-openai-make-authentication :login t))
  ;; Codex comes from Nix on this machine. Keep agent-shell on the store-backed
  ;; ACP binary and give Codex a real terminal environment; Emacs otherwise
  ;; launches it with TERM=dumb and stale TERMINFO_DIRS entries.
  ;; (setq agent-shell-openai-codex-acp-command
  ;;       (list (or (executable-find "codex-acp") "codex-acp")))
  ;; (setq agent-shell-openai-codex-environment
  ;;       (append
  ;;        (agent-shell-make-environment-variables
  ;;         "TERM" "xterm-256color"
  ;;         "TERMINFO_DIRS" "/run/current-system/sw/share/terminfo")
  ;;        '("NO_COLOR")))
  ;; Use Codex directly for new shells. Other agents remain available through
  ;; their own launch commands or by changing this preference.
  (setq agent-shell-preferred-agent-config 'codex
        agent-shell-openai-default-model-id "gpt-6-sol"
        agent-shell-openai-default-session-mode-id "agent-full-access")
  (when (bound-and-true-p joe/noexec-home-p)
    (setq agent-shell-anthropic-claude-acp-command
          (list "node" joe/claude-acp-program))
    ;; Second, separate noexec casualty. The adapter does not drive the `claude'
    ;; on PATH: it bundles its own copy of the CLI, as a platform binary under
    ;; node_modules/@anthropic-ai/claude-agent-sdk-linux-x64/claude, and spawns
    ;; that. Which lands in /home, so it cannot be exec'd here — `session/new'
    ;; fails with "exists but failed to launch". The adapter's own diagnostic
    ;; blames a musl/glibc mismatch; that is a plausible guess in general and
    ;; the wrong one here, so do not go chasing loaders.
    ;;
    ;; CLAUDE_CODE_EXECUTABLE takes precedence over the bundled binary, so point
    ;; it at the Nix one — in the store, so executable, and the version we
    ;; actually keep updated. Resolved via `executable-find' rather than
    ;; hardcoded, since the store path changes on every rebuild.
    (when-let* ((claude (executable-find "claude")))
      (setq agent-shell-anthropic-claude-environment
            (agent-shell-make-environment-variables
             "CLAUDE_CODE_EXECUTABLE" claude))))
  :bind
  ;; `C-c a' is org-agenda and `C-c s' is eshell; `C-c z' is the
  ;; nearest free key, and matches the C-c z-as-REPL-toggle convention.
  ;; Its uppercase companion switches among existing agent sessions.
  (("C-c z" . agent-shell)
   ("C-c Z" . agent-shell-switch-buffer)))

(use-package agent-shell-notifications
  ;; Keep this small package as a visible source checkout: it is not in the
  ;; package archives used by this configuration.
  :load-path "~/projects/agent-shell-notifications"
  :after agent-shell
  :hook (agent-shell-mode . agent-shell-notifications-mode))

(defun joe/agent-recall-style-transcript ()
  "Give an Agent Recall transcript a read-only reading layout."
  (when agent-recall-transcript-mode
    (visual-line-mode 1)
    (olivetti-mode 1)
    (when (derived-mode-p 'markdown-mode)
      ;; Hide source punctuation without changing the transcript file.
      (setq-local markdown-fontify-code-blocks-natively t)
      (markdown-toggle-markup-hiding 1))))

(use-package agent-recall
  ;; Keep the upstream checkout visible and update it with git, just like
  ;; agent-shell-notifications. Do not duplicate it in this config repo.
  :load-path "~/projects/agent-recall"
  :after agent-shell
  :hook ((agent-shell-mode . agent-recall-track-sessions)
         (agent-recall-transcript-mode . joe/agent-recall-style-transcript))
  :config
  (setq agent-recall-search-paths '("~/projects" "~/.emacs.d" "~/Notes" "~/Downloads")
        agent-recall-extra-transcript-dirs '((:dir "~/.agent-shell/transcripts"))
        agent-recall-search-function 'consult-ripgrep
        agent-recall-browse-sort 'modified-desc))

(provide 'joe-ai)
;;; joe-ai.el ends here
