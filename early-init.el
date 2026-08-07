;;; early-init.el --- Early init -*- lexical-binding: t; -*-

;; Defer garbage collection further back in the startup process
(setq gc-cons-threshold most-positive-fixnum)

;; Prevent font-cache compaction on every GC (big win on Windows with icons)
(setq inhibit-compacting-font-caches t)

;; Prevent the glimpse of un-styled Emacs by disabling these UI elements early.
(setq load-prefer-newer t)
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;; Resizing the Emacs frame can be a terribly expensive part of changing the
;; font. By inhibiting this, we easily halve startup times with fonts that are
;; larger than the system default.
(setq frame-inhibit-implied-resize t)

;; Ignore X resources; its settings would be redundant with the other settings
;; in this file and can conflict with later config (particularly where the
;; cursor color is concerned).
;; Guard: x-apply-session-resources doesn't exist on windows-nt.
(when (fboundp 'x-apply-session-resources)
  (advice-add #'x-apply-session-resources :override #'ignore))

;; native-comp: reduce verbosity
(setq native-comp-async-report-warnings-errors nil)
(setq warning-suppress-types '((comp)))

;; The x270 is a locked-down console appliance: /home is mounted noexec, so
;; native-compiled .eln files cannot be dlopen'd from the user eln-cache, and
;; there is no GUI at all. Everything keyed off this constant is a no-op on
;; every other machine — an earlier revision set the native-comp variables
;; unconditionally, which would also have disabled native-comp on Windows.
(defconst joe/console-appliance-p (string= (system-name) "x270")
  "Non-nil on the x270 console appliance (noexec /home, no window system).")

(when joe/console-appliance-p
  ;; Run packages as byte-code; .elc is interpreted, .eln would be dlopen'd.
  (setq native-comp-jit-compilation nil)
  (setq native-comp-enable-subr-trampolines nil))

;; Hosts whose Emacs is built by Nix `emacsWithPackages'. On these, packages
;; with native modules or a version-locked CLI — pdf-tools (epdfinfo), jinx
;; (jinx-mod.so), notmuch (elisp must match the notmuch CLI) — are provided by
;; Emacs itself and MUST be `:ensure nil', because MELPA cannot build the
;; native parts here (and on the appliance they could not be dlopen'd from a
;; noexec /home anyway). Pure-elisp packages are unaffected — they still come
;; from MELPA on every host. See nixos/HANDOFF.md §7. Add other Nix hosts (e.g.
;; the x270, once its Emacs is emacsWithPackages) to this list as they migrate.
(defconst joe/nix-emacs-p (member (system-name) '("nixdesktop"))
  "Non-nil on hosts where Emacs packages come from Nix `emacsWithPackages'.")

(provide 'early-init)
;;; early-init.el ends here
