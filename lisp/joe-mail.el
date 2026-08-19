;;; joe-mail.el --- Email configuration -*- lexical-binding: t; -*-

;;;;; Mu4e
(use-package mu4e
  :ensure nil
  :defer t
  :config
  (setq mu4e-maildir "~/.mail/gmail")
  (setq mu4e-drafts-folder "/Drafts")
  (setq mu4e-sent-folder   "/Sent")
  (setq mu4e-trash-folder  "/Trash")

  (setq mu4e-get-mail-command
        (cond
         ((eq system-type 'windows-nt) "mbsync.cmd -a")
         ((memq system-type '(gnu/linux darwin)) "mbsync -a")))
  (setq mu4e-update-interval 300)

  (setq mu4e-maildir-shortcuts
        '( ("/Inbox"    . ?i)
	   ("/Sent"     . ?s)
	   ("/Drafts"   . ?d)
	   ("/Trash"    . ?t))))

;;;;; Notmuch
(setq message-sendmail-f-is-evil t)
(setq message-sendmail-extra-arguments '("--read-envelope-from"))

(setq notmuch-fcc-dirs nil)  ; Avoids duplicating sent messages

(setq notmuch-maildir "~/.mail/gmail")

(setq notmuch-command
      (cond
       ((eq system-type 'windows-nt) "notmuch.cmd")
       ((memq system-type '(gnu/linux darwin)) "notmuch")))

(setq message-send-mail-function 'message-send-mail-with-sendmail)
(setq sendmail-program
      (cond
       ((eq system-type 'windows-nt) "msmtp.cmd")
       ((memq system-type '(gnu/linux darwin)) "msmtp")))

;;;;; Credentials from pass, not plaintext ~/.authinfo
;; Make the GPG-encrypted ~/.password-store a backend for auth-source, so
;; mbsync/msmtp passwords and API keys (e.g. openrouter.ai) are read decrypted
;; on demand. Harmless on hosts without a pass store — auth-source just falls
;; through to its other sources.
(require 'auth-source-pass)
(auth-source-pass-enable)

(use-package notmuch
  :ensure nil
  :defer t
  :config
  (setq notmuch-show-logo nil)
  (setq notmuch-column-control 1.0)
  (setq notmuch-hello-auto-refresh t)
  (setq notmuch-hello-recent-searches-max 20)
  (setq notmuch-hello-thousands-separator "")
  (setq notmuch-hello-sections '(notmuch-hello-insert-saved-searches))
  (setq notmuch-show-all-tags-list t)
  (setq-default notmuch-search-oldest-first nil)
  :bind
  ("C-c d" . notmuch-jump-search)
  ("C-x m" . notmuch-mua-new-mail))

(defun mailupdate ()
  "Update notmuch."
  (interactive)
  (async-shell-command
   (cond
    ((eq system-type 'windows-nt) "mailupdate.cmd")
    ((memq system-type '(gnu/linux darwin)) "mailupdate.sh")))
  (notmuch-refresh-all-buffers))

(add-to-list 'display-buffer-alist
             (cons (regexp-quote shell-command-buffer-name-async)
                   '((display-buffer-no-window))))

(provide 'joe-mail)
;;; joe-mail.el ends here
