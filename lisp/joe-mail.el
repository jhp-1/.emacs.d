;;; joe-mail.el --- Notmuch mail + msmtp sending -*- lexical-binding: t; -*-

;; Mail is three programs and this file glues them together:
;;
;;   mbsync   ~/.mbsyncrc       Gmail IMAP  <-> ~/.mail/gmail/{Inbox,Sent,...}
;;   notmuch  ~/.notmuch-config indexes ~/.mail, provides search and the UI
;;   msmtp    ~/.msmtprc        outgoing SMTP, used as Emacs's sendmail-program
;;
;; Both mbsync and msmtp read their password from the GPG pass store
;; (`pass show email/...'), so no credential is on disk in the clear and Emacs
;; itself never handles it — msmtp does the authenticating.
;;
;; mu4e used to be configured here too. `mu' is not installed on this machine
;; and notmuch does the same job, so that half is gone; recover it from git if
;; a future box wants it.

(require 'auth-source-pass)
(require 'message)
(require 'sendmail)

;; Lives in notmuch-mua.el, which notmuch.el does not pull in at :config time.
;; Only the symbol is referenced here (it goes on a hook); by the time the hook
;; runs, composing a message has loaded the file.
(declare-function notmuch-mua-attachment-check "notmuch-mua")

;;;;; Identity

(setq user-full-name "Joe"
      user-mail-address "josephheberpercy@gmail.com")

;;;;; Credentials
;; Make the GPG-encrypted ~/.password-store a backend for auth-source, so API
;; keys (e.g. openrouter.ai) are read decrypted on demand rather than living in
;; a plaintext ~/.authinfo.  Harmless on hosts without a pass store —
;; auth-source just falls through to its other sources.
(auth-source-pass-enable)

;;;;; Sending
;; Hand the message to msmtp rather than opening an SMTP connection from Emacs:
;; msmtp already knows the account, and Emacs never sees the password.
(setq message-send-mail-function #'message-send-mail-with-sendmail
      sendmail-program (cond ((eq system-type 'windows-nt) "msmtp.cmd")
                             (t "msmtp"))
      ;; Never let Emacs pass "-f address" — msmtp picks the account itself
      ;; from the From: header, which is what --read-envelope-from does.
      message-sendmail-f-is-evil t
      message-sendmail-extra-arguments '("--read-envelope-from")
      message-kill-buffer-on-exit t)

;;;;; Notmuch

(use-package notmuch
  ;; Provided by Nix (emacs-packages-deps), not MELPA.
  :ensure nil
  :defer t
  :bind (("C-c d" . notmuch-jump-search)
         ("C-x m" . notmuch-mua-new-mail)
         ;; joe/notmuch-inbox and joe/notmuch-unread are deliberately NOT bound
         ;; here: :bind implies :commands, so use-package would emit autoload
         ;; stubs claiming those commands live in notmuch.el, which does not
         ;; define them.  They are bound at the bottom of this file instead.
         ("C-c M" . notmuch))
  :config
  (setq notmuch-command (cond ((eq system-type 'windows-nt) "notmuch.cmd")
                              (t "notmuch")))

  ;; Gmail's SMTP server files a copy of everything it sends into
  ;; [Gmail]/Sent Mail by itself, and mbsync pulls that back down.  Letting
  ;; notmuch Fcc as well would store every sent message twice.
  (setq notmuch-fcc-dirs nil)

  (setq notmuch-show-logo nil
        notmuch-column-control 1.0
        notmuch-hello-auto-refresh t
        notmuch-hello-recent-searches-max 20
        notmuch-hello-thousands-separator ""
        notmuch-hello-sections '(notmuch-hello-insert-saved-searches)
        notmuch-show-all-tags-list t)
  ;; Newest mail at the top. notmuch's own default is t (oldest first), and it
  ;; is read at search time rather than baked in, so this is the whole fix for
  ;; the ordering — but saved searches can carry their own `:sort-order', so
  ;; those below set it explicitly rather than relying on this.
  (setq notmuch-search-oldest-first nil)

  ;; Complete addresses from mail already indexed, no external command.
  (setq notmuch-address-command 'internal)

  ;; Postponed drafts (C-c C-p) go into the synced Drafts maildir rather than
  ;; the default top-level "drafts", so mbsync pushes them to Gmail and they
  ;; are reachable from the phone.  Path is relative to the database root.
  (setq notmuch-draft-folder "gmail/Drafts")

  ;; Refuse to send a message that says "attached" with nothing attached.
  (add-hook 'notmuch-mua-send-hook #'notmuch-mua-attachment-check)

  ;; Unread threads stand out in the search list; everything else inherits the
  ;; theme.  Kept to two rules so the modus palette still does the work.
  (setq notmuch-search-line-faces
        '(("unread" . notmuch-search-unread-face)
          ("flagged" . notmuch-search-flagged-face)))

  (setq notmuch-saved-searches
        '((:name "inbox"   :query "tag:inbox"  :key "i" :sort-order newest-first)
          (:name "unread"  :query "tag:unread" :key "u" :sort-order newest-first)
          (:name "flagged" :query "tag:flagged":key "f" :sort-order newest-first)
          (:name "sent"    :query "tag:sent"   :key "s" :sort-order newest-first)
          (:name "drafts"  :query "tag:draft"  :key "d" :sort-order newest-first)
          (:name "today"   :query "date:today" :key "t" :sort-order newest-first)
          (:name "all"     :query "*"          :key "a" :sort-order newest-first))))

;;;;; Jumping straight to a view
;; `C-c M' opens notmuch-hello and needs a second keystroke; these are the two
;; views actually wanted from cold, so they get their own keys. Both go through
;; `notmuch-search' with OLDEST-FIRST nil, so ordering does not depend on the
;; global default having been applied.

(declare-function notmuch-search "notmuch")

(defun joe/notmuch-inbox ()
  "Show the inbox, newest first."
  (interactive)
  (require 'notmuch)
  (notmuch-search "tag:inbox" nil))

(defun joe/notmuch-unread ()
  "Show unread mail, newest first."
  (interactive)
  (require 'notmuch)
  (notmuch-search "tag:unread" nil))

(keymap-global-set "C-c I" #'joe/notmuch-inbox)
(keymap-global-set "C-c U" #'joe/notmuch-unread)

;;;;; Syncing
;; The actual work — mbsync, notmuch new, tagging, and the desktop
;; notification — lives in ~/.local/bin/mail-sync, which a systemd user timer
;; runs every 30 minutes whether or not Emacs is up:
;;
;;     systemctl --user status mail-sync.timer
;;     journalctl --user -u mail-sync -e
;;
;; Emacs shells out to that same script rather than reimplementing it, so the
;; tag rules have exactly one definition. Two reasons it is a script and not
;; elisp: mail must sync with Emacs closed, and a 7000-message `notmuch new'
;; in-process would block redisplay while you type.
;;
;; (The tagging would more naturally be a notmuch post-new hook, but notmuch
;; exec's hooks directly and /home is mounted noexec — hence a script invoked
;; through `bash', both here and in the systemd unit.)

(defvar joe/mail-sync-buffer "*mail sync*"
  "Buffer holding mbsync/notmuch output for the last sync.")

(defvar joe/mail--sync-process nil
  "The in-flight sync process, or nil.")

(defconst joe/mail-sync-script (expand-file-name "~/.local/bin/mail-sync")
  "Shared sync script, also driven by the mail-sync systemd user timer.")

;; WHICH TAGS REACH GMAIL, AND WHICH DO NOT
;;
;; `maildir.synchronize_flags' in ~/.notmuch-config makes notmuch write tags
;; back into maildir filename flags, which mbsync then pushes.  But notmuch
;; only maps five of them (notmuch-properties(7)):
;;
;;     D draft    F flagged    P passed    R replied    S unread
;;
;; There is deliberately NO mapping for `deleted'.  So tagging a thread
;; +deleted — including via the `notmuch-show-mark-read-tags' style bindings
;; and the Trash rule above — changes nothing on the server: the tag only
;; hides the thread locally, because `search.exclude_tags' filters it out of
;; searches.  The mail stays in Gmail indefinitely.
;;
;; Read/unread, flagged and replied DO round-trip, so marking something read
;; here marks it read on the phone.  Archiving and deleting do not, and making
;; them propagate means moving the message FILE between maildirs (Inbox ->
;; Trash) or removing it, so mbsync replays that as a label change.  That is
;; not implemented here — see the README note before relying on `d'.

(defun joe/mail--sync-sentinel (proc event)
  (unless (process-live-p proc)
    (setq joe/mail--sync-process nil)
    (when (fboundp 'notmuch-refresh-all-buffers)
      (notmuch-refresh-all-buffers))
    (if (and (eq (process-status proc) 'exit)
             (zerop (process-exit-status proc)))
        (message "Mail synced.")
      (message "Mail sync failed (%s) — see %s"
               (string-trim event) joe/mail-sync-buffer))))

(defun joe/mail-sync (&optional archive)
  "Fetch, index and tag mail by running `joe/mail-sync-script'.
Runs in the background; the modeline reports the outcome and notmuch
buffers refresh when it finishes.  With a prefix argument ARCHIVE, also
sync the large [Gmail]/All Mail channel."
  (interactive "P")
  (require 'notmuch)
  (if (process-live-p joe/mail--sync-process)
      (message "Mail sync already running.")
    (with-current-buffer (get-buffer-create joe/mail-sync-buffer)
      (erase-buffer))
    (message "Syncing mail%s..." (if archive " (including archive)" ""))
    (setq joe/mail--sync-process
          ;; Through `bash' explicitly: /home is noexec, so the script's +x bit
          ;; does not make it executable.  Same reason as the systemd unit.
          (apply #'start-process "mail-sync" joe/mail-sync-buffer
                 "bash" joe/mail-sync-script
                 (and archive '("--archive"))))
    (set-process-sentinel joe/mail--sync-process #'joe/mail--sync-sentinel)))

;; The old name, kept because muscle memory and the README both use it.
(defalias 'mailupdate #'joe/mail-sync)

(keymap-global-set "C-c u" #'joe/mail-sync)

;; There is deliberately no Emacs-side periodic sync. The schedule belongs to
;; mail-sync.timer, which keeps running with Emacs closed and cannot touch
;; redisplay; an Emacs timer would satisfy neither. `C-c u' remains for syncing
;; on demand.

;; The sync buffer is for reading after a failure, not for stealing a window.
(add-to-list 'display-buffer-alist
             (cons (regexp-quote joe/mail-sync-buffer)
                   '((display-buffer-no-window) (allow-no-window . t))))

(provide 'joe-mail)
;;; joe-mail.el ends here
