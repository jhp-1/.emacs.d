;;; joe-org-notes.el --- Org mode and note-taking configuration -*- lexical-binding: t; -*-

;;;; jinx
(use-package jinx
  :ensure nil
  ;; jinx links libenchant, not aspell directly, and the backend surfaces
  ;; under different names per host: enchant-2 on Nix, aspell elsewhere.
  ;; Accept either, so spell-check activates without a per-host gate.
  :if (or (executable-find "enchant-2") (executable-find "aspell"))
  :hook (org-mode . jinx-mode)
  :bind
  (:map org-mode-map
        ("M-$" . jinx-correct))
  :config
  (setq jinx-languages "en_GB"))  ; enchant here provides en_GB, not the en_US default

;; Removed three `add-to-list' calls on `jinx-exclude-regexps' that pushed bare
;; strings — '("@@.*?@@"), '("~.*?~"), '("=.*?=") — to skip org macros, verbatim
;; and code. That variable is an alist keyed by MODE, `((MODE REGEXP...) ...)',
;; so a string sat where a mode symbol belongs and jinx died with
;; "Wrong type argument: symbolp, \"=.*?=\"" the moment it checked an org
;; buffer, taking spell-checking out entirely.
;; They are not worth repairing in place: `jinx-exclude-regexps' anchors at the
;; START of a word, so by its own docstring it "cannot be used to exclude larger
;; parts of a buffer" — it could never have skipped a =code= span. The
;; region-based mechanism is `jinx-exclude-faces', whose default Salready lists
;; org-code, org-verbatim, org-macro, org-block, org-link et al. for org-mode.
;; So plain deletion both fixes the crash and gets the intended behaviour.

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
  (setq org-directory joe/notes-dir)
  ;; Use joe/notes-dir so that no host hardcodes a location.
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
;; Merged in from the former joe-career.el: two denote keywords, one org-ql
;; view and a keybinding are settings for a single org file, not a subsystem.
;; (joe-counting-house.el stays separate - that one is a real subsystem with
;; its own transient menu and harvest machinery.)
(defconst joe/career-applications-file
  (expand-file-name "career/20260624T102500--job-applications__career.org" joe/notes-dir)
  "Denote note holding the job applications.
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

;; The job-application capture template was removed in Aug 2026. What remains
;; is read-only: `joe/applications-open' still lists what the file already
;; holds. Delete this whole section, and the two denote keywords above, if the
;; file itself is finished with.

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
  ;; joe/notes-dir resolves per host; see joe-core.el.
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
  (setq denote-rename-buffer-format "%>60t")
  (setq denote-buffer-name-prefix "<Denote> ")
  ;; Both settings above are inert without this: they only configure a mode
  ;; that was never switched on, so buffers kept their raw file names
  ;; (20260828T164500--reading-the-deductions__kant_material_reading.org) and
  ;; nothing ever consulted the format. `denote-rename-buffer-mode' is what
  ;; installs the hook that rewrites the buffer name after a file is visited or
  ;; renamed. It is off by default in Denote, so it must be enabled explicitly.
  ;; This matters most on Android, where the buffer name is all that fits in a
  ;; narrow mode line and a 60-character title beats a timestamped filename.
  (denote-rename-buffer-mode 1)
  :bind
  ( :map global-map
    ("C-c n n" . denote-open-or-create)
    ("C-c n s" . denote-subdirectory)
    ("C-c n o" . denote-sort-dired)
    ("C-c n r" . denote-rename-file)))

(add-hook 'dired-mode-hook #'denote-dired-mode-in-directories)

;;;;; denote-org
;; Denote's Org dynamic blocks live in their own package as of Denote 4 --
;; plain `denote' gives you links and backlinks written as static text, but
;; not the blocks that re-derive their contents on update. Without this
;; package `C-c C-x C-u' on a `#+begin: denote-links' block fails outright,
;; because `org-dblock-write:denote-links' is simply not defined.
;;
;; No explicit `require' is needed for updating: the `org-dblock-write:denote-*'
;; writers are autoloaded, so refreshing a block in a file you have just opened
;; pulls the package in on its own. The bindings below are only for authoring
;; new blocks.
;;
;; Not bound: `denote-org-dblock-insert-sequence', which is defined inside a
;; `with-eval-after-load' on the separate `denote-sequence' package and so does
;; not exist here. It indexes notes by signature, and `denote-prompts' above
;; asks only for title and keywords, so nothing in this setup carries one.
(use-package denote-org
  :ensure t
  :after (denote org)
  :bind
  ( :map org-mode-map
    ("C-c n d l" . denote-org-dblock-insert-links)
    ("C-c n d b" . denote-org-dblock-insert-backlinks)
    ("C-c n d f" . denote-org-dblock-insert-files)
    ("C-c n d h" . denote-org-dblock-insert-files-as-headings)
    ("C-c n d m" . denote-org-dblock-insert-missing-links)))

;;;;; org-transclusion
;; The dblocks above are the wrong tool for reading one heading out of another
;; note. They select whole *files* by filename regexp -- there is no heading or
;; search-option parameter anywhere in denote-org -- and what they write is a
;; copy, so an edit made inside a block is discarded the next time you press
;; `C-c C-x C-u'. org-transclusion fills that gap: a `#+transclude:' keyword
;; followed by a link displays the target's live contents in the buffer, while
;; the file on disk keeps nothing but the one-line keyword.
;;
;;   #+transclude: [[denote:20260714T173000::#h4f2a][Hub::Method]]
;;   #+transclude: [[denote:20260714T173000::*Method]] :only-contents :level 2
;;
;; `:only-contents' drops the heading line itself; `:level N' re-levels the
;; transcluded subtree to fit where it lands.
;;
;; Two things that surprise people, neither of them a misconfiguration here:
;; transcluded text is read-only until `C-c n t e' starts a live-sync edit, and
;; a `#+transclude:' keyword exports as nothing, so a buffer must have its
;; transclusions added (`C-c n t A', or just turn the minor mode on) before
;; exporting or the content is silently absent from the output.
;;
;; Version note: `package-archives' carries gnu, melpa and nongnu but
;; deliberately not GNU-devel, so `:ensure' installs GNU ELPA's stable 1.4.0
;; (2024-05-20) rather than the 2.0.0-rc snapshot that the development archive
;; ships. The glue below is written against the parts both releases share, so
;; that is a preference rather than a constraint.

;; org-transclusion has no built-in `denote:' support and is not getting any:
;; nobiot/org-transclusion#160 ("Support denote: links") was closed without it,
;; leaving `org-transclusion-add-functions' -- a documented extension point --
;; as the sanctioned route. This is the denote arm of that hook, after the
;; snippet in that issue. It moved here from joe-counting-house.el, where it
;; had been sitting inert: it is generic denote glue, not Counting House
;; machinery.
;;
;; Two deliberate choices:
;;
;; - It rewrites the denote link into a `file:' link rather than resolving the
;;   target itself. Heading transclusion is unreliable through `id:' links
;;   (nobiot/org-transclusion#237), whereas file links carrying a search option
;;   are the best-tested path; and `org-transclusion-wrap-path-to-link' builds
;;   the link object the same way org-transclusion builds its own, so what
;;   `org-transclusion-add-org-file' is handed here is indistinguishable from
;;   its ordinary input.
;;
;; - Everything it touches came through the 1.4 -> 2.0 refactor unchanged: the
;;   hook contract (LINK PLIST -> payload plist), `org-transclusion-add-org-file'
;;   and `org-transclusion-wrap-path-to-link'. What 2.0 did break was
;;   `org-transclusion-add-payload' and the signature of
;;   `org-transclusion-content-insert', neither of which appears here.
(defun joe/denote-transclusion-add (link plist)
  "Resolve a `denote:' LINK for org-transclusion, honouring PLIST.
Return nil for any other link type, so the remaining functions in
`org-transclusion-add-functions' still get their turn."
  (when (string= "denote" (org-element-property :type link))
    (require 'denote)
    ;; Org splits a `::' search option off `file:' links only, so for a denote
    ;; link the identifier and the search term arrive together in :path.
    (let* ((parts (split-string (org-element-property :path link) "::"))
           (identifier (car parts))
           (search (cadr parts))
           (path (denote-get-path-by-id identifier)))
      (if path
          (org-transclusion-add-org-file
           (org-transclusion-wrap-path-to-link
            (format "[[file:%s%s]]" path (if search (concat "::" search) "")))
           plist)
        ;; Say which identifier failed. Falling through to the other hook
        ;; functions with nil is correct -- none of them claims denote links --
        ;; but on its own it would only produce org-transclusion's generic
        ;; "No transclusion added" and leave you guessing at the cause.
        (message "Denote transclusion: no file with identifier %s" identifier)
        nil))))

