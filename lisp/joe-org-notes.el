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
;; Guarded: `directory-files-recursively' signals if the directory is absent,
;; and because this sits inside org's :config that would abort the entire
;; block - taking `org-capture-templates' and everything after it with it.
;; A missing notes dir should cost you the agenda, not the whole org setup.
(setq org-agenda-files
      (when (file-directory-p joe/notes-dir)
        (directory-files-recursively joe/notes-dir "\\.org\\'")))
  (setq org-startup-folded 'fold)
  (setq org-todo-keywords
        '((sequence "TODO(t)" "CANCEL(c!)" "DONE(d!)")))

  :hook
  (org-mode . abbrev-mode))

;;;;; Capture templates
;; Keyed on `org-capture', NOT `org' - `org-capture-templates' is a defcustom
;; in org-capture.el, so loading org alone does not define it. Every place
;; that touches the variable (here, the career templates below, and
;; joe-counting-house.el) uses the same guard, so ordering follows init.el's
;; require order rather than which feature happens to load first. This block
;; must `setq' before the others `add-to-list', which it does because
;; joe-org-notes is required first.
(with-eval-after-load 'org-capture
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
           :jump-to-captured t))))

;;;; Career roadmap
;; Merged in from the former joe-career.el: one capture template, two denote
;; keywords, one org-ql view and a keybinding is settings for a single org
;; file, not a subsystem. (joe-counting-house.el stays separate - that one is
;; a real subsystem with its own transient menu and harvest machinery.)
(defconst joe/career-applications-file
  (expand-file-name "career/20260624T102500--job-applications__career.org" joe/notes-dir)
  "Denote note the job-application capture template files into.
Lives in the `career/' project silo (git repo), not the notes root.")

(with-eval-after-load 'denote
  (dolist (kw '("career" "project"))
    (add-to-list 'denote-known-keywords kw)))

(defun joe/applications-open ()
  "List open job applications via `org-ql' - TODOs whose STATUS is not offer/rejected."
  (interactive)
  (require 'org-ql)
  (org-ql-search (list joe/career-applications-file)
    '(and (todo "TODO")
          (property "STATUS")
          (not (property "STATUS" "offer"))
          (not (property "STATUS" "rejected")))))

;; Was previously defined inside a `with-eval-after-load 'org' block, so the
;; binding silently did not exist until org happened to load. It has no reason
;; to wait on org: the command requires what it needs itself.
(keymap-global-set "C-c n A" #'joe/applications-open)

(with-eval-after-load 'org-capture
  (add-to-list 'org-capture-templates
               `("a" "Job application / outreach" entry
                 (file+headline ,joe/career-applications-file "Applications")
                 ,(concat
                   "* TODO %^{Firm} — %^{Role} :%^{Lane|rulesascode|analytics|aicompliance|apprenticeship}:\n"
                   ":PROPERTIES:\n"
                   ":ADDED:    %U\n"
                   ":STATUS:   %^{Status|applied|replied|call|interview|offer|rejected}\n"
                   ":END:\n"
                   "- Next action: %^{Next action}\n%?")
                 :empty-lines 1)
               t))

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
