;;; joe-research.el --- Research tools configuration -*- lexical-binding: t; -*-
;;;; Bibliographic Management
;;;;; citar
(use-package citar
  :ensure t
  :custom
  (citar-bibliography '("~/Texts/My Library.bib"))
  (org-cite-insert-processor 'citar)
  (org-cite-follow-processor 'citar)
  (org-cite-activate-processor 'citar)
  (citar-library-paths '("~/Texts/"))
  :bind
  ("C-c f o" . citar-open-files)
  ("C-c f a" . citar-add-file-to-last-added)
  ("C-c f A" . citar-add-file-to-library))



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
        (citar-add-file-to-library last-citekey)))))

  

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
  :bind (("C-c f z" . zotra-add-entry))
  :config
  (setq zotra-backend 'zotra-server
        zotra-local-server-directory "~/.local/share/zotra-server"
        zotra-default-bibliography "~/Texts/My Library.bib"
        zotra-default-entry-format "bibtex"
        zotra-default-entry-fields '(author title journal year volume number pages doi url abstract)))

(use-package pdf-tools
  :ensure t
  :defer t
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
  (setf (alist-get 'underline pdf-annot-default-annotation-properties)
	'((color . "red")))
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

(defun joe/--run-pdfannots-async (pdf-path target-buf)
  "Run pdfannots on PDF-PATH and merge into TARGET-BUF when done."
  (let ((out-buf (generate-new-buffer " *pdfannots-output*")))
    (make-process
     :name "pdfannots"
     :buffer out-buf
     :command (list "python3" joe/pdfannots-script "--no-group" pdf-path)
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

(provide 'joe-research)
;;; joe-research.el ends here
