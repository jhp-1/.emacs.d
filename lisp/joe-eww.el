;;; joe-eww.el --- eww, the built-in text web browser -*- lexical-binding: t; -*-

;; Split out of joe-tools.el. eww is the one thing in this configuration that
;; needs no external program whatsoever, which matters on Android: it is half
;; of what that machine is for, while everything else joe-tools.el configures
;; (magit, rg, ghostel, eshell, bluetooth) is either unavailable there or
;; actively breaks -- bluetooth `require's dbus at load time, so reaching eww
;; through joe-tools.el would have failed outright.

;;;; eww
(use-package eww
  :ensure nil
  :init
  (setq browse-url-browser-function #'eww-browse-url)
  :config
  (setq eww-search-prefix "https://duckduckgo.com/html/?q=")
  (setq eww-download-directory
        ;; ~/Downloads is Emacs's own private app directory on Android
        ;; (/data/data/org.gnu.emacs/files/Downloads) -- nothing else on the
        ;; phone can see a file put there. /sdcard/Download is the directory
        ;; the system Files app and every other program actually opens, and it
        ;; needs only the ordinary storage permission (Settings -> Special App
        ;; Access on Android 11+), not the Termux variant of the APK.
        (if (bound-and-true-p joe/android-p) "/sdcard/Download/" "~/Downloads/"))
  (setq eww-history t)
  (setq eww-auto-rename-buffer 'title)
  (setq eww-readable-urls
	'("https://plato.stanford.edu/.*"
          "https://www.marxists.org/.*"
	  "https://splash247.com/.*"
	  "https://theloadstar.com/.*"
          ("https://en.wikipedia.org/.*" . t)))
  :bind
  ("C-c e" . eww)
  (:map eww-mode-map
        ("M-n" . eww-next-url)
        ("M-p" . eww-previous-url)))

;;;; Android
;; eww is the best-behaved thing on the Android port, and for a structural
;; reason: an eww buffer is read-only, so Android's text conversion (see
;; joe-android.el) never engages, and its own bindings -- n p l g w d & S R --
;; are already single unmodified letters. Once a page is on screen it needs no
;; modifier key at all. Getting *into* it is the only part that wants `M-x',
;; which is why joe-android.el puts eww on the tool bar.
(when (bound-and-true-p joe/android-p)
  ;; shr's variable-pitch layout assumes desktop-ish widths; at phone width the
  ;; proportional metrics make tables and multi-column pages reflow badly.
  ;; Fixed-pitch is uglier and correct.
  (setq shr-use-fonts nil)
  ;; Cap images at a fraction of the window rather than letting a hero image
  ;; take the whole screen and push the text below the fold.
  (setq shr-max-image-proportion 0.4)

  (defun joe/android-browse-external (url &rest _ignore)
    "Open URL in Android's default browser, leaving eww behind.
For the pages eww cannot render -- anything that is really an
application rather than a document. Shells out to Android's `am',
which comes from Termux, so this needs the shared-UID (`termux/')
APK; without it there is no `am' on `exec-path' and the command
reports as much rather than failing silently.

The scheme is not optional: `am' errors on a bare host name, so
\"example.com\" is rejected where \"https://example.com\" works."
    (interactive
     ;; In eww, act on the page being read -- no prompt. Elsewhere, ask.
     (list (or (and (derived-mode-p 'eww-mode) (bound-and-true-p eww-current-url))
               (read-string "URL: " "https://"))))
    (unless (executable-find "am")
      (user-error "No `am' on `exec-path' -- Termux is not reachable from this APK"))
    (unless (string-match-p "\\`[a-zA-Z][-+.a-zA-Z0-9]*:" url)
      (user-error "`am' needs a scheme: try https://%s" url))
    (call-process "am" nil 0 nil
                  "start" "-a" "android.intent.action.VIEW" "-d" url))

  ;; Set as the SECONDARY browser rather than rebound onto a key. eww's own `&'
  ;; (`eww-browse-with-external-browser') already dispatches through this
  ;; variable, so `&' keeps meaning what its documentation says it means, and
  ;; every other "open this elsewhere" caller in Emacs picks it up too. The
  ;; primary browser stays eww -- the default here is
  ;; `browse-url-default-browser', which on Android would land back in eww.
  (setq browse-url-secondary-browser-function #'joe/android-browse-external))

;; There is no incoming direction to configure: Android has no share-target
;; integration for Emacs and no URL-scheme handler for org-protocol, so getting
;; a link from Chrome into Emacs is copy, switch app, yank.

(provide 'joe-eww)
;;; joe-eww.el ends here
