;;; early-init.el --- Early init -*- lexical-binding: t; -*-

;; Defer garbage collection further back in the startup process
(setq gc-cons-threshold most-positive-fixnum)

;; Prevent font-cache compaction on every GC. Matters most where a buffer
;; mixes many fonts, as an icon set does.
(setq inhibit-compacting-font-caches t)

;;;; Android
;; Defined here, above everything that consults it, because the very first
;; thing it changes is the frame alist below -- by the time init.el is read the
;; initial frame already exists.
(defconst joe/android-p (eq system-type 'android)
  "Non-nil on the native Android port (GNU Emacs 30+ APK).")

(defconst joe/android-termux-home "/data/data/com.termux/files/home"
  "Termux's Unix home, when Emacs and Termux share a UID.
Only reachable from the `termux/' APK builds, which set
`sharedUserId' to com.termux.  Files here -- unlike anything under
/content or /assets -- are visible to SUBPROCESSES as well as to
Emacs's own file primitives, which is why notes belong here rather
than in a Storage Access Framework folder.")

;; Put Termux's bin on PATH so Emacs has git, rg, aspell, `am', ls -- anything
;; at all, really; the APK ships no userland of its own.  Per the port's README
;; this is PATH and `exec-path' ONLY: the advice to also set LD_LIBRARY_PATH has
;; been explicitly retracted upstream, because Termux embeds its library paths
;; in its executables and adding the variable causes name collisions and
;; bizarre linking errors.  Guarded on the directory existing, so a non-Termux
;; APK (or a Termux that has not been installed yet) is a no-op rather than a
;; broken PATH.
(when joe/android-p
  (let ((bin "/data/data/com.termux/files/usr/bin"))
    (when (file-directory-p bin)
      (setenv "PATH" (format "%s:%s" bin (getenv "PATH")))
      (push bin exec-path))))

;; `temporary-file-directory' comes from $TMPDIR, and the Android port sets it
;; nowhere, so it falls back to /tmp -- which on Android is owned by shell:shell
;; with the SELinux context shell_data_file, and is therefore not writable by an
;; app process at all.  Everything needing a scratch file then fails, silently.
;; The visible casualty is `server-start' in joe-android.el: it creates its
;; socket under `server-socket-dir' (i.e. $TMPDIR/emacs<uid>), so with no
;; writable TMPDIR the server never comes up and emacsclient has nothing to talk
;; to -- with no error shown, because server-start reports the failure only to
;; *Messages*.  Termux's own tmp is owned by the shared UID and carries the same
;; SELinux categories as our data directory, so it is the one scratch area both
;; halves of this pairing can write.  Guarded like PATH above, and falling back
;; inside `user-emacs-directory' so a non-Termux APK still lands somewhere
;; writable instead of /tmp.
(when joe/android-p
  (let ((tmp (if (file-directory-p "/data/data/com.termux/files/usr/tmp")
                 "/data/data/com.termux/files/usr/tmp"
               (expand-file-name "tmp" user-emacs-directory))))
    (make-directory tmp t)
    (setenv "TMPDIR" tmp)
    (setq temporary-file-directory (file-name-as-directory tmp))))

;; Prevent the glimpse of un-styled Emacs by disabling these UI elements early.
(setq load-prefer-newer t)
;; ...except on Android, where the tool bar and menu bar are not chrome, they
;; are the input device.  There is no Ctrl and no Alt on a soft keyboard, so
;; `M-x' lives at Edit -> Execute Command and the modifier bar (see
;; joe-android.el) is the only way to type a modified key sequence at all.  The
;; port's own README is blunt that turning these off on Android is unwise.
(push (cons 'menu-bar-lines (if joe/android-p 1 0)) default-frame-alist)
(push (cons 'tool-bar-lines (if joe/android-p 1 0)) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;; Resizing the Emacs frame can be a terribly expensive part of changing the
;; font. By inhibiting this, we easily halve startup times with fonts that are
;; larger than the system default.
(setq frame-inhibit-implied-resize t)

;; Ignore X resources; its settings would be redundant with the other settings
;; in this file and can conflict with later config (particularly where the
;; cursor color is concerned).
;; Guard: the function only exists on window systems that read X resources,
;; so it is absent on Android.
(when (fboundp 'x-apply-session-resources)
  (advice-add #'x-apply-session-resources :override #'ignore))

;; Collapse every installed package's autoloads into one big file that Emacs
;; loads instead of visiting each package directory in turn. This MUST be set
;; here: `package-activate-all' consults it, and that runs before init.el is
;; read, so the copy that used to live in joe-core.el was evaluated long after
;; the only moment it could have mattered (and the quickstart file was
;; consequently never even generated). Regenerate by hand after editing
;; package state outside Emacs: M-x package-quickstart-refresh.
(setq package-quickstart t)

;; native-comp: reduce verbosity
(setq native-comp-async-report-warnings-errors nil)
(setq warning-suppress-types '((comp)))

;; The x270 is a locked-down console appliance: /home is mounted noexec, so
;; native-compiled .eln files cannot be dlopen'd from the user eln-cache, and
;; there is no GUI at all. Everything keyed off this constant is a no-op on
;; every other machine — an earlier revision set the native-comp variables
;; unconditionally, which disabled native-comp on hosts that could use it.
(defconst joe/console-appliance-p (string= (system-name) "x270")
  "Non-nil on the x270 console appliance (noexec /home, no window system).")

;; Hosts whose Emacs is built by Nix `emacsWithPackages'. On these, packages
;; with native modules or a version-locked CLI — pdf-tools (epdfinfo), jinx
;; (jinx-mod.so), notmuch (elisp must match the notmuch CLI) — are provided by
;; Emacs itself and MUST be `:ensure nil', because MELPA cannot build the
;; native parts here (and on the appliance they could not be dlopen'd from a
;; noexec /home anyway). Pure-elisp packages are unaffected — they still come
;; from MELPA on every host. See ~/nixos-configs/x270-console-appliance/HANDOFF.md
;; §7. Add other Nix hosts (e.g. the x270, once its Emacs is emacsWithPackages)
;; to this list as they migrate.
(defconst joe/nix-emacs-p (member (system-name) '("nixdesktop"))
  "Non-nil on hosts where Emacs packages come from Nix `emacsWithPackages'.")

;; Hosts whose /home is mounted noexec. There, Emacs may not dlopen anything it
;; writes into ~/.emacs.d/eln-cache: the load fails with "failed to map segment
;; from shared object". Interactively that is a message; in the daemon it aborts
;; startup (status=255/EXCEPTION), and systemd then hits its restart limit and
;; gives up, so you get no daemon at all. Emacs's own AOT .eln — and on Nix
;; those of `emacsWithPackages' — live in the read-only store, which IS
;; executable, so they keep working; only JIT output is a problem. Turning JIT
;; off costs some speed and nothing else.
;; Kept separate from `joe/console-appliance-p': that gate is about having no
;; GUI, and the two happen to coincide on the x270 but not elsewhere.
(defconst joe/noexec-home-p (or joe/console-appliance-p joe/nix-emacs-p)
  "Non-nil where $HOME is noexec, so .eln in the user eln-cache cannot load.")

(when joe/noexec-home-p
  ;; Run packages as byte-code; .elc is interpreted, .eln would be dlopen'd.
  (setq native-comp-jit-compilation nil)
  (setq native-comp-enable-subr-trampolines nil))

;; Android reads fonts from ~/fonts (/data/data/org.gnu.emacs/files/fonts) and
;; nowhere else, non-recursively, and the APK ships nothing nerd-patched.
;; Rather than assume either way, look: if the symbols font has been installed
;; there, the icon packages work and should be enabled.  A file test rather
;; than `font-family-list', which is not usable this early -- no frame exists
;; yet, and on Android the font set is only enumerated once one does.
(defconst joe/android-nerd-font-p
  (and joe/android-p
       (file-exists-p (expand-file-name "fonts/SymbolsNerdFontMono-Regular.ttf"
                                        "~")))
  "Non-nil when a Nerd Font has been installed into Android's ~/fonts.
Install SymbolsNerdFontMono-Regular.ttf (for the icon glyphs) alongside
the JetBrainsMono NFM faces (for text); see the Pixel 7a handoff.")

;; Hosts with no nerd-icons-patched font, where the icon packages render a row
;; of replacement boxes rather than glyphs.  Two unrelated causes, same symptom
;; and same fix, so they share a constant:
;;   - the x270's console (kmscon, built without pango) has no fontconfig
;;     fallback at all, so the one configured font must carry the glyph;
;;   - Android, unless a Nerd Font has actually been installed (above).
(defconst joe/no-icon-font-p
  (or joe/console-appliance-p
      (and joe/android-p (not joe/android-nerd-font-p)))
  "Non-nil where no nerd-icons-patched font can be assumed.")

(provide 'early-init)
;;; early-init.el ends here
