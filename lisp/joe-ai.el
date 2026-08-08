;;; joe-ai.el --- Coding agents in Emacs buffers -*- lexical-binding: t; -*-

;;; Commentary:
;; Claude Code (and any other ACP-speaking agent) in a native Emacs buffer,
;; via agent-shell.  Chosen over claude-code-ide.el and claude-code.el
;; specifically because of this machine: both of those drive the real CLI TUI
;; inside a terminal emulator, and every terminal backend they support is
;; either a native module we cannot build here (vterm, ghostel — see the
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
;; declaration only quiets the byte-compiler, which matters on the Windows host
;; where compile-angel is enabled.
(declare-function agent-shell-anthropic-make-authentication "agent-shell-anthropic")

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
  ;; `:config', not `:init'.  All three settings live in agent-shell-anthropic,
  ;; which agent-shell.el requires — so in `:init' the constructor below is a
  ;; void function and startup dies with a use-package error.  Nothing reads
  ;; these before the package loads, so deferring them costs nothing.
  :config
  ;; Reuse the subscription login the `claude' CLI already holds, rather than
  ;; putting an API key in a file that lives in a public git repo.  Refresh it
  ;; with `claude setup-token' if sessions start failing to authenticate.
  (setq agent-shell-anthropic-authentication
        (agent-shell-anthropic-make-authentication :login t))
  ;; Preselect rather than force, so the picker still lists Codex, Gemini et al
  ;; for the times a second opinion is worth the keystrokes.
  (setq agent-shell-preferred-agent-config '(preselect . claude-code))
  (when (bound-and-true-p joe/noexec-home-p)
    (setq agent-shell-anthropic-claude-acp-command
          (list "node" joe/claude-acp-program)))
  :bind
  ;; `C-c a' is org-agenda and `C-c s' is ghostel on Windows; `C-c z' is the
  ;; nearest free key, and matches the C-c z-as-REPL-toggle convention.
  ("C-c z" . agent-shell))

(provide 'joe-ai)
;;; joe-ai.el ends here
