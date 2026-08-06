;;; early-init.el --- Early init -*- lexical-binding: t; -*-

;; Defer garbage collection further back in the startup process
(setq gc-cons-threshold most-positive-fixnum)

;; Prevent font-cache compaction on every GC (big win on Windows with icons)
(setq inhibit-compacting-font-caches t)

;; Prevent the glimpse of un-styled Emacs by disabling these UI elements early.
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

;; Locked appliance: /home is mounted noexec, so native-compiled .eln files
;; cannot be dlopen'd from the user eln-cache. Run packages as byte-code.
(setq native-comp-jit-compilation nil)
(setq native-comp-enable-subr-trampolines nil)

(provide 'early-init)
;;; early-init.el ends here
