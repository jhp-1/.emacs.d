;;; joe-counting-house.el --- Counting House capture, menu, garden walk -*- lexical-binding: t; -*-

;;; Commentary:
;; Operational layer for the Counting House research system (hub note
;; 20260714T173000 in the Denote silo; full manual in note 20260714T191500).
;; Provides capture templates with automatic reading provenance, refile
;; plumbing, org-ql views, the garden-walk layout, a bulk annotation harvest
;; built on the existing pdfannots machinery in joe-research.el, and a
;; transient menu on C-c n c.

;;; Code:

(defun joe/ch--file (id)
  "Path of the Counting House satellite with Denote ID."
  (denote-get-path-by-id id))

(defconst joe/ch-hub-id "20260714T173000")
(defconst joe/ch-ledger-id "20260714T190100")
(defconst joe/ch-commonplace-id "20260714T190200")
(defconst joe/ch-fieldnotes-id "20260714T190300")

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
  "Everything timestamped in the last 35 days, across the satellites."
  (interactive)
  (org-ql-search (joe/ch-refile-files)
    '(ts :from -35)
    :title "Counting House: last month's traces"))

(defun joe/ch-garden-walk ()
  "Ledger on the left, last month's traces on the right."
  (interactive)
  (delete-other-windows)
  (find-file (joe/ch--file joe/ch-ledger-id))
  (split-window-right)
  (other-window 1)
  (joe/ch-recent-traces))

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
  "Counting House."
  [["Capture"
    ("q" "quotation"    (lambda () (interactive) (org-capture nil "cq")))
    ("f" "field note"   (lambda () (interactive) (org-capture nil "cf")))
    ("e" "evidence"     (lambda () (interactive) (org-capture nil "ce")))
    ("Q" "new question" (lambda () (interactive) (org-capture nil "cQ")))
    ("h" "hunch"        (lambda () (interactive) (org-capture nil "ch")))]
   ["Visit"
    ("u" "hub"          (lambda () (interactive) (find-file (joe/ch--file joe/ch-hub-id))))
    ("l" "ledger"       (lambda () (interactive) (find-file (joe/ch--file joe/ch-ledger-id))))
    ("m" "commonplace"  (lambda () (interactive) (find-file (joe/ch--file joe/ch-commonplace-id))))
    ("n" "field notes"  (lambda () (interactive) (find-file (joe/ch--file joe/ch-fieldnotes-id))))]
   ["Views"
    ("?" "live questions" joe/ch-open-questions)
    ("r" "recent traces"  joe/ch-recent-traces)
    ("w" "garden walk"    joe/ch-garden-walk)]
   ["Session"
    ("t" "25-min timer" (lambda () (interactive) (tmr "25" "counting house")))
    ("H" "harvest annotated PDFs" joe/ch-harvest)]])

(define-key global-map (kbd "C-c n c") #'joe/counting-house)

;; The org-transclusion bridge that used to sit here now lives in
;; joe-org-notes.el, as `joe/denote-transclusion-add', alongside the denote and
;; denote-org blocks. It was generic denote glue rather than Counting House
;; machinery, and it had never run: it was guarded on org-transclusion being
;; loaded, and the package was not installed. It is installed now.

(provide 'joe-counting-house)
;;; joe-counting-house.el ends here
