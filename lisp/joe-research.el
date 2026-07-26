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
  ;; K10plus ISBN lookups routinely take 40-70s; the 15s default guaranteed
  ;; "Request failed" timeouts. ponytail: fixed high ceiling, not adaptive.
  (zotra-url-retrieve-timeout 120)
  (zotra-use-curl nil))

;;;; Controlled keyword vocabulary
;; A small, hand-owned, lower-case vocabulary, after Karl Voit's tagging rules
;; (few; self-defined; non-overlapping; general; lower-case; one language;
;; explained) tempered by library science (literary warrant: tags earn their
;; place from what is actually in the collection).  Single source of truth for
;; the bibliography `keywords' field.  Two facets — subject and era — plus the
;; one figure whose warrant is overwhelming.  Drop `philosophy' itself: it is
;; the whole library, so it tags nothing.  Subject tags are mass nouns, hence
;; singular (Voit's "plural" rule targets count nouns, which these are not).
;;
;; Tag dictionary (Voit rule 10 — explain your tags):
;;   metaphysics   being, ontology, time, modality, causation, persistence
;;   epistemology  knowledge, justification, skepticism
;;   logic         formal & philosophical logic, set theory, foundations
;;   ethics        moral philosophy, value, the good life
;;   aesthetics    philosophy of art & beauty; art/music theory
;;   mind          philosophy of mind, consciousness, cognition
;;   language      philosophy of language, linguistics, semiotics
;;   science       philosophy & history of science
;;   mathematics   philosophy of mathematics + mathematics proper
;;   computing     CS, programming, algorithms, cybernetics, information,
;;                 computing history, philosophy of information/technology
;;   media         media theory, film/cinema, communication
;;   politics      political philosophy & theory, sovereignty, the state
;;   economics     political economy, money, finance, world-systems
;;   religion      theology, philosophy of religion, scripture
;;   esotericism   alchemy, magic, hermeticism, rosicrucianism, astrology,
;;                 kabbalah, occult
;;   history       historiography & history proper (NOT history-of-philosophy);
;;                 also absorbs intelligence/deep-politics/conspiracy material
;;   literature    literary works, criticism, poetry
;;   anthropology  ethnology, myth, ritual, kinship
;;   sociology     social theory, society, institutions
;;   psychology    empirical/historical psychology, psychoanalysis
;;   -- era: the historical period a work's SUBJECT belongs to or concerns.
;;      Tag only when a period is genuinely the object; omit for perennial
;;      philosophy, technical works, and studies of 20th-c.+ figures.  A study
;;      of a pre-1900 figure takes that figure's era.  Non-overlapping: --
;;   ancient       antiquity, to ~500
;;   medieval      ~500–1400
;;   renaissance   ~1400–1600
;;   early-modern  ~1600–1800 (scientific revolution, Enlightenment)
;;   modern        the long 19th century, ~1800–1900
;;   contemporary  a present-day phenomenon/condition is the subject (mass
;;                 media, current politics) — NOT mere recent authorship
;;   -- figure (only where the focus dominates the collection) --
;;   kant          Kant & Kantianism (scholarship on, not merely by)
(defconst joe/bib-keywords
  '(;; subject
    "metaphysics" "epistemology" "logic" "ethics" "aesthetics" "mind"
    "language" "science" "mathematics" "computing" "media" "politics"
    "economics" "religion" "esotericism" "history" "literature"
    "anthropology" "sociology" "psychology"
    ;; era
    "ancient" "medieval" "renaissance" "early-modern" "modern" "contemporary"
    ;; figure
    "kant")
  "Controlled vocabulary for the bibliography `keywords' field.
See the tag dictionary in the comment above this definition.")

(defun joe/bib-strip-keywords ()
  "Delete the keywords field from the bibtex entry at point.
On `zotra-after-get-bibtex-entry-hook' so imported entries never carry
source-supplied keywords into the controlled vocabulary."
  (save-excursion
    (bibtex-beginning-of-entry)
    (let ((end (save-excursion (bibtex-end-of-entry) (point))))
      (when (re-search-forward "^[ \t]*keywords[ \t]*=[ \t]*" end t)
        (let ((start (match-beginning 0)))
          (if (looking-at "[{\"]") (forward-sexp) (end-of-line))
          (when (looking-at "[ \t]*,") (goto-char (match-end 0)))
          (when (looking-at "[ \t]*\n") (goto-char (match-end 0)))
          (delete-region start (point)))))))

(with-eval-after-load 'zotra
  ;; append so it runs after `bibtex-clean-entry' has normalised the entry
  (add-hook 'zotra-after-get-bibtex-entry-hook #'joe/bib-strip-keywords t))

(defvar joe/--exiftool-warned nil
  "Non-nil once the missing-exiftool warning has been issued this session.")

(defun joe/--exiftool ()
  "Return the exiftool program, or nil after warning once.
Every PDF-metadata write is a no-op without exiftool.  This used to fail
silently -- when the WSL setup went away so did exiftool, and months of
`joe/bib-set-keywords' calls wrote the bib but quietly never touched a
single PDF.  Warn loudly instead, exactly once per session."
  (or (executable-find "exiftool")
      (progn
        (unless joe/--exiftool-warned
          (setq joe/--exiftool-warned t)
          (display-warning
           'joe/research
           "exiftool not found -- PDF metadata will NOT be written.
Install it and put exiftool.exe on `exec-path' (~/bin is already on PATH)."
           :warning))
        nil)))

