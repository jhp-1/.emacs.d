;;; joe-org-notes.el --- Org mode and note-taking configuration -*- lexical-binding: t; -*-

;;;; jinx
(use-package jinx
  :ensure t
  :if (executable-find "aspell")
  :hook (org-mode . jinx-mode)
  :bind
  (:map org-mode-map
        ("M-$" . jinx-correct))
  :config
  (add-to-list 'jinx-exclude-regexps '("@@.*?@@"))  ; Don't check spell in org @ macros
  (add-to-list 'jinx-exclude-regexps '("~.*?~"))     ; Don't check spell in verbatim
  (add-to-list 'jinx-exclude-regexps '("=.*?=")))    ; Don't check spell in code

;;;; Org
(use-package org
  :bind
  ("C-c c" . org-capture)
  ("C-c a" . org-agenda)
  :config
  (setq org-M-RET-may-split-line '((default . nil)))
  (setq org-insert-heading-respect-content t)
  (setq org-log-done 'time)
  (setq org-log-into-drawer t)
  (setq org-enforce-todo-dependencies t)
  (setq org-hide-emphasis-markers t)
  (setq org-use-speed-commands t)
  (setq org-goto-max-level 3)
  (setq org-hide-block-startup t)
  ;; Use joe/notes-dir so this works from both Windows and WSL Emacs.
(setq org-agenda-files
      (directory-files-recursively joe/notes-dir "\\.org\\'"))
  (setq org-startup-folded 'fold)
  (setq org-capture-templates
        `(("l" "Link" entry
           (file+headline ,(expand-file-name "20240410T184722--reading-list__life_reading.org" joe/notes-dir) "Websites")
           "* %?\n  %a")
          ("t" "Task" entry
           (file ,(expand-file-name "20241021T152220--tasks.org" joe/notes-dir))
           "* TODO %?\n  SCHEDULED: %t")

          ("n" "New note (with Denote)" plain
           (file denote-last-path)
           #'denote-org-capture
           :no-save t
           :immediate-finish nil
           :kill-buffer t
           :jump-to-captured t)

          ("j" "Denote journal entry for TODAY" plain
           (file denote-last-path)
           #'denote-journal-new-or-existing-entry
           :no-save t
           :immediate-finish nil
           :kill-buffer t
           :jump-to-captured t)))
  (setq org-todo-keywords
        '((sequence "TODO(t)" "CANCEL(c!)" "DONE(d!)")))

  :hook
  (org-mode . abbrev-mode))

;;;;; org-modern
(use-package org-modern
  :ensure t
  :hook
  (org-mode . org-modern-mode)
  (org-agenda-finalize . org-modern-agenda))

;;;; denote
(use-package denote
  :ensure t
  :config
  ;; joe/notes-dir resolves to d:/Notes on Windows, /mnt/d/Notes in WSL.
  (setq denote-directory (expand-file-name joe/notes-dir))
  (setq denote-dired-directories
        (list denote-directory
              (expand-file-name "attachments" denote-directory)))
  (setq denote-infer-keywords nil)
  (setq denote-sort-keywords t)
  (setq denote-prompts '(title keywords))
  (setq denote-excluded-directories-regexp nil)
  (setq denote-excluded-keywords-regexp nil)
  (setq denote-known-keywords '("people" "methods" "entities" "concepts" "material" "events" "personal"))
  :bind
  ( :map global-map
    ("C-c n n" . denote-open-or-create)
    ("C-c n s" . denote-subdirectory)
    ("C-c n o" . denote-sort-dired)
    ("C-c n r" . denote-rename-file)))

(add-hook 'dired-mode-hook #'denote-dired-mode-in-directories)

;;;;; denote-journal
(use-package denote-journal
  :ensure t
  :commands ( denote-journal-new-entry
              denote-journal-new-or-existing-entry
              denote-journal-link-or-create-entry )
  :bind
  ("C-c j" . denote-journal-new-or-existing-entry)
  :hook (calendar-mode . denote-journal-calendar-mode)
  :config
  (setq denote-journal-directory
        (expand-file-name "journal" joe/notes-dir))
  (setq denote-journal-keyword "journal")
  (setq denote-journal-title-format 'day-date-month-year))

;;;; org-ql
(use-package org-ql
  :ensure t
  :defer t
  :bind
  ("C-c n q" . org-ql-search))

;;;;; citar-denote


(provide 'joe-org-notes)
;;; joe-org-notes.el ends here