(defun joe/denote-transclude-heading (&optional current-file)
  "Insert a `#+transclude:' line targeting a heading in a Denote Org file.
Prompt for the note, then for the heading. With optional CURRENT-FILE as a
prefix argument, pick a heading in the current file instead.

The link is written as [[denote:IDENTIFIER::#CUSTOM-ID]]:
`denote-org-link-to-heading' writes a CUSTOM_ID property into the target
heading when it has none, so the reference survives that heading being
retitled, and the denote identifier means it survives the file being renamed
too. That property is the one edit this command makes outside the current
buffer, and it is what makes the transclusion durable."
  (interactive "P" org-mode)
  (unless (derived-mode-p 'org-mode)
    (user-error "`#+transclude:' keywords only work in Org buffers"))
  (require 'denote-org)
  ;; Wrapped so that quitting either prompt leaves no half-written keyword
  ;; behind; a CUSTOM_ID already written into the target note is harmless and
  ;; gets reused next time.
  (atomic-change-group
    (unless (bolp) (insert "\n"))
    (insert "#+transclude: ")
    (denote-org-link-to-heading current-file)))

(defun joe/denote-transclude-file ()
  "Insert a `#+transclude:' line targeting a whole Denote note.
The heading-level counterpart is `joe/denote-transclude-heading'; for many
notes at once, the denote-files dblocks above are the better tool."
  (interactive nil org-mode)
  (unless (derived-mode-p 'org-mode)
    (user-error "`#+transclude:' keywords only work in Org buffers"))
  (require 'denote)
  (when-let* ((file (denote-file-prompt ".*\\.org" "Transclude note"))
              (identifier (denote-retrieve-filename-identifier file)))
    (unless (bolp) (insert "\n"))
    (insert (format "#+transclude: [[denote:%s][%s]]\n"
                    identifier (denote-get-link-description file)))))

;; `:after org' rather than `:defer', matching the denote-org block above: the
;; bindings live in `org-mode-map', so the form has to wait for that map to
;; exist. use-package autoloads every command it binds, so the package itself
;; still loads on first use, and `:config' then registers the denote arm before
;; any transclusion is attempted.
;;
;; Only the entry points are bound. Inside a transclusion, org-transclusion's
;; own `org-transclusion-map' already offers e/g/d/o/P/D on single keys.
(use-package org-transclusion
  :ensure t
  :after org
  :bind
  ( :map org-mode-map
    ("C-c n t t" . org-transclusion-mode)
    ("C-c n t a" . org-transclusion-add)
    ("C-c n t A" . org-transclusion-add-all)
    ("C-c n t r" . org-transclusion-remove)
    ("C-c n t R" . org-transclusion-remove-all)
    ("C-c n t g" . org-transclusion-refresh)
    ("C-c n t e" . org-transclusion-live-sync-start)
    ("C-c n t o" . org-transclusion-open-source)
    ("C-c n t m" . org-transclusion-make-from-link)
    ("C-c n t h" . joe/denote-transclude-heading)
    ("C-c n t f" . joe/denote-transclude-file))
  :config
  (add-to-list 'org-transclusion-add-functions #'joe/denote-transclusion-add))

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