(defun joe/--write-pdf-keywords (file keywords)
  "Write KEYWORDS (a list of strings) to FILE's metadata via exiftool.
Replaces any existing Keywords/Subject; an empty list clears them.
`-sep' makes exiftool store them as a proper multi-valued list.
Return non-nil on success, nil on failure, so callers can report rather
than assume."
  (let ((prog (joe/--exiftool)))
    (when prog
      (let ((val (string-join keywords ", ")))
        (eq 0 (ignore-errors
                (call-process prog nil nil nil
                              "-overwrite_original_in_place"
                              "-sep" ", "
                              (concat "-Keywords=" val)
                              (concat "-Subject=" val)
                              (joe/--native-path file))))))))

(defun joe/--bib-set-keywords-field (value)
  "Set the keywords field of the bibtex entry at point to VALUE (a string).
Replaces an existing keywords field or inserts one; self-contained since
bibtex.el has no `bibtex-set-field'."
  (save-excursion
    (bibtex-beginning-of-entry)
    (let ((end (save-excursion (bibtex-end-of-entry) (point))))
      (if (re-search-forward "^[ \t]*keywords[ \t]*=[ \t]*" end t)
          (let ((vstart (point)))
            (if (looking-at "[{\"]") (forward-sexp) (end-of-line))
            (delete-region vstart (point))
            (goto-char vstart)
            (insert "{" value "}"))
        (bibtex-beginning-of-entry)
        (end-of-line)
        (insert "\n  keywords = {" value "},")))))

