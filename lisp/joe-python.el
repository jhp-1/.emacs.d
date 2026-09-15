;;; joe-python.el --- Python / org-babel literate analysis -*- lexical-binding: t; -*-

;;; Commentary:
;; Minimal Python support for org-babel literate analysis (the gilt work).
;; Uses built-in ob-python with :session blocks — no MELPA packages.
;; Upgrade to emacs-jupyter for inline plots when the chart milestone lands.

;;; Code:

(with-eval-after-load 'org
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((python . t))))
  (setq org-babel-python-command "python3"
        ;; sole user; don't confirm on every block evaluation
        org-confirm-babel-evaluate nil))

(provide 'joe-python)
;;; joe-python.el ends here
