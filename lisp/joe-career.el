;;; joe-career.el --- Career roadmap: capture, agenda, applications -*- lexical-binding: t; -*-

;; Roadmap-specific config. Kept isolated from joe-org-notes.el on purpose;
;; required right after it in init.el. See the career-roadmap Denote note.

(require 'joe-core)                      ; joe/notes-dir

(defconst joe/career-applications-file
  (expand-file-name "career/20260624T102500--job-applications__career.org" joe/notes-dir)
  "Denote note the job-application capture template files into.
Lives in the `career/' project silo (git repo), not the notes root.")

;;;; Denote keywords used by the career notes
(with-eval-after-load 'denote
  (dolist (kw '("career" "project"))
    (add-to-list 'denote-known-keywords kw)))

;;;; Capture: job application / outreach  (C-c c a)
(with-eval-after-load 'org
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
               t)

  ;; Agenda: the roadmap view  (C-c a r)
  ;; (add-to-list 'org-agenda-custom-commands
  ;;              '("r" "Career roadmap"
  ;;                ((agenda "" ((org-agenda-span 7)
  ;;                             (org-agenda-overriding-header "Next 7 days — roadmap actions")))
  ;;                 (tags-todo "economics"
  ;;                            ((org-agenda-overriding-header "Economics bridge — syllabus modules & reading")))
  ;;                 (tags-todo "rulesascode"
  ;;                            ((org-agenda-overriding-header "Primary lane (LOCKED): rules-as-code")))
  ;;                 (tags-todo "analytics|aicompliance"
  ;;                            ((org-agenda-overriding-header "Other primary lanes")))
  ;;                 (tags-todo "apprenticeship"
  ;;                            ((org-agenda-overriding-header "Hedge: apprenticeships")))))
  ;;              t)

  (define-key global-map (kbd "C-c n A") #'joe/applications-open))
;;;; Open applications (STATUS not offer/rejected)  (C-c n A)
(defun joe/applications-open ()
  "List open job applications via `org-ql' — TODOs whose STATUS is not offer/rejected."
  (interactive)
  (require 'org-ql)
  (org-ql-search (list joe/career-applications-file)
    '(and (todo "TODO")
          (property "STATUS")
          (not (property "STATUS" "offer"))
          (not (property "STATUS" "rejected")))))

(provide 'joe-career)
;;; joe-career.el ends here
