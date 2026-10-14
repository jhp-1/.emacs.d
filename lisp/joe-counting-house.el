;;; joe-counting-house.el --- Study, browsing, capture and review -*- lexical-binding: t; -*-

;;; Commentary:
;; Counting House is a collection used for study and local inquiries.
;; The starting note is 20260714T173000; the study and writing guide is
;; 20260714T191500. The menu exposes existing Denote and Org commands,
;; alongside provenance captures, review views and PDF annotation harvest.

;;; Code:

(defun joe/ch--file (id)
  "Return the path of the Counting House note with Denote ID."
  (or (denote-get-path-by-id id)
      (user-error "No note with Denote identifier %s in %s" id denote-directory)))

(defconst joe/ch-hub-id "20260714T173000")
(defconst joe/ch-ledger-id "20260714T190100")
(defconst joe/ch-commonplace-id "20260714T190200")
(defconst joe/ch-fieldnotes-id "20260714T190300")
(defconst joe/ch-guide-id "20260714T191500")

(defun joe/ch-provenance ()
  "One-line provenance for the buffer being read."
  (cond
   ((derived-mode-p 'pdf-view-mode)
    (format "[cite:@%s] p.%s"
            (file-name-base (buffer-file-name))
            (pdf-view-current-page)))
   ((derived-mode-p 'nov-mode)
    (format "%s (EPUB, section %s)"
            (file-name-base nov-file-name)
            (1+ nov-documents-index)))
   ((buffer-file-name)
    (format "[[file:%s]]" (buffer-file-name)))
   (t (buffer-name))))

(defun joe/ch-provenance-from-origin ()
  "Provenance of the buffer org-capture was called from."
  (with-current-buffer (org-capture-get :original-buffer)
    (joe/ch-provenance)))

(with-eval-after-load 'org-capture
  (dolist (tpl
           `(("c" "Counting House")
             ("cq" "Quotation → commonplace inbox" entry
              (file+headline ,(lambda () (joe/ch--file joe/ch-commonplace-id)) "Inbox")
              "* %^{head hint|unfiled}\n#+begin_quote\n%i%?\n#+end_quote\n%(joe/ch-provenance-from-origin) · %U\n%a"
              :empty-lines 1)
             ("cf" "Field note → datetree" entry
              (file+olp+datetree ,(lambda () (joe/ch--file joe/ch-fieldnotes-id)))
              "* %U %?\n%a" :empty-lines 1)
             ("cQ" "New question → ledger" entry
              (file+headline ,(lambda () (joe/ch--file joe/ch-ledger-id)) "Questions")
              "* OPEN %^{the question}\n:PROPERTIES:\n:OPENED: %u\n:END:\n** State\nUnformed. %?\n** Evidence\n"
              :empty-lines 1)
             ("ch" "Hunch → ledger" entry
              (file+headline ,(lambda () (joe/ch--file joe/ch-ledger-id)) "Hunches")
              "* %^{the hunch} :hunch:\n- felt confidence :: %^{confidence|low|medium-low|medium|medium-high}\n- logged :: %u\n- note :: %?"
              :empty-lines 1)
             ("ce" "Evidence → ledger inbox" entry
              (file+headline ,(lambda () (joe/ch--file joe/ch-ledger-id)) "Evidence inbox")
              "* %U %?\n%(joe/ch-provenance-from-origin)\n%a" :empty-lines 1)))
    (add-to-list 'org-capture-templates tpl t)))

(defun joe/ch-refile-files ()
  "Counting House refile targets."
  (list (joe/ch--file joe/ch-ledger-id)
        (joe/ch--file joe/ch-commonplace-id)))

(defun joe/ch-trace-files ()
  "Notes searched by the recent-records view.
This includes field notes, which are not ordinary refile targets."
  (append (joe/ch-refile-files)
          (list (joe/ch--file joe/ch-fieldnotes-id))))

(with-eval-after-load 'org
  (setq org-refile-targets '((nil :maxlevel . 3)
                             (joe/ch-refile-files :maxlevel . 3)))
  (setq org-refile-use-outline-path 'file)
  (setq org-outline-path-complete-in-steps nil)
  (define-key global-map (kbd "C-c l") #'org-store-link))

(defun joe/ch-open-questions ()
  "Live questions, by my own statuses."
  (interactive)
  (org-ql-search (joe/ch--file joe/ch-ledger-id)
    '(todo "OPEN" "SHARPENED")
    :title "Counting House: live questions"))

(defun joe/ch-recent-traces ()
  "Show timestamped records from the last 35 days.
This is a view of what was recorded, not a measure of reading activity."
  (interactive)
  (org-ql-search (joe/ch-trace-files)
    '(ts :from -35)
    :title "Counting House: recent records"))

(defun joe/ch-review ()
  "Show questions beside recent records for an optional review."
  (interactive)
  (delete-other-windows)
  (find-file (joe/ch--file joe/ch-ledger-id))
  ;; `split-window-right' returns the new window, so select it directly rather
  ;; than splitting and then walking to it with `other-window', which depends
  ;; on the cyclic ordering happening to put the new window next.
  (select-window (split-window-right))
  (joe/ch-recent-traces))

(defalias 'joe/ch-garden-walk #'joe/ch-review
  "Compatibility name for `joe/ch-review'. Exploratory walks use Denote Explore.")

(defun joe/ch--pdf-annotated-p (file)
  "Non-nil if FILE's raw bytes mention markup annotation subtypes."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file)
    (goto-char (point-min))
    (re-search-forward "/\\(?:Highlight\\|Underline\\|Squiggly\\|StrikeOut\\)" nil t)))

(defun joe/ch--ensure-note-buffer (citekey)
  "Return the citar-denote note buffer for CITEKEY, creating the note if needed."
  (require 'citar-denote)
  (let ((existing (gethash citekey (citar-denote--get-notes (list citekey)))))
    (if existing
        (find-file-noselect (car existing))
      (save-window-excursion
        (citar-denote--create-note citekey)
        (current-buffer)))))

(defun joe/ch-harvest (days)
  "Harvest annotations from PDFs modified in the last DAYS into literature notes.
Scans the library for PDFs changed within DAYS (default 14; prefix argument
prompts) whose bytes contain highlight or underline annotations and whose
basename is a citekey in the bibliography.  Each match runs the existing
pdfannots importer asynchronously; results merge into each book's
citar-denote note with the usual de-duplication, so re-running is safe."
  (interactive (list (if current-prefix-arg (read-number "Days back: " 14) 14)))
  (require 'citar)
  (require 'cl-lib)
  (let ((cutoff (time-subtract nil (days-to-time days)))
        (started 0)
        (stale 0)
        (unknown '()))
    (dolist (pdf (directory-files (expand-file-name joe/texts-dir) t "\\.pdf\\'"))
      ;; Cheap mtime test first: the byte scan below reads the whole file, and
      ;; the library is thousands of PDFs / several GB.
      (if (not (time-less-p cutoff
                            (file-attribute-modification-time (file-attributes pdf))))
          (cl-incf stale)
        (when (joe/ch--pdf-annotated-p pdf)
          (let ((citekey (file-name-base pdf)))
            (if (citar-get-entry citekey)
                (progn
                  (joe/--run-pdfannots-async pdf (joe/ch--ensure-note-buffer citekey))
                  (cl-incf started))
              (push (file-name-nondirectory pdf) unknown))))))
    (message "Harvest: %d import%s started%s%s"
             started (if (= started 1) "" "s")
             ;; A run that starts nothing is almost always the date window, not a
             ;; broken importer.  Say so rather than reporting a bare zero.
             (if (and (= started 0) (> stale 0))
                 (format "; %d PDF%s not modified within %d day%s (C-u to widen)"
                         stale (if (= stale 1) "" "s") days (if (= days 1) "" "s"))
               "")
             (if unknown
                 (format "; skipped (no citekey): %s" (string-join unknown ", "))
               ""))))

(require 'transient)
(transient-define-prefix joe/counting-house ()
  "Browse, read, write and review the Counting House collection."
  [["Capture"
    ("q" "quotation"    (lambda () (interactive) (org-capture nil "cq")))
    ("f" "field note"   (lambda () (interactive) (org-capture nil "cf")))
    ("e" "evidence"     (lambda () (interactive) (org-capture nil "ce")))
    ("Q" "new question" (lambda () (interactive) (org-capture nil "cQ")))
    ("h" "hunch"        (lambda () (interactive) (org-capture nil "ch")))]
   ["Browse"
    ("b" "note shelf" denote-menu-list-notes)
    ("o" "sorted shelf" denote-sort-dired)
    ("g" "search notes" consult-denote-grep)
    ("i" "find a passage" org-ql-find-in-org-directory)]
   ["Connections"
    (">" "outgoing links" denote-find-link)
    ("<" "incoming passage" denote-find-backlink-with-location)
    ("B" "backlinks" denote-backlinks)]]
  [["Walk"
    ("w" "linked step" denote-explore-random-link)
    ("k" "keyword step" denote-explore-random-keyword)
    ("x" "chosen shelf" denote-explore-random-regex)
    ("W" "anywhere" denote-explore-random-note)]
   ["Visit"
    ("u" "starting note" (lambda () (interactive) (find-file (joe/ch--file joe/ch-hub-id))))
    ("l" "questions"     (lambda () (interactive) (find-file (joe/ch--file joe/ch-ledger-id))))
    ("m" "quotations"    (lambda () (interactive) (find-file (joe/ch--file joe/ch-commonplace-id))))
    ("n" "session notes" (lambda () (interactive) (find-file (joe/ch--file joe/ch-fieldnotes-id))))
    ("G" "study guide"   (lambda () (interactive) (find-file (joe/ch--file joe/ch-guide-id))))]
   ["Review"
    ("?" "live questions" joe/ch-open-questions)
    ("r" "recent records" joe/ch-recent-traces)
    ("R" "review layout"  joe/ch-review)
    ("v" "saved views"    org-ql-view)]]
  [["Session"
    ("t" "25-min timer" (lambda () (interactive) (tmr "25" "counting house")))
    ("H" "harvest annotated PDFs" joe/ch-harvest)]])

(define-key global-map (kbd "C-c n c") #'joe/counting-house)

;; Heading transclusion lives in joe-org-notes.el, under C-c n t.

(provide 'joe-counting-house)
;;; joe-counting-house.el ends here

