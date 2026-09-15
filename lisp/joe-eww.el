;;; joe-eww.el --- eww, the built-in text web browser -*- lexical-binding: t; -*-

;; Split out of joe-tools.el. eww is the one thing in this configuration that
;; needs no external program whatsoever, which matters on Android: it is half
;; of what that machine is for, while everything else joe-tools.el configures
;; (magit, rg, eshell, bluetooth) is either unavailable there or actively
;; breaks -- bluetooth `require's dbus at load time, so reaching eww through
;; joe-tools.el would have failed outright.

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

  (declare-function android-browse-url "android-win" (url &optional send))

  ;; `android-browse-url' rather than a shell-out to `am'. It is native to the
  ;; port (a wrapper over `android-browse-url-internal' in androidselect.c), so
  ;; it needs no Termux, and it handles the URL-encoding and the file:// ->
  ;; content:// conversion that a hand-built `am' command line does not.
  ;;
  ;; The wrapper is not decoration. `android-browse-url' takes (URL &optional
  ;; SEND), where SEND non-nil means "offer this to a mail or messaging app"
  ;; instead of "open it". `browse-url-secondary-browser-function' passes
  ;; NEW-WINDOW as its second argument, so binding the raw function would turn
  ;; every new-window request into a share sheet. Swallow the rest.
  (defun joe/android-browse-external (url &rest _)
    "Open URL in Android's default browser, leaving eww behind.
For the pages eww cannot render -- anything that is really an
application rather than a document."
    (interactive
     ;; In eww, act on the page being read -- no prompt. Elsewhere, ask.
     (list (or (and (derived-mode-p 'eww-mode) (bound-and-true-p eww-current-url))
               (read-string "URL: " "https://"))))
    (android-browse-url url))

  (defun joe/eww-open-clipboard ()
    "Open whatever is on the Android clipboard in eww.
Android has no share-target integration for Emacs and no URL-scheme
handler for org-protocol, so a link found in another browser has to come
across by hand. The port wires Android's clipboard into Emacs's selection
back end, though, which makes the paste half of that one command rather
than a switch to a scratch buffer and a yank."
    (interactive)
    (let ((s (string-trim (or (ignore-errors (gui-get-selection 'CLIPBOARD)) ""))))
      (when (string-empty-p s)
        (user-error "Clipboard is empty"))
      (eww s)))

  ;; NOT `C-c E': joe-core.el already binds that to `joe/find-config-file', and
  ;; joe-eww loads later, so it would have shadowed it silently and only on the
  ;; phone. `C-c A' is the Android prefix (see `joe/android-toggle-text-
  ;; conversion'), which is where a command that exists only here belongs.
  (keymap-global-set "C-c A e" #'joe/eww-open-clipboard)
  ;; And on the tool bar, because the point of this machine is not typing a
  ;; five-tap chord to save a switch to another app.
  (tool-bar-add-item "paste" #'joe/eww-open-clipboard 'joe-tb-clip
                     :help "Open the clipboard URL in eww"
                     :label "Clip->eww")

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