(defun joe/bib-set-keywords ()
  "Set the keywords of the bibtex entry at point from `joe/bib-keywords'.
Also mirror them into the linked PDF's metadata.  Pre-fills with the
entry's current in-vocabulary keywords."
  (interactive)
  (bibtex-beginning-of-entry)
  (let* ((citekey (ignore-errors (bibtex-key-in-head)))
         (current (ignore-errors (bibtex-text-in-field "keywords")))
         (initial (when current
                    (seq-filter (lambda (k) (member k joe/bib-keywords))
                                (mapcar #'string-trim (split-string current ",")))))
         (chosen (completing-read-multiple
                  "Keywords: " joe/bib-keywords nil t
                  (when initial (concat (string-join initial ",") ",")))))
    (joe/--bib-set-keywords-field (string-join chosen ", "))
    (when citekey
      ;; match citar's own resolution: `file' field links + <citekey>.pdf
      (dolist (pdf (seq-filter
                    (lambda (f) (string-match-p "\\.pdf\\'" (downcase f)))
                    (delete-dups
                     (append (ignore-errors (gethash citekey (citar-get-files citekey)))
                             (joe/citar--files-by-citekey citekey)))))
        (joe/--write-pdf-keywords pdf chosen)))))

(defun joe/--bib-untagged-entries ()
  "Return a list of (CITEKEY . TITLE) for entries with no/empty keywords.
Reads the bib file directly rather than going through citar, so it works
from anywhere and needs no loaded cache."
  (let ((bib (joe/--bib-file)) (out '()))
    (when (and bib (file-readable-p bib))
      (with-temp-buffer
        (insert-file-contents bib)
        (goto-char (point-min))
        (let ((starts '()))
          (while (re-search-forward "^@[a-zA-Z]+[ \t]*{[ \t]*\\([^,\n]+\\)," nil t)
            (push (cons (string-trim (match-string 1)) (match-beginning 0)) starts))
          (setq starts (nreverse starts))
          (let ((n (length starts)))
            (dotimes (i n)
              (let* ((key (car (nth i starts)))
                     (beg (cdr (nth i starts)))
                     (end (if (< (1+ i) n) (cdr (nth (1+ i) starts)) (point-max)))
                     (body (buffer-substring beg end))
                     (kw (when (string-match
                                "^[ \t]*keywords[ \t]*=[ \t]*[{\"]\\([^}\"]*\\)[\"}]" body)
                           (string-trim (match-string 1 body))))
                     (title (when (string-match
                                   "^[ \t]*title[ \t]*=[ \t]*{\\([^}]*\\)}" body)
                              (string-trim (match-string 1 body)))))
                (when (or (null kw) (string-empty-p kw))
                  (push (cons key (or title "")) out))))))))
    (nreverse out)))

(defun joe/bib-audit-keywords ()
  "Audit the bib file's keywords against `joe/bib-keywords'.
Reports both off-vocabulary keywords AND entries carrying no keywords at
all.  The latter matters: an untagged entry has no keywords field to be
matched, so it is invisible to a purely vocabulary-based check -- which
is how a whole batch import once sat untagged and unnoticed."
  (interactive)
  (let ((bib (joe/--bib-file))
        (bad (make-hash-table :test #'equal))
        (untagged (joe/--bib-untagged-entries)))
    (with-temp-buffer
      (insert-file-contents bib)
      (goto-char (point-min))
      (while (re-search-forward
              "^[ \t]*keywords[ \t]*=[ \t]*[{\"]\\([^}\"]*\\)[\"}]" nil t)
        (dolist (kw (mapcar #'string-trim (split-string (match-string 1) ",")))
          (unless (or (string-empty-p kw) (member kw joe/bib-keywords))
            (puthash kw (1+ (gethash kw bad 0)) bad)))))
    (if (and (zerop (hash-table-count bad)) (null untagged))
        (message "Clean: all keywords in vocabulary, and every entry is tagged.")
      (let ((rows nil)
            (buf (get-buffer-create "*bib-keyword-audit*")))
        (maphash (lambda (k v) (push (cons k v) rows)) bad)
        (setq rows (sort rows (lambda (a b) (> (cdr a) (cdr b)))))
        (with-current-buffer buf
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (format "%d off-vocabulary keyword(s):\n\n" (length rows)))
            (if rows
                (dolist (r rows) (insert (format "%5d  %s\n" (cdr r) (car r))))
              (insert "  (none)\n"))
            (insert (format "\n%d entr%s with NO keywords:\n\n"
                            (length untagged) (if (= 1 (length untagged)) "y" "ies")))
            (if untagged
                (dolist (u untagged)
                  (insert (format "  %-44s %s\n"
                                  (truncate-string-to-width (car u) 44)
                                  (truncate-string-to-width (cdr u) 60))))
              (insert "  (none)\n"))
            (when untagged
              (insert "\nRun `joe/bib-tag-untagged-entries' (C-c f T) to tag these.\n"))
            (goto-char (point-min))
            (special-mode)))
        (display-buffer buf)
        (message "Audit: %d off-vocabulary keyword(s), %d untagged entr%s"
                 (length rows) (length untagged)
                 (if (= 1 (length untagged)) "y" "ies"))))))

(keymap-global-set "C-c f t" #'joe/bib-set-keywords)
(keymap-global-set "C-c f k" #'joe/bib-audit-keywords)

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
  (setq pdf-view-resize-factor 1.025)
  (setq-default pdf-view-display-size 'fit-height)
  ;; pdf-annot is loaded lazily inside pdf-tools; guard so the setf
  ;; doesn't fire before pdf-annot.el has been required.
  (with-eval-after-load 'pdf-annot
    (setf (alist-get 'underline pdf-annot-default-annotation-properties)
	  '((color . "red"))))
  :hook
  ;; Sync colors to this frame's theme *before* enabling midnight mode, so the
  ;; daemon's colorless initial frame never feeds it `unspecified-fg'.
  (pdf-view-mode . (lambda ()
                     (joe--sync-pdf-midnight-colors)
                     (pdf-view-midnight-minor-mode))))

(use-package saveplace-pdf-view
  :ensure t
  :after (:any doc-view pdf-tools)
  :demand t
  :init
  (save-place-mode 1))

;;;; buffer-to-pdf
(use-package buffer-to-pdf
  :ensure t
  :init
  ;; Then upgrade it with the command `package-vc-upgrade' or `package-vc-upgrade-all'.
  (unless (package-installed-p 'buffer-to-pdf)
    (package-vc-install "https://github.com/protesilaos/buffer-to-pdf.git"))
  :config
  ;; Configure `buffer-to-pdf-directory' to specify where PDF files are stored.
  ;; This is the default value:
  (setq buffer-to-pdf-directory (expand-file-name "~/Downloads/")))
;;;; Pdf metadata
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
                    ;; drop any source-supplied keyword junk on import
                    "-Keywords=" "-Subject="
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
  "Return the command list to invoke pdfannots on PDF-PATH.
pdfannots runs as a native Python package on all platforms now."
  (list "pdfannots" "--no-group" pdf-path))

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
;; library as <citekey>.pdf, write metadata, auto-tag it from the controlled
;; keyword vocabulary via an LLM, and -- on a verified copy -- delete the
;; Downloads original.  Anything it cannot resolve is left in place and
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
      ;; Leading newline is load-bearing: `bibtex-next-entry' searches
      ;; FORWARD, so an entry beginning at point-min is skipped and the
      ;; parse silently returns nil.  Zotra's output happens to carry
      ;; leading whitespace, but a hand-written entry does not.
      (insert "\n" entry-string)
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

(defun joe/--rename-citekey-in-entry (entry-string old new)
  "Return ENTRY-STRING with citekey OLD replaced by NEW in its header."
  (replace-regexp-in-string
   (concat "\\(@[a-zA-Z]+[ \t]*{[ \t]*\\)" (regexp-quote old) "\\([ \t]*,\\)")
   (concat "\\1" new "\\2") entry-string t))

(defconst joe/--citekey-unsafe-rx "[<>:\"/\\|?*]"
  "Characters that are illegal in a Windows filename.
The citekey becomes the PDF's filename, so any of these makes the copy
fail.  A colon is the common one -- zotra derives keys from the
shorttitle, so \"Crashed: how a decade...\" yields `tooze_crashed:_2019'
-- and on NTFS \"name:stream\" means an alternate data stream, so the
copy either errors or silently writes into a hidden stream.")

(defun joe/--sanitize-citekey (entry-string key)
  "Return (ENTRY . KEY) with filename-hostile characters stripped from KEY.
Applied on import so a new entry's key is always usable as
<citekey>.pdf.  Existing keys are left alone -- rewriting them would
break citar-denote note references."
  (if (or (null key) (not (string-match-p joe/--citekey-unsafe-rx key)))
      (cons entry-string key)
    (let ((clean (replace-regexp-in-string joe/--citekey-unsafe-rx "" key)))
      (cons (joe/--rename-citekey-in-entry entry-string key clean) clean))))

(defun joe/--ensure-unique-citekey (entry-string key)
  "Return (ENTRY . KEY), renaming KEY in ENTRY-STRING if it collides."
  (if (or (null key) (not (joe/--bib-has-citekey-p key)))
      (cons entry-string key)
    (let ((n 2) newkey)
      (while (progn (setq newkey (format "%s%d" key n))
                    (joe/--bib-has-citekey-p newkey))
        (setq n (1+ n)))
      (cons (joe/--rename-citekey-in-entry entry-string key newkey) newkey))))

(defun joe/--append-entry-to-bib (entry-string)
  "Append ENTRY-STRING to the bib file and return its (unique) citekey."
  (let* ((parsed (joe/--parse-bibtex-entry entry-string))
         (key (cdr (assoc-string "=key=" parsed t)))
         ;; Sanitize BEFORE the collision check, so uniqueness is tested
         ;; against the key that will actually be written.
         (safe (joe/--sanitize-citekey entry-string key))
         (uniq (joe/--ensure-unique-citekey (car safe) (cdr safe)))
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
                      ;; drop any source-supplied keyword junk on import
                      "-Keywords=" "-Subject="
                      (format "-Title=%s" title)
                      (format "-Author=%s" (or author "")))
                (when year (list (format "-XMP-dc:date=%s" year)))
                (list (joe/--native-path file))))))))

;;;;; LLM auto-tagging (OpenRouter)
;; Tagging is otherwise "on-touch" (`joe/bib-set-keywords', by hand), which
;; has no natural trigger for a batch of unattended imports -- those would
;; otherwise sit untagged indefinitely, invisibly (`joe/bib-audit-keywords'
;; only catches off-vocabulary keywords, not a missing keywords field).  Ask
;; a small/free OpenRouter model to pick from `joe/bib-keywords' instead.
;; The reply is whitelist-filtered against that same vocabulary, so a
;; chatty or careless model can wrap its answer in explanation but cannot
;; inject an off-vocabulary tag; any failure (no key, no curl, network
;; hiccup, unparseable reply) just yields no tags rather than interrupting
;; the import.  Source-supplied keywords are still stripped unconditionally
;; on fetch (`joe/bib-strip-keywords') -- this only ever adds fresh,
;; in-vocabulary tags afterward.
(require 'auth-source)

(defvar joe/batch-import-auto-tag t
  "When non-nil, `joe/batch-import-books' asks an LLM to choose keywords
for each newly-committed entry from `joe/bib-keywords'.  Set to nil to
skip tagging (e.g. no OpenRouter key, or rate-limited) without losing
the setting.")

(defvar joe/openrouter-model "google/gemma-4-26b-a4b-it:free"
  "OpenRouter model slug used to auto-tag imported books.
The task is closed-vocabulary word-picking, not reasoning, so a small,
fast, plain instruction-tuned free-tier model is plenty -- avoid the
`-reasoning' variants, which tend to pad replies with chain-of-thought
before the actual answer.  Free slugs rotate; see
https://openrouter.ai/models?max_price=0 for current options.")

(defun joe/--openrouter-api-key ()
  "Return the OpenRouter API key from $OPENROUTER_API_KEY or auth-source.
The key lives OUTSIDE this repo, which is public.  Add a line like
    machine openrouter.ai password sk-or-v1-...
to ~/.authinfo (searched first by default in Emacs 30) or ~/.authinfo.gpg
if you want it encrypted at rest.  Never inline a key in this file."
  (or (getenv "OPENROUTER_API_KEY")
      (auth-source-pick-first-password :host "openrouter.ai")))

(defvar joe/openrouter-min-interval 3.2
  "Minimum seconds between OpenRouter requests.
OpenRouter caps free-model use at 20 requests/minute regardless of
credit; 3.2s spacing keeps a batch just under that.  Tripping it returns
HTTP 429, which is easily misread as the daily quota being exhausted.")

(defvar joe/openrouter-max-retries 3
  "How many times to retry a 429 before giving up on a request.")

(defvar joe/--openrouter-last-call nil
  "`float-time' of the last OpenRouter request, for pacing.")

(defun joe/--openrouter-pace ()
  "Sleep as needed to respect `joe/openrouter-min-interval'."
  (when joe/--openrouter-last-call
    (let ((wait (- joe/openrouter-min-interval
                   (- (float-time) joe/--openrouter-last-call))))
      (when (> wait 0) (sleep-for wait))))
  (setq joe/--openrouter-last-call (float-time)))

(defun joe/--openrouter-chat (system user)
  "POST a one-shot SYSTEM/USER chat completion to OpenRouter.
Return a cons (STATUS . VALUE) where STATUS is one of:
  ok         VALUE is the reply's content string
  no-key     no API key, or curl unavailable
  ratelimit  429 survived `joe/openrouter-max-retries' backed-off retries
  error      VALUE is a short diagnostic string
Callers get to distinguish \"model declined to tag this\" from \"the
request never happened\" -- collapsing those two into nil is what makes
a failed batch look like a successfully untagged one."
  (let ((key (joe/--openrouter-api-key)))
    (if (not (and key (executable-find "curl")))
        (cons 'no-key nil)
      (let ((attempt 0) (result nil))
        (while (and (null result) (<= attempt joe/openrouter-max-retries))
          (joe/--openrouter-pace)
          (let* ((payload (json-serialize
                           `((model . ,joe/openrouter-model)
                             (temperature . 0)
                             (max_tokens . 60)
                             (messages
                              . ,(vector `((role . "system") (content . ,system))
                                         `((role . "user") (content . ,user)))))))
                 (out (ignore-errors
                        (with-temp-buffer
                          (insert payload)
                          (let ((coding-system-for-read 'utf-8)
                                (coding-system-for-write 'utf-8))
                            (call-process-region
                             (point-min) (point-max) "curl" t t nil
                             "-s" "--max-time" "30" "-w" "\n__HTTP__%{http_code}"
                             "https://openrouter.ai/api/v1/chat/completions"
                             "-H" (concat "Authorization: Bearer " key)
                             "-H" "Content-Type: application/json"
                             "--data-binary" "@-"))
                          (buffer-string))))
                 (code (and out (if (string-match "__HTTP__\\([0-9]+\\)" out)
                                    (match-string 1 out) "?")))
                 (body (and out (replace-regexp-in-string
                                 "\n__HTTP__[0-9]+\\'" "" out))))
            (cond
             ((null out) (setq result (cons 'error "curl failed")))
             ((equal code "429")
              ;; Back off and retry: usually the 20/min cap, not the daily quota.
              (setq attempt (1+ attempt))
              (when (<= attempt joe/openrouter-max-retries)
                (sleep-for (* 5.0 attempt)))
              (when (> attempt joe/openrouter-max-retries)
                (setq result (cons 'ratelimit nil))))
             ((not (equal code "200"))
              (setq result (cons 'error (format "HTTP %s" code))))
             (t
              (let* ((json (ignore-errors
                             (json-parse-string body :object-type 'alist
                                                :array-type 'list)))
                     (content (alist-get 'content
                                         (alist-get 'message
                                                    (car (alist-get 'choices json))))))
                (setq result (if content (cons 'ok content)
                               (cons 'error "unparseable response"))))))))
        (or result (cons 'ratelimit nil))))))

(defvar joe/bib-keyword-guidance
  "Rules:
- Choose ONLY from the vocabulary below.  Reply with a comma-separated
  list, lower-case, nothing else -- no explanation, no reasoning.
- Be sparing.  Most books need 1-3 tags; never give more than 4.  Tag
  what the book is ABOUT, not every subject it touches on.  A tag that
  would fit most of a philosophy library (e.g. `epistemology' on any
  work that discusses knowing) discriminates nothing -- leave it off
  unless it is a principal subject of the book.
- Era tags mark the period the book's SUBJECT belongs to or concerns --
  NEVER when the book was written.  MOST BOOKS GET NO ERA TAG AT ALL:
  omit era for perennial philosophy and for technical works.  A study
  of a pre-1900 figure takes that figure's era.  The eras, which use
  these specific ranges and not their everyday senses, are:
      ancient       antiquity, to ~500
      medieval      ~500-1400
      renaissance   ~1400-1600
      early-modern  ~1600-1800
      modern        the long 19th century, ~1800-1900 ONLY
      contemporary  a present-day phenomenon is the subject (mass
                    media, current politics) -- never mere recent
                    authorship
  A 20th- or 21st-century work of philosophy is NOT `modern' and NOT
  `contemporary'; it almost always takes no era tag.
- Reply with nothing at all if no tag genuinely fits."
  "Usage rules sent to the LLM alongside `joe/bib-keywords'.
Mirrors the tag dictionary above that definition -- in particular the era
convention, which a model will otherwise read as the publication date,
and the injunction against over-tagging.  Kept separate from
`joe/bib-keywords' so the vocabulary stays a plain list for
`completing-read-multiple' and `joe/bib-audit-keywords'.")

(defun joe/--llm-pick-keywords (title author year &optional extra)
  "Ask an LLM to choose from `joe/bib-keywords' for this work.
TITLE, AUTHOR and YEAR describe the book; optional EXTRA is an alist of
further ((\"Publisher\" . VAL) ...) context -- a publisher or an abstract
sharpens the guess considerably over a bare title.

Return a cons (STATUS . TAGS) with STATUS from `joe/--openrouter-chat'.
On \\='ok, TAGS is the reply filtered to the controlled vocabulary, so a
chatty model cannot inject an off-vocabulary tag; it may legitimately be
empty when nothing fits.  Never signals."
  (let* ((system (format "You are tagging a book for a personal philosophy \
library, using a fixed controlled vocabulary.\n\n%s\n\nVocabulary: %s"
                         joe/bib-keyword-guidance
                         (string-join joe/bib-keywords ", ")))
         (user (concat
                (format "Title: %s\nAuthor: %s\nYear: %s"
                        (or title "unknown") (or author "unknown") (or year "unknown"))
                (mapconcat (lambda (kv)
                             (format "\n%s: %s" (car kv)
                                     (truncate-string-to-width (cdr kv) 700)))
                           (seq-filter #'cdr (or extra '())) "")))
         (res (joe/--openrouter-chat system user)))
    (if (eq (car res) 'ok)
        (cons 'ok (seq-filter (lambda (w) (member w joe/bib-keywords))
                              (split-string (downcase (cdr res)) "[,;\n .]+" t)))
      res)))

(defun joe/--bib-set-keywords-for-key (key value)
  "Set the keywords field of bib entry KEY to VALUE (a string).
Like `joe/--bib-set-keywords-field' but locates KEY itself, for callers
not already positioned inside the entry."
  (let ((bib (joe/--bib-file)))
    (when (and bib (file-readable-p bib))
      (with-current-buffer (or (find-buffer-visiting bib) (find-file-noselect bib))
        (save-excursion
          (goto-char (point-min))
          (when (re-search-forward
                 (concat "@[a-zA-Z]+[ \t]*{[ \t]*" (regexp-quote key) "[ \t]*,") nil t)
            (joe/--bib-set-keywords-field value)))
        (save-buffer)))))

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
    (when joe/batch-import-auto-tag
      (let* ((res (joe/--llm-pick-keywords
                   (joe/--bibtex-field parsed "title")
                   (joe/--bibtex-field parsed "author")
                   (joe/--bibtex-field parsed "year")
                   (list (cons "Publisher" (joe/--bibtex-field parsed "publisher")))))
             (status (car res))
             (keywords (cdr res)))
        (if (not (eq status 'ok))
            ;; Record WHY there are no tags, so the report can say so rather
            ;; than leaving a silently untagged book behind.
            (setq result (plist-put result :tag-error status))
          (when keywords
            (joe/--bib-set-keywords-for-key citekey (string-join keywords ", "))
            (unless (joe/--write-pdf-keywords dest keywords)
              (setq result (plist-put result :pdf-keywords-failed t)))
            (setq result (plist-put result :keywords keywords))))))
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
                 (when (plist-get r :keywords)
                   (insert (format "    tags : %s%s\n"
                                   (string-join (plist-get r :keywords) ", ")
                                   (if (plist-get r :pdf-keywords-failed)
                                       "   (bib only — PDF write failed)" ""))))
                 (when (plist-get r :tag-error)
                   (insert (format "    tags : NOT TAGGED (%s) — rerun C-c f T\n"
                                   (plist-get r :tag-error))))
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
          ;; Isolate each book: an unattended run over a whole Downloads
          ;; folder must not lose the remaining books because one of them
          ;; errored (a bad citekey, a locked file, a full disk).  Record
          ;; the failure and carry on.
          (setq res (condition-case err
                        (joe/--commit-import res)
                      (error
                       (setq res (plist-put res :status 'failed))
                       (plist-put res :reason
                                  (format "commit error: %s"
                                          (error-message-string err)))))))
        (push res results)))
    (joe/--show-import-report (nreverse results) total)))

(keymap-global-set "C-c f b" #'joe/batch-import-books)

;;;; Tag sweep (backfill entries the importer left untagged)
;; Tagging is otherwise on-touch, which has no trigger for entries that
;; arrive in bulk -- and `joe/bib-audit-keywords' historically could not see
;; them, since an entry with no keywords field has nothing to match against.
;; This sweep closes that loop: it is idempotent (skips anything already
;; tagged), so it is safe to re-run, and it resumes naturally after a
;; rate-limit stop because the entries it completed are no longer untagged.

(defun joe/--bib-entry-fields (citekey fields)
  "Return an alist of FIELDS -> value for CITEKEY, reading the bib directly."
  (let ((bib (joe/--bib-file)) (out '()))
    (when (and bib (file-readable-p bib))
      (with-temp-buffer
        (insert-file-contents bib)
        (goto-char (point-min))
        (when (re-search-forward
               (concat "^@[a-zA-Z]+[ \t]*{[ \t]*" (regexp-quote citekey) "[ \t]*,") nil t)
          (let* ((beg (match-beginning 0))
                 (end (or (save-excursion
                            (when (re-search-forward "^@[a-zA-Z]+[ \t]*{" nil t)
                              (match-beginning 0)))
                          (point-max)))
                 (body (buffer-substring beg end)))
            (dolist (f fields)
              (when (string-match (concat "^[ \t]*" f "[ \t]*=[ \t]*{\\([^}]*\\)}") body)
                (push (cons (capitalize f)
                            (joe/citar--clean-bibtex-value
                             (string-trim (match-string 1 body))))
                      out)))))))
    (nreverse out)))

(defun joe/--dedup-paths (paths)
  "Remove duplicate PATHS, case-insensitively on Windows.
`joe/citar--files-by-citekey' probes both \".pdf\" and \".PDF\", and on a
case-insensitive filesystem BOTH report as existing for the same physical
file -- so a naive `delete-dups' leaves two names for one file and every
write happens twice."
  (let ((seen (make-hash-table :test #'equal)) (out '()))
    (dolist (p paths)
      (let ((canon (if (memq system-type '(windows-nt ms-dos))
                       (downcase (expand-file-name p))
                     (expand-file-name p))))
        (unless (gethash canon seen)
          (puthash canon t seen)
          (push p out))))
    (nreverse out)))

(defun joe/--pdfs-for-citekey (citekey)
  "Return existing PDFs for CITEKEY: <citekey>.pdf plus `file' field entries.
The `file' field may hold a bare basename (the portable form citar
resolves against `citar-library-paths'), so try that against the library
directory as well as verbatim."
  (let* ((dir (joe/--library-dir))
         (fields (joe/--bib-entry-fields citekey '("file")))
         (raw (cdr (assoc "File" fields)))
         (cands (append (joe/citar--files-by-citekey citekey)
                        (when raw
                          (mapcan (lambda (p)
                                    (let ((p (string-trim p)))
                                      (list p (expand-file-name
                                               (file-name-nondirectory p) dir))))
                                  (split-string raw ";" t))))))
    (joe/--dedup-paths
     (seq-filter (lambda (f) (and (string-match-p "\\.pdf\\'" (downcase f))
                                  (file-exists-p f)))
                 cands))))

(defun joe/bib-tag-untagged-entries (&optional limit)
  "Tag every bib entry that currently has no keywords, via the LLM.
Writes the controlled-vocabulary tags to the bib entry and mirrors them
into any PDF found for it.  With a prefix argument, prompt for a LIMIT on
how many entries to process in this run.

Idempotent and resumable: entries tagged in an earlier run are no longer
untagged, so re-running simply continues.  Stops cleanly if OpenRouter
rate-limits, reporting what remains rather than silently leaving entries
untagged.  Honors `joe/batch-import-dry-run'."
  (interactive (list (when current-prefix-arg
                       (read-number "Max entries this run: " 50))))
  (require 'citar)
  (let* ((all (joe/--bib-untagged-entries))
         (todo (if limit (seq-take all limit) all))
         (n (length todo))
         (done 0) (skipped 0) (failed 0) (pdfs 0)
         (stopped nil) (rows '()))
    (when (zerop n)
      (user-error "No untagged entries -- nothing to do"))
    (catch 'stop
      (dolist (e todo)
        (let* ((key (car e))
               (fields (joe/--bib-entry-fields
                        key '("title" "author" "year" "publisher" "abstract")))
               (res (joe/--llm-pick-keywords
                     (cdr (assoc "Title" fields))
                     (cdr (assoc "Author" fields))
                     (cdr (assoc "Year" fields))
                     (list (cons "Publisher" (cdr (assoc "Publisher" fields)))
                           (cons "Abstract/contents" (cdr (assoc "Abstract" fields))))))
               (status (car res))
               (tags (cdr res)))
          (message "[%d/%d] %s -> %s" (1+ (+ done skipped failed)) n key
                   (pcase status
                     ('ok (if tags (string-join tags ", ") "(none)"))
                     (_ (format "! %s" status))))
          (redisplay)
          (pcase status
            ('ratelimit (setq stopped 'ratelimit) (throw 'stop nil))
            ('no-key (setq stopped 'no-key) (throw 'stop nil))
            ('error (cl-incf failed))
            ('ok
             (if (null tags)
                 (cl-incf skipped)
               (unless joe/batch-import-dry-run
                 (joe/--bib-set-keywords-for-key key (string-join tags ", "))
                 (dolist (pdf (joe/--pdfs-for-citekey key))
                   (when (joe/--write-pdf-keywords pdf tags) (cl-incf pdfs))))
               (cl-incf done)
               (push (cons key tags) rows)))))))
    (let ((buf (get-buffer-create "*bib-tag-sweep*")))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (format "Tag sweep — %s%s\n" (format-time-string "%F %R")
                          (if joe/batch-import-dry-run
                              "   [DRY RUN — no changes made]" "")))
          (insert (make-string 72 ?-) "\n\n")
          (dolist (r (nreverse rows))
            (insert (format "  %-44s %s\n"
                            (truncate-string-to-width (car r) 44)
                            (string-join (cdr r) ", "))))
          (insert "\n" (make-string 72 ?-) "\n")
          (insert (format "tagged %d   no-tag %d   errors %d   PDFs written %d\n"
                          done skipped failed pdfs))
          (insert (format "untagged remaining: %d\n"
                          (length (joe/--bib-untagged-entries))))
          (when stopped
            (insert (format "\nSTOPPED: %s — re-run C-c f T to continue.\n" stopped)))
          (goto-char (point-min))
          (special-mode)))
      (display-buffer buf))
    (message "Tag sweep: %d tagged, %d no-tag, %d errors, %d PDFs%s"
             done skipped failed pdfs
             (if stopped (format "  [STOPPED: %s]" stopped) ""))))

(keymap-global-set "C-c f T" #'joe/bib-tag-untagged-entries)

(provide 'joe-research)
;;; joe-research.el ends here



















