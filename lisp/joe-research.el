;;; joe-research.el --- Research tools configuration -*- lexical-binding: t; -*-
;;;; Bibliographic Management
;;;;; citar
(use-package citar
  :ensure t
  :demand t
  :custom
  ;; joe/texts-dir resolves to d:/Texts on Windows, /mnt/d/Texts in WSL.
  (citar-bibliography (list (expand-file-name "My Library.bib" joe/texts-dir)))
  (org-cite-insert-processor 'citar)
  (org-cite-follow-processor 'citar)
  (org-cite-activate-processor 'citar)
  (citar-notes-paths (list joe/notes-dir))
  (citar-library-paths (list (file-name-as-directory (expand-file-name joe/texts-dir))))
  :bind
  ("C-c f o" . citar-open-files)
  ("C-c f a" . citar-add-file-to-last-added)
  ("C-c f A" . citar-add-file-to-library)
  :config
  (defun citar-add-file-to-last-added ()
    (interactive)
    (let ((original-buffer (current-buffer))
          (bib-file (car citar-bibliography)))
      (with-temp-buffer
        (insert-file-contents bib-file)
        (end-of-buffer)
        (search-backward "@")
        (search-forward "{")
        (set-mark (point))
        (search-forward ",")
        (backward-char)
        (let ((last-citekey (buffer-substring-no-properties (mark) (point))))
          (pop-to-buffer original-buffer)
          (citar-add-file-to-library last-citekey))))))
(use-package citar-denote
  :ensure t
  :demand t ;; Ensure minor mode loads
  :after (:any citar denote)
  :hook
  (citar-mode . citar-denote-mode)
  :config
  (setq citar-denote-keyword "material")
  (setq citar-denote-use-bib-keywords t)
  :init
  (citar-denote-mode)
  :bind
  ("C-c f n" . citar-create-note)
  ("C-c f r" . joe/insert-reading-list-entry))
(use-package citar-embark
  :ensure t
  :after citar embark
  :no-require
  :config (citar-embark-mode))

;;;;; recoll
(use-package consult-recoll
  :ensure t
  :after embark
  :config
  (setq consult-recoll-group-by-mime nil)
  (setq consult-recoll-inline-snippets t)
  (consult-recoll-embark-setup))
;;;;; zotra
(use-package zotra
  :ensure t
  :demand t
  :bind (("C-c f z" . zotra-add-entry))
  :custom
  (zotra-backend 'zotra-server)
  (zotra-local-server-directory nil)
  (zotra-server-path "http://127.0.0.1:1969")
  (zotra-default-bibliography (list (expand-file-name "My Library.bib" joe/texts-dir)))
  (zotra-default-entry-format "bibtex")
  (zotra-use-curl nil)
  (zotra-default-entry-fields
   '(author title journal year volume number pages doi url abstract)))

(when (eq system-type 'windows-nt)
  ;; MinGW64 DLLs must come before Git for Windows
  (setenv "PATH" (concat "C:\\msys64\\mingw64\\bin;" (getenv "PATH")))
  (add-to-list 'exec-path "C:/msys64/mingw64/bin")
  (setq pdf-info-epdfinfo-program "C:/msys64/mingw64/bin/epdfinfo.exe")
  ;; epdfinfo requires unix line endings
  (prefer-coding-system 'utf-8-unix))
;;;;; pdf-tools
(use-package pdf-tools
  :ensure t
  :demand t
  :pin melpa
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :bind
  (:map pdf-view-mode-map
        ("C-s"     . isearch-forward)
        ("h"       . pdf-view-previous-page)
        ("n"       . pdf-view-next-page)
        ("<mouse-8>" . pdf-view-previous-page)
        ("<mouse-9>" . pdf-view-next-page)
        ("SPC"     . pdf-view-next-page)
        ("S-SPC"   . pdf-view-previous-page)
        ("C-<f4>"  . pdf-annot-add-underline-markup-annotation)
        ("DEL"     . pdf-view-previous-page)
        ("g"       . revert-buffer-quick))

  :config
  (pdf-tools-install :no-query)
  (setq-default pdf-view-midnight-colors                    
		(cons (frame-parameter nil 'foreground-color)    
                      (frame-parameter nil 'background-color)))
  (setq pdf-view-resize-factor 1.025)
  (setq-default pdf-view-display-size 'fit-height)
  ;; pdf-annot is loaded lazily inside pdf-tools; guard so the setf
  ;; doesn't fire before pdf-annot.el has been required.
  (with-eval-after-load 'pdf-annot
    (setf (alist-get 'underline pdf-annot-default-annotation-properties)
	  '((color . "red"))))
  :hook
  (pdf-view-mode . pdf-view-midnight-minor-mode))

(use-package saveplace-pdf-view
  :ensure t
  :init
  (save-place-mode 1))

;;;; PDF metadata
(defun joe/citar--files-by-citekey (citekey)
  "Find PDFs in `citar-library-paths' whose basename matches CITEKEY."
  (seq-filter #'file-exists-p
              (mapcan (lambda (dir)
                        (mapcar (lambda (ext)
                                  (expand-file-name (concat citekey ext) dir))
                                '(".pdf" ".PDF")))
                      citar-library-paths)))

(defun joe/citar--clean-bibtex-value (value)
  "Strip LaTeX markup from a BibTeX field VALUE."
  (when value
    (let ((s value))
      (setq s (replace-regexp-in-string "{{\\([^}]*\\)}}" "\\1" s))
      (setq s (replace-regexp-in-string "{\\([^}]*\\)}" "\\1" s))
      (setq s (replace-regexp-in-string "\\\\textendash{?}?" "\u2013" s))
      (setq s (replace-regexp-in-string "\\\\[a-zA-Z]+{?}?" "" s))
      (string-trim s))))

(defun joe/citar--write-pdf-metadata (citekey file)
  "Write bibtex title/author/year for CITEKEY to FILE via exiftool."
  (let* ((title (joe/citar--clean-bibtex-value (citar-get-value "title" citekey)))
         (author (or (joe/citar--clean-bibtex-value (citar-get-value "author" citekey))
                     (when-let ((ed (joe/citar--clean-bibtex-value (citar-get-value "editor" citekey))))
                       (concat ed " (ed.)"))))
         (year-raw (or (citar-get-value "year" citekey)
                       (citar-get-value "date" citekey)))
         (year (when (and year-raw (string-match "[0-9]\\{4\\}" year-raw))
                 (match-string 0 year-raw))))
    (when title
      (apply #'call-process "exiftool" nil nil nil
             (append
              (list "-overwrite_original_in_place"
                    (format "-Title=%s" title)
                    (format "-Author=%s" (or author "")))
              (when year (list (format "-XMP-dc:date=%s" year)))
              (list (expand-file-name file)))))))

(defun joe/citar--read-pdf-metadata (file)
  "Return plist with :title and :author from FILE via exiftool."
  (with-temp-buffer
    (call-process "exiftool" nil t nil "-s" "-Title" "-Author"
                  (expand-file-name file))
    (let ((output (buffer-string)) title author)
      (when (string-match "^Title[[:space:]]*:[[:space:]]*\\(.*\\)$" output)
        (setq title (string-trim (match-string 1 output))))
      (when (string-match "^Author[[:space:]]*:[[:space:]]*\\(.*\\)$" output)
        (setq author (string-trim (match-string 1 output))))
      (list :title title :author author))))

(defun joe/citar--metadata-correct-p (citekey file)
  "Return t if FILE already has metadata matching CITEKEY in bibtex."
  (let* ((bib-title (joe/citar--clean-bibtex-value (citar-get-value "title" citekey)))
         (bib-author (or (joe/citar--clean-bibtex-value (citar-get-value "author" citekey))
                         (when-let* ((ed (joe/citar--clean-bibtex-value
                                          (citar-get-value "editor" citekey))))
                           (concat ed " (ed.)"))))
         (existing (joe/citar--read-pdf-metadata file))
         (existing-title (plist-get existing :title))
         (existing-author (plist-get existing :author)))
    (and bib-title
         (stringp existing-title)
         (not (string-empty-p existing-title))
         (string= existing-title bib-title)
         (string= (or existing-author "") (or bib-author "")))))

(defun joe/citar-bulk-update-pdf-metadata ()
  "Write bibtex metadata to PDFs missing or with incorrect metadata."
  (interactive)
  (let* ((citekeys (hash-table-keys (citar-get-entries)))
         (all-files (citar-get-files citekeys))
         (updated 0)
         (skipped 0))
    (dolist (citekey citekeys)
      (let ((files (delete-dups
                    (append (gethash citekey all-files)
                            (joe/citar--files-by-citekey citekey)))))
        (dolist (file files)
          (when (string-match-p "\\.pdf\\'" (downcase file))
            (if (joe/citar--metadata-correct-p citekey file)
                (cl-incf skipped)
              (joe/citar--write-pdf-metadata citekey file)
              (cl-incf updated))))))
    (message "Updated %d PDFs, skipped %d with correct metadata" updated skipped)))

(defun joe/citar--update-file-metadata-after-add (citekey &rest _)
  "Write metadata to PDFs matching CITEKEY filename after file is added."
  (dolist (file (joe/citar--files-by-citekey citekey))
    (joe/citar--write-pdf-metadata citekey file)))

(advice-add 'citar-add-file-to-library :after #'joe/citar--update-file-metadata-after-add)

;;;; Reading list
(defun joe/reading-list--last-name (author-field)
  "Extract last name of first author from BibTeX AUTHOR-FIELD."
  (let* ((first (car (split-string author-field " and ")))
         (clean (joe/citar--clean-bibtex-value first)))
    (if (string-match "\\`\\([^,]+\\)," clean)
        (string-trim (match-string 1 clean))
      (car (last (split-string (string-trim clean)))))))

(defun joe/insert-reading-list-entry ()
  "Insert a formatted org reading-list heading for a citar entry."
  (interactive)
  (let* ((citekey   (citar-select-ref))
         (author    (or (citar-get-value "author" citekey)
                        (citar-get-value "editor" citekey)))
         (year-raw  (or (citar-get-value "year" citekey)
                        (citar-get-value "date" citekey) ""))
         (year      (if (string-match "[0-9]\\{4\\}" year-raw)
                        (match-string 0 year-raw) ""))
         (title     (joe/citar--clean-bibtex-value
                     (or (citar-get-value "title" citekey) "")))
         (publisher (joe/citar--clean-bibtex-value
                     (or (citar-get-value "publisher" citekey)
                         (citar-get-value "journal" citekey) "")))
         (last-name (if author (joe/reading-list--last-name author) "Unknown")))
    (insert (format "** %s (%s) %s, %s. :: [cite:@%s]\n"
                    last-name year title publisher citekey))))


;;;; bibtex
(use-package bibtex
  :ensure nil
  :config
  (setq bibtex-align-at-equal-sign t)
  (setq bibtex-comma-after-last-field t))
(defun my/import-and-link-by-isbn-from-filename ()
  "Import bibliography entry by ISBN found in filename and link current file.
Works from Dired buffer with ISBN in filename like '9781234567890_Some_Book.pdf'"
  (interactive)
  (require 'zotra)
  (let* ((filename (dired-get-filename))
         (isbn (when (string-match "97[0-9]\\{11\\}" filename)
                 (match-string 0 filename))))
    (if isbn
        (progn
          (message "Importing bibliography entry for ISBN: %s" isbn)
          (zotra-add-entry (concat "isbn:" isbn))
          (sit-for 2)
          (citar-add-file-to-last-added)
          (message "Successfully imported and linked ISBN %s" isbn))
      (message "No ISBN found in filename: %s" filename))))

(defun my/import-and-link-by-doi-from-filename ()
  "Import bibliography entry by DOI found in filename and link current file.
Works from Dired buffer with DOI in filename."
  (interactive)
  (require 'zotra)
  (let* ((filename (dired-get-filename))
         (doi (when (string-match "10\\.[0-9]+/[a-zA-Z0-9./_-]+" filename)
                (match-string 0 filename))))
    (if doi
        (progn
          (message "Importing bibliography entry for DOI: %s" doi)
          (zotra-add-entry (concat "doi:" doi))
          (sit-for 2)
          (citar-add-file-to-last-added)
          (message "Successfully imported and linked DOI %s" doi))
      (message "No DOI found in filename: %s" filename))))

(with-eval-after-load 'dired
  (define-key dired-mode-map (kbd "C-c i") 'my/import-and-link-by-isbn-from-filename)
  (define-key dired-mode-map (kbd "C-c d") 'my/import-and-link-by-doi-from-filename))

;;;; PDF annotation import
(defconst joe/pdfannots-script
  (expand-file-name "~/.local/share/pdfannots/pdfannots.py"))

(defun joe/--demote-headings (text)
  "Demote all org headings in TEXT by one level."
  (with-temp-buffer
    (insert text)
    (goto-char (point-min))
    (while (re-search-forward "^\\(\\*+\\) " nil t)
      (replace-match (concat (match-string 1) "* ")))
    (buffer-string)))

(defun joe/--extract-page-blocks (text)
  "Return list of *** heading blocks from TEXT (one per annotation)."
  (require 'cl-lib)
  (with-temp-buffer
    (insert text)
    (let (positions)
      (goto-char (point-min))
      (while (re-search-forward "^\\*\\*\\* " nil t)
        (push (line-beginning-position) positions))
      (setq positions (nreverse positions))
      (cl-mapcar (lambda (start end)
                   (buffer-substring-no-properties start end))
                 positions
                 (append (cdr positions) (list (point-max)))))))

(defun joe/--quote-fingerprint (block)
  "Return a fingerprint from the #+begin_quote content in BLOCK."
  (with-temp-buffer
    (insert block)
    (goto-char (point-min))
    (if (re-search-forward "#\\+begin_quote" nil t)
        (let ((start (progn (forward-line 1) (point)))
              (end   (progn (re-search-forward "#\\+end_quote" nil t)
                            (line-beginning-position))))
          (let ((q (string-trim (buffer-substring-no-properties start end))))
            (substring (replace-regexp-in-string "[[:space:]]+" " " q)
                       0 (min 60 (length q)))))
      (buffer-substring-no-properties (point-min) (line-end-position)))))

(defun joe/--section-end ()
  "Return position of end of current org heading's subtree."
  (save-excursion
    (forward-line 1)
    (if (re-search-forward "^\\* " nil t)
        (line-beginning-position)
      (point-max))))

(defun joe/--collect-fingerprints-in-section (section-end)
  "Return hash-set of fingerprints for #+begin_quote blocks up to SECTION-END."
  (let ((prints (make-hash-table :test #'equal)))
    (save-excursion
      (while (re-search-forward "#\\+begin_quote" section-end t)
        (let* ((start (progn (forward-line 1) (point)))
               (end   (progn (re-search-forward "#\\+end_quote" section-end t)
                             (line-beginning-position)))
               (q (string-trim (buffer-substring-no-properties start end)))
               (fp (substring (replace-regexp-in-string "[[:space:]]+" " " q)
                              0 (min 60 (length q)))))
          (puthash fp t prints))))
    prints))

(defun joe/--merge-annotations (target-buf raw-output)
  "Merge pdfannots RAW-OUTPUT into `* PDF Annotations' in TARGET-BUF."
  (let* ((demoted (joe/--demote-headings raw-output))
         (page-blocks (joe/--extract-page-blocks demoted))
         (added 0))
    (with-current-buffer target-buf
      (save-excursion
        (goto-char (point-min))
        (if (re-search-forward "^\\* PDF Annotations" nil t)
            (let* ((sec-end (joe/--section-end))
                   (existing (joe/--collect-fingerprints-in-section sec-end)))
              (goto-char sec-end)
              (dolist (block page-blocks)
                (let ((fp (joe/--quote-fingerprint block)))
                  (unless (gethash fp existing)
                    (unless (bolp) (insert "\n"))
                    (insert block)
                    (unless (string-suffix-p "\n" block) (insert "\n"))
                    (puthash fp t existing)
                    (cl-incf added)))))
          (goto-char (point-max))
          (unless (bolp) (insert "\n"))
          (insert "\n* PDF Annotations\n")
          (insert demoted)
          (unless (string-suffix-p "\n" demoted) (insert "\n"))
          (setq added (length page-blocks))))
      (save-buffer))
    (message "Added %d new annotation%s" added (if (= added 1) "" "s"))))

(defun joe/--pdfannots-command (pdf-path)
  "Return the command list to invoke pdfannots on PDF-PATH."
  (if (eq system-type 'windows-nt)
      (list "pdfannots-wsl.cmd" pdf-path)
    (list "pdfannots" "--no-group" pdf-path)))

(defun joe/--run-pdfannots-async (pdf-path target-buf)
  "Run pdfannots on PDF-PATH and merge into TARGET-BUF when done."
  (let ((out-buf (generate-new-buffer " *pdfannots-output*")))
    (make-process
     :name "pdfannots"
     :buffer out-buf
     :command (joe/--pdfannots-command pdf-path)  
     :sentinel (lambda (proc _event)
                 (when (eq (process-status proc) 'exit)
                   (let ((output (with-current-buffer out-buf (buffer-string))))
                     (kill-buffer out-buf)
                     (if (buffer-live-p target-buf)
                         (joe/--merge-annotations target-buf output)
                       (message "pdfannots: target buffer was killed"))))))))

(defun joe/import-pdf-annotations ()
  "Import PDF highlights into the citar-denote note for the current entry."
  (interactive)
  (require 'citar)
  (require 'citar-denote)
  (let* ((buf-file (buffer-file-name))
         (citekey (if (and buf-file (derived-mode-p 'org-mode))
                      (car (citar-denote--retrieve-references buf-file))
                    nil))
         (citekey (or citekey (citar-select-ref)))
         (citar-files (when citekey
                        (gethash citekey (citar-get-files citekey))))
         (pdf (car (seq-filter
                    (lambda (f) (string-match-p "\\.pdf\\'" (downcase f)))
                    (delete-dups
                     (append citar-files
                             (joe/citar--files-by-citekey citekey)))))))
    (unless citekey (user-error "No citekey found"))
    (unless (and pdf (file-exists-p pdf))
      (user-error "No PDF found for %s" citekey))
    (unless (and buf-file
                 (derived-mode-p 'org-mode)
                 (member citekey (citar-denote--retrieve-references buf-file)))
      (let ((existing (gethash citekey (citar-denote--get-notes (list citekey)))))
        (if existing
            (find-file (car existing))
          (citar-denote--create-note citekey))))
    (message "Running pdfannots on %s\u2026" (file-name-nondirectory pdf))
    (joe/--run-pdfannots-async pdf (current-buffer))))

(keymap-global-set "C-c f h" #'joe/import-pdf-annotations)

;;;; Batch book import (Downloads -> bib + library)
;; Unattended importer: resolve each PDF's ISBN (filename first, then the PDF's
;; text layer), fetch a bib entry via zotra, append it, copy the PDF into the
;; library as <citekey>.pdf, write metadata, and -- on a verified copy -- delete
;; the Downloads original.  Anything it cannot resolve is left in place and
;; listed in the *book-import-report* buffer.
(require 'cl-lib)

(defvar joe/batch-import-dry-run nil
  "When non-nil, `joe/batch-import-books' reports what it would do but
makes no changes: no bib writes, no file copies, no deletions.")

(defvar joe/batch-import-pdftotext-candidates
  '("C:/Program Files/Git/mingw64/bin/pdftotext.exe"
    "C:/msys64/mingw64/bin/pdftotext.exe")
  "Preferred absolute paths to try for pdftotext before falling back to PATH.")

(defun joe/--pdftotext-program ()
  "Return a usable pdftotext program path, or nil."
  (or (seq-find #'file-exists-p joe/batch-import-pdftotext-candidates)
      (executable-find "pdftotext")))

(defun joe/--native-path (file)
  "Return a path for FILE safe to hand to a native (non-Emacs) program.
On Windows, `call-process' encodes arguments as UTF-8, but native programs
use the system codepage, so a path with non-ASCII characters fails to open
\(e.g. the curly apostrophe in \"Anna's Archive\").  Fall back to the 8.3
short name, which is pure ASCII, in that case."
  (let ((f (expand-file-name file)))
    (if (and (eq system-type 'windows-nt)
             (fboundp 'w32-short-file-name)
             (string-match-p "[^[:ascii:]]" f))
        (or (ignore-errors (w32-short-file-name f)) f)
      f)))

;;;;; ISBN validation / normalization
(defun joe/--isbn13-valid-p (s)
  "Return non-nil if S is 13 digits with a valid ISBN-13 check digit."
  (and (stringp s)
       (string-match-p "\\`[0-9]\\{13\\}\\'" s)
       (let ((sum 0))
         (dotimes (i 13)
           (let ((d (- (aref s i) ?0)))
             (setq sum (+ sum (if (cl-evenp i) d (* 3 d))))))
         (zerop (mod sum 10)))))

(defun joe/--isbn10-valid-p (s)
  "Return non-nil if S is a valid ISBN-10 (final char may be X)."
  (and (stringp s)
       (string-match-p "\\`[0-9]\\{9\\}[0-9Xx]\\'" s)
       (let ((sum 0))
         (dotimes (i 10)
           (let* ((c (aref s i))
                  (d (if (memq c '(?X ?x)) 10 (- c ?0))))
             (setq sum (+ sum (* d (- 10 i))))))
         (zerop (mod sum 11)))))

(defun joe/--isbn10->isbn13 (s)
  "Convert valid ISBN-10 string S to its ISBN-13 form."
  (let ((core (concat "978" (substring s 0 9)))
        (sum 0))
    (dotimes (i 12)
      (let ((d (- (aref core i) ?0)))
        (setq sum (+ sum (if (cl-evenp i) d (* 3 d))))))
    (concat core (number-to-string (mod (- 10 (mod sum 10)) 10)))))

(defun joe/--isbn-normalize (raw)
  "Normalize RAW to a valid ISBN-13 string, or nil.
Accepts a 13-digit ISBN-13, a 10-char ISBN-10, or a 9-digit SBN
\(possibly with embedded spaces, dots or hyphens)."
  (let ((s (upcase (replace-regexp-in-string "[^0-9Xx]" "" (or raw "")))))
    (cond
     ((and (= (length s) 13) (joe/--isbn13-valid-p s)) s)
     ((and (= (length s) 10) (joe/--isbn10-valid-p s)) (joe/--isbn10->isbn13 s))
     ((and (= (length s) 9) (joe/--isbn10-valid-p (concat "0" s)))
      (joe/--isbn10->isbn13 (concat "0" s)))
     (t nil))))

(defun joe/--isbn-from-filename (file)
  "Return a normalized ISBN-13 found in FILE's name, or nil."
  (let ((name (file-name-nondirectory file)))
    (when (string-match "97[0-9]\\{11\\}" name)
      (joe/--isbn-normalize (match-string 0 name)))))

(defun joe/--isbns-from-text (text)
  "Return a de-duplicated list of normalized ISBN-13 candidates in TEXT."
  (let ((case-fold-search t)
        (results '()))
    (with-temp-buffer
      (insert (or text ""))
      ;; Labeled: ISBN / SBN / ISBN-13 / ISBN-10, then a digit group.
      (goto-char (point-min))
      (while (re-search-forward
              "I?SBN\\(?:[ \t-]*1[03]\\)?[^0-9]\\{0,6\\}\\([0-9][0-9 ._-]\\{7,16\\}[0-9Xx]\\)"
              nil t)
        (let ((norm (joe/--isbn-normalize (match-string 1))))
          (when norm (push norm results))))
      ;; Bare EAN-13 beginning 978/979.
      (goto-char (point-min))
      (while (re-search-forward "\\(97[89][0-9 ._-]\\{10,14\\}[0-9]\\)" nil t)
        (let ((norm (joe/--isbn-normalize (match-string 1))))
          (when norm (push norm results)))))
    (seq-take (delete-dups (nreverse results)) 6)))

(defun joe/--isbns-from-pdf-text (file)
  "Return normalized ISBN-13 candidates from FILE's text layer.
Scans the first 25 pages via pdftotext.  Returns nil if pdftotext is
unavailable or the PDF has no usable text layer."
  (let ((prog (joe/--pdftotext-program)))
    (when prog
      (let ((text (with-temp-buffer
                    (let ((coding-system-for-read 'utf-8))
                      (ignore-errors
                        (call-process prog nil t nil
                                      "-f" "1" "-l" "25"
                                      (joe/--native-path file) "-")))
                    (buffer-string))))
        (joe/--isbns-from-text text)))))

;;;;; Title matching (guards against a valid-but-wrong ISBN)
(defun joe/--title-words (s)
  "Return significant lowercase word tokens from S."
  (seq-remove
   (lambda (w) (or (< (length w) 3)
                   (member w '("the" "and" "for" "with" "from" "into"
                               "a" "an" "of" "in" "on" "to" "by"))))
   (split-string (downcase (or s "")) "[^a-z0-9]+" t)))

(defun joe/--filename-title (file)
  "Return FILE's leading title segment (before the first \" -- \")."
  (let* ((base (file-name-base (file-name-nondirectory file)))
         (seg (car (split-string base " -- " t))))
    (string-trim (or seg base))))

(defun joe/--title-match-strength (filename-title entry-title)
  "Return \\='strong, \\='weak, or nil for how well the titles agree.
Scored symmetrically against the shorter title's word count, so a catalog
entry that omits the filename's subtitle (or vice versa) still matches
strongly when the shorter title is fully covered."
  (let* ((fw (joe/--title-words filename-title))
         (ew (joe/--title-words entry-title))
         (inter (seq-count (lambda (w) (member w ew)) fw))
         (base (min (length fw) (length ew))))
    (cond
     ((or (null fw) (null ew)) 'weak)        ; cannot judge; do not hard-reject
     ((and (>= base 1) (>= inter (max 2 (ceiling (* 0.6 base))))) 'strong)
     ((>= inter 1) 'weak)
     (t nil))))

;;;;; Bibliography helpers
(defun joe/--bib-file ()
  "Return the (first) bibliography file path."
  (car (if (listp citar-bibliography) citar-bibliography
         (list citar-bibliography))))

(defun joe/--bib-has-isbn-p (isbn13)
  "Return non-nil if ISBN13 already appears in the bibliography file."
  (let ((bib (joe/--bib-file)) (found nil))
    (when (and bib (file-readable-p bib))
      (with-temp-buffer
        (insert-file-contents bib)
        (goto-char (point-min))
        (while (and (not found)
                    (re-search-forward
                     "isbn\\s-*=\\s-*[{\"]\\([^}\"]+\\)[\"}]" nil t))
          (dolist (tok (split-string (match-string 1) "[^0-9Xx]+" t))
            (when (equal (joe/--isbn-normalize tok) isbn13)
              (setq found t))))))
    found))

(defun joe/--bib-has-citekey-p (key)
  "Return non-nil if KEY is already an entry key in the bibliography file."
  (let ((bib (joe/--bib-file)))
    (when (and bib (file-readable-p bib))
      (with-temp-buffer
        (insert-file-contents bib)
        (goto-char (point-min))
        (and (re-search-forward
              (concat "@[a-zA-Z]+[ \t]*{[ \t]*" (regexp-quote key) "[ \t]*,")
              nil t)
             t)))))

(defun joe/--parse-bibtex-entry (entry-string)
  "Parse ENTRY-STRING and return its bibtex field alist (with =key=).
Navigates with `bibtex-next-entry' from the top: `bibtex-beginning-of-entry'
does not land on the entry when point starts before it on a blank line."
  (when (and entry-string (stringp entry-string))
    (with-temp-buffer
      (insert entry-string)
      (bibtex-mode)
      (bibtex-set-dialect 'BibTeX t)
      (goto-char (point-min))
      (when (bibtex-next-entry)
        (ignore-errors (bibtex-parse-entry))))))

(defun joe/--bibtex-field (parsed name)
  "Return cleaned value of field NAME from PARSED, or nil."
  (let ((raw (cdr (assoc-string name parsed t))))
    (when (and raw (not (string-empty-p (string-trim raw))))
      (joe/citar--clean-bibtex-value
       (string-trim
        (replace-regexp-in-string "\\`[{\"]\\|[}\"]\\'" "" (string-trim raw)))))))

(defun joe/--ensure-unique-citekey (entry-string key)
  "Return (ENTRY . KEY), renaming KEY in ENTRY-STRING if it collides."
  (if (or (null key) (not (joe/--bib-has-citekey-p key)))
      (cons entry-string key)
    (let ((n 2) newkey)
      (while (progn (setq newkey (format "%s%d" key n))
                    (joe/--bib-has-citekey-p newkey))
        (setq n (1+ n)))
      (cons (replace-regexp-in-string
             (concat "\\(@[a-zA-Z]+[ \t]*{[ \t]*\\)" (regexp-quote key) "\\([ \t]*,\\)")
             (concat "\\1" newkey "\\2") entry-string t)
            newkey))))

(defun joe/--append-entry-to-bib (entry-string)
  "Append ENTRY-STRING to the bib file and return its (unique) citekey."
  (let* ((parsed (joe/--parse-bibtex-entry entry-string))
         (key (cdr (assoc-string "=key=" parsed t)))
         (uniq (joe/--ensure-unique-citekey entry-string key))
         (final-entry (car uniq))
         (final-key (cdr uniq))
         (bib (joe/--bib-file)))
    (with-current-buffer (or (find-buffer-visiting bib)
                             (find-file-noselect bib))
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-max))
          (unless (bolp) (insert "\n"))
          (insert "\n" (string-trim final-entry) "\n")))
      (save-buffer))
    final-key))

(defun joe/--library-dir ()
  "Return the first citar library directory (with trailing slash)."
  (file-name-as-directory
   (expand-file-name
    (car (if (listp citar-library-paths) citar-library-paths
           (list citar-library-paths))))))

(defun joe/--copy-to-library (src citekey)
  "Copy SRC into the library as CITEKEY.pdf without clobbering; return dest."
  (let* ((dir (joe/--library-dir))
         (dest (expand-file-name (concat citekey ".pdf") dir))
         (n 2))
    (while (file-exists-p dest)
      (setq dest (expand-file-name (format "%s-%d.pdf" citekey n) dir)
            n (1+ n)))
    (copy-file src dest)
    dest))

(defun joe/--write-pdf-metadata-from-entry (parsed file)
  "Write title/author/year from PARSED bibtex alist to FILE via exiftool."
  (let* ((title (joe/--bibtex-field parsed "title"))
         (author (or (joe/--bibtex-field parsed "author")
                     (let ((ed (joe/--bibtex-field parsed "editor")))
                       (when ed (concat ed " (ed.)")))))
         (year-raw (or (joe/--bibtex-field parsed "year")
                       (joe/--bibtex-field parsed "date")))
         (year (when (and year-raw (string-match "[0-9]\\{4\\}" year-raw))
                 (match-string 0 year-raw))))
    (when (and title (executable-find "exiftool"))
      (ignore-errors
        (apply #'call-process "exiftool" nil nil nil
               (append
                (list "-overwrite_original_in_place"
                      (format "-Title=%s" title)
                      (format "-Author=%s" (or author "")))
                (when year (list (format "-XMP-dc:date=%s" year)))
                (list (joe/--native-path file))))))))

;;;;; Resolution + commit
(defvar joe/zotra-max-attempts 8
  "How many times to retry a flaky zotra request before giving up.")

(defun joe/--zotra-get-entry-robust (query)
  "Call `zotra-get-entry' for QUERY in bibtex, robustly.
Emacs's `url-retrieve-synchronously' is badly flaky against the keep-alive
zotra server (it errors or returns an empty body about half the time),
whereas curl is reliable.  So prefer curl when available, and in every case
retry until a real \\='@entry\\=' comes back.  Returns the entry string, or nil
if every attempt failed."
  (let ((zotra-use-curl (and (executable-find "curl") t))
        (n joe/zotra-max-attempts)
        (good nil))
    (while (and (> n 0) (not good))
      (setq n (1- n))
      (let ((res (ignore-errors (zotra-get-entry query "bibtex"))))
        (if (and res (string-match-p "@[a-zA-Z]+[ \t]*{" res))
            (setq good res)
          ;; Gentle backoff: the local translation-server is flakier under
          ;; rapid-fire requests, so give it more room on each retry.
          (when (> n 0)
            (sleep-for (min 1.5 (* 0.3 (- joe/zotra-max-attempts n))))))))
    good))

(defun joe/--resolve-from-isbns (isbns ftitle file ocrp)
  "Try each ISBN in ISBNS via zotra; return a result plist or nil.
FTITLE is the filename title used for the sanity check; OCRP marks the
candidates as having come from the PDF text layer."
  (catch 'done
    (dolist (isbn isbns)
      (if (joe/--bib-has-isbn-p isbn)
          (throw 'done (list :status 'duplicate :isbn isbn
                             :file file :title ftitle))
        (let ((entry (joe/--zotra-get-entry-robust isbn)))
          (when (and entry (string-match-p "@[a-zA-Z]+[ \t]*{" entry))
            (let* ((parsed (joe/--parse-bibtex-entry entry))
                   (etitle (joe/--bibtex-field parsed "title"))
                   (strength (and etitle
                                  (joe/--title-match-strength ftitle etitle))))
              (when strength
                (throw 'done
                       (list :status 'ok :isbn isbn :entry entry :parsed parsed
                             :etitle etitle :strength strength :ocr ocrp
                             :file file :title ftitle))))))))
    nil))

(defun joe/--import-one-book (file)
  "Resolve a bib entry for FILE (no side effects).  Return a result plist."
  (let* ((ftitle (joe/--filename-title file))
         (fn-isbns (let ((x (joe/--isbn-from-filename file))) (and x (list x))))
         (result (joe/--resolve-from-isbns fn-isbns ftitle file nil))
         (ocr-isbns nil))
    (unless result
      (setq ocr-isbns (seq-remove (lambda (x) (member x fn-isbns))
                                  (joe/--isbns-from-pdf-text file)))
      (setq result (joe/--resolve-from-isbns ocr-isbns ftitle file t)))
    (or result
        (list :status 'failed
              :reason (if (or fn-isbns ocr-isbns) 'no-matching-entry 'no-isbn-found)
              :file file :title ftitle))))

(defun joe/--commit-import (result)
  "Perform the side effects for an :ok RESULT.  Mutate and return RESULT."
  (let* ((file (plist-get result :file))
         (entry (plist-get result :entry))
         (parsed (plist-get result :parsed))
         (citekey (joe/--append-entry-to-bib entry))
         (dest (joe/--copy-to-library file citekey)))
    (joe/--write-pdf-metadata-from-entry parsed dest)
    (setq result (plist-put result :citekey citekey))
    (setq result (plist-put result :dest dest))
    (if (and (file-exists-p dest)
             (> (or (file-attribute-size (file-attributes dest)) 0) 0))
        (condition-case err
            (progn (delete-file file delete-by-moving-to-trash)
                   (setq result (plist-put result :deleted t)))
          (error (setq result (plist-put result :delete-error
                                         (error-message-string err)))))
      (setq result (plist-put result :verify-failed t)))
    result))

;;;;; Report
(defun joe/--show-import-report (results total)
  "Display a summary buffer for RESULTS (a list of result plists)."
  (let ((buf (get-buffer-create "*book-import-report*"))
        (n-ok 0) (n-verify 0) (n-dup 0) (n-fail 0))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Book import report  —  %s%s\n"
                        (format-time-string "%F %R")
                        (if joe/batch-import-dry-run
                            "   [DRY RUN — no changes made]" "")))
        (insert (make-string 72 ?-) "\n\n")
        (dolist (r results)
          (let ((status (plist-get r :status))
                (fname (file-name-nondirectory (plist-get r :file))))
            (pcase status
              ('ok
               (let ((verify (eq (plist-get r :strength) 'weak)))
                 (if verify (cl-incf n-verify) (cl-incf n-ok))
                 (insert (format "%s %s\n" (if verify "⚠" "✓")
                                 (or (plist-get r :citekey)
                                     (format "(would import) %s" (plist-get r :isbn))))
                         (format "    file : %s\n" fname)
                         (format "    isbn : %s%s\n" (plist-get r :isbn)
                                 (if (plist-get r :ocr) "   (from PDF text)" ""))
                         (format "    title: %s\n" (plist-get r :etitle)))
                 (when verify
                   (insert (format "    NOTE : may not match filename title — verify\n")))
                 (when (plist-get r :dest)
                   (insert (format "    saved: %s%s\n" (plist-get r :dest)
                                   (cond ((plist-get r :deleted) "   (original deleted)")
                                         ((plist-get r :verify-failed)
                                          "   (COPY UNVERIFIED — original kept)")
                                         ((plist-get r :delete-error)
                                          (format "   (original kept: %s)"
                                                  (plist-get r :delete-error)))
                                         (t "   (original kept)")))))))
              ('duplicate
               (cl-incf n-dup)
               (insert (format "= already in library  [%s]\n    file : %s\n"
                               (plist-get r :isbn) fname)))
              ('failed
               (cl-incf n-fail)
               (insert (format "✗ FAILED  (%s)\n    file : %s\n"
                               (plist-get r :reason) fname)))))
          (insert "\n"))
        (insert (make-string 72 ?-) "\n")
        (insert (format "Total %d    ✓ %d    ⚠ verify %d    = dup %d    ✗ failed %d\n"
                        total n-ok n-verify n-dup n-fail))
        (goto-char (point-min))
        (special-mode)))
    (display-buffer buf)
    (message "Book import: %d ok, %d verify, %d dup, %d failed%s"
             n-ok n-verify n-dup n-fail
             (if joe/batch-import-dry-run "  [dry run]" ""))))

;;;;; Entry point
(defun joe/batch-import-books (&optional dir)
  "Batch-import book PDFs into the citar/zotra library.
Operates on the marked files when called from Dired, otherwise on every
*.pdf in DIR (default ~/Downloads).  Honors `joe/batch-import-dry-run'."
  (interactive)
  (require 'zotra)
  (require 'citar)
  (require 'bibtex)
  (let* ((raw (if (derived-mode-p 'dired-mode)
                  (dired-get-marked-files nil nil nil t)
                (directory-files (or dir (expand-file-name "~/Downloads"))
                                 t "\\.pdf\\'")))
         ;; Filter to PDFs.  Use (not (file-directory-p)) rather than
         ;; `file-regular-p': the latter is a `stat' that fails (returns nil)
         ;; for paths at/over Windows' 260-char limit, silently dropping books
         ;; with long names; `directory-files' itself lists them fine.
         (files (seq-filter (lambda (f) (and (stringp f)
                                             (string-match-p "\\.pdf\\'" (downcase f))
                                             (not (file-directory-p f))))
                            raw))
         (total (length files))
         (i 0)
         (results '()))
    (when (zerop total)
      (user-error "No PDF files to import"))
    (dolist (file files)
      (setq i (1+ i))
      (message "[%d/%d] Importing %s…" i total (file-name-nondirectory file))
      (redisplay)
      (let ((res (joe/--import-one-book file)))
        (when (and (not joe/batch-import-dry-run)
                   (eq (plist-get res :status) 'ok))
          (setq res (joe/--commit-import res)))
        (push res results)))
    (joe/--show-import-report (nreverse results) total)))

(keymap-global-set "C-c f b" #'joe/batch-import-books)

(provide 'joe-research)
;;; joe-research.el ends here



















