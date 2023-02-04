;;; go-prettify-mode.el --- Hide `if err != nil' and other statements in Go in an informative way. -*- lexical-binding: t -*-

;; Author: Gleb Zakharov <snyssfx@posteo.net>
;; Version: 1.0
;; Keywords: languages go tools
;; URL: https://git.sr.ht/~snyssfx/go-prettify-mode.el

;;; Copyright © 2023 Gleb Zakharov <snyssfx@posteo.net>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:


;;
;; Common things
;;

(defgroup go-prettify-mode nil
  "Hide `if err != nil' and other statements in Go programs."
  :prefix "go-prettify-mode-"
  :group 'convenience)

(defcustom go-prettify-feature-list
  '(lambda-func
    range
    if-err-nil
    1-code-block)
  "What features turn on in the package"
  :type '(list string)
  :group 'go-prettify-mode)

(defface go-prettify-face
  '((t :inherit font-lock-comment-face))
  "Face of an overlay for `if err != nil' statement."
  :group 'go-prettify-mode)

(make-variable-buffer-local
 (defvar go-prettify--overlays '()
   "Private local variable, overlays of the buffer."))

(defconst go-prettify--invisible-symbol
  'go-prettify--invisible-symbol
  "Symbol to add in invisible property of overlays.")

(defun go-prettify--make-overlay (buffer beginning end replace-to-str)
  "Creates overlay with all properties between BEGINNING and END."
  (let ((overlay (make-overlay beginning end)))
    (put-text-property
     0 (length replace-to-str)
     'face 'go-prettify-face
     replace-to-str)
    (overlay-put overlay
                 'invisible
                 go-prettify--invisible-symbol)
    (overlay-put overlay
                 'after-string
                 replace-to-str)
    (overlay-put overlay 'evaporate t)
    ;; (overlay-put overlay 'isearch-open-invisible-temporary t)
    ;; (overlay-put overlay 'isearch-open-invisible t)
    overlay))

(defun go-prettify--get-or-make-overlay (buffer beginning end str-replace-to)
  (let* ((ov
          (cl-find-if
           (lambda (ov) (eq
                         go-prettify--invisible-symbol
                         (overlay-get ov 'invisible)))
           (overlays-at beginning))))
    (or ov
        (go-prettify--make-overlay
         buffer beginning end str-replace-to))))


;;
;; Hide `if err != nil', `if !ok' and inline them.
;;

(defcustom go-if-err-nil--err-regexp
  "\\(;\\|if\\) \\(err != nil\\|!ok\\) {"
  "A variable of what regexp should be hidden in Go code."
  :type 'regexp
  :group 'go-prettify-mode)

(defcustom go-if-err-nil-regexp-alist
  '(("^[ \t\n\r]*" "")
    ("if err != nil " "iferr: ")
    ("err != nil " "err: ")
    ("!ok " "!ok: ")
    ("{\\|}" "")
    ("return" "↵")
    ("fmt\\.Error[f]" "ϕ")
    ("logger\\." "λ")
    ("logger()\\." "λ")
    ("log\\." "λ")
    ("can't" "c'")
    ("cannot" "c'")
    ("can not" "c'")
    ("couldn't" "c'")
    ("\"" ""))
  "Alist of pairs of regexps to their replaces for every line inside if err != nil code blocks."
  :type '(alist :key-type regexp :value-type string)
  :group 'go-prettify-mode)

(defun go-if-err-nil--replace-line-in-overlay (line)
  "Apply all regexp to replacements from alist to the line."
  (let* ((replaced-line (cl-reduce
                         (lambda (line kv)
                           (replace-regexp-in-string (first kv) (second kv) line))
                         go-if-err-nil-regexp-alist
                         :initial-value line))
         (shorten-line (string-limit replaced-line 27)))
    (concat
     shorten-line
     (when (length> replaced-line 27) "...")
     (unless (or
              (string-match-p "err != nil" line)
              (string-match-p "!ok" line)
              (string-empty-p replaced-line)) "; "))))

(defun go-if-err-nil--string-after-overlay (buffer beginning end)
  "Yields a line that should be displayed instead of `if err' statement."
  (let* ((lines-raw (buffer-substring-no-properties beginning end))
         (lines (string-lines lines-raw))
         (lines-replaced (mapcar #'go-if-err-nil--replace-line-in-overlay lines)))
    (string-trim-right
     (string-join lines-replaced)
     "; ")))

(defun go-if-err-nil--make-overlay-at-point (buffer)
  "Creates an overlay and stores it for the future use."
  (let* ((beginning (progn
                      (search-backward-regexp go-if-err-nil--err-regexp)
                      (point)))
         (end (progn
                (end-of-line)
                (backward-char)
                (forward-sexp)
                (point))))
    (setq go-prettify--overlays
          (cons
           (go-prettify--get-or-make-overlay
            buffer
            beginning end
            (go-if-err-nil--string-after-overlay
             buffer beginning end))
           go-prettify--overlays))))


;;
;; Replace `:= range' to just `in'
;;

(defcustom go-range--regexp
  ":= range"
  "Regexp for finding and hiding `:= range' code."
  :type 'regexp
  :group 'go-prettify-mode)

(defun go-range--make-overlay-at-point (buffer)
  "Find `:= range' and replace it to just `in' like in Python and other languages."
  (let* ((end (point))
         (beginning (progn
                      (search-backward-regexp go-range--regexp)
                      (point))))
    (end-of-line)
    (setq go-prettify--overlays
          (cons
           (go-prettify--get-or-make-overlay
            buffer beginning end "in")
           go-prettify--overlays))))


;;
;; Hide all blocks of code with only 1 statement
;;

(defcustom go-simple-block--regexp
  "[^\n]* {\n[^\n{}]*\n[\t ]+}"
  "A variable of what regexp represents simple blocks of code (i.e. consists of 1 expression)."
  :type 'regexp
  :group 'go-prettify-mode)

(defcustom go-simple-block-regexp-alist
  '((" {" ": ")
    ("}" "")
    ("^[ \t\n\r]*" "")
    ("return" "↵")
    ("fmt\\.Error[f]" "ϕ")
    ("logger\\." "λ")
    ("logger()\\." "λ")
    ("log\\." "λ")
    ("can't" "c'")
    ("cannot" "c'")
    ("can not" "c'")
    ("couldn't" "c'")
    ("\"" ""))
  "Alist of pairs of regexps to their replaces for the line in a code block."
  :type '(alist :key-type regexp :value-type string)
  :group 'go-prettify-mode)

(defun go-simple-block--replace-line-in-overlay (line)
  "Apply all regexp to replacements from alist to the line.
   Shorten it if the first line is too long."
  (let* ((replaced-line (cl-reduce
                         (lambda (line kv)
                           (replace-regexp-in-string (first kv) (second kv) line))
                         go-simple-block-regexp-alist
                         :initial-value line))
         (shorten-line (string-limit replaced-line 70)))
    (concat
     shorten-line
     (when (length> replaced-line 70) "..."))))

(defun go-simple-block--string-after-overlay (buffer beginning end)
  "Yields a line that should be displayed instead of a simple block."
  (let* ((lines-raw (buffer-substring-no-properties beginning end))
         (lines (string-lines lines-raw))
         (lines-replaced (mapcar #'go-simple-block--replace-line-in-overlay lines)))
    (string-join lines-replaced)))

(defun go-simple-block--make-overlay-at-point (buffer)
  "Creates an overlay and stores it for the future use.
   Do not hide it if the first line is too long."
  (let* ((beginning (progn
                      (search-backward-regexp go-simple-block--regexp)
                      (end-of-line)
                      (backward-char 2) ;; open { and space before it
                      (point)))
         (line-start (line-beginning-position))
         (line-end (line-end-position))
         (line-length (- line-end line-start))
         (end (progn (forward-sexp)
                     (point))))
    (when (< line-length 50)
      (setq go-prettify--overlays
            (cons
             (go-prettify--get-or-make-overlay ;; if err != nil overlay can already exist
              buffer beginning end
              (go-simple-block--string-after-overlay
               buffer beginning end))
             go-prettify--overlays)))))


;;
;; lambdas
;;


(defcustom go-lambda--regexp
  "[^\n]*[^t]func("
  "A variable of regexp that represents a lambda (anonymous function) in Go code."
  :type 'regexp
  :group 'go-prettify-mode)

(defun go-lambda--string-after-overlay (buffer beginning end)
  "Yields a line that hides types in anonymous functions."
  (let* ((args-beginning (progn
                           (goto-char beginning)
                           (search-forward "(")
                           (point)))
         (args-end (progn
                     (backward-char)
                     (forward-sexp)
                     (point)))
         (args (buffer-substring-no-properties args-beginning args-end))
         (args-refined (replace-regexp-in-string "\\([^ \t\n,\)]+\\) \\([^ \t\n,\)]+\\)\\([,\)]\\)" "\\1\\3" args))
         (args-lines (string-lines args-refined))
         (args-lines-trimmed (cl-map 'list #'string-trim args-lines))
         (args-joined (string-join args-lines-trimmed " "))

         (returns (progn
                    (forward-char)
                    (message (buffer-substring-no-properties (point) (+ 1 (point))))
                    (if (string= "{" (buffer-substring-no-properties (point) (+ 1 (point))))
                        ""
                      "(...) ")))
         )
    (concat "func(" args-joined "" " " returns)))

(defun go-lambda--make-overlay-at-point (buffer)
  "Creates an overlay and stores it for the future use."
  (let* ((beginning (progn
                      (search-backward-regexp go-lambda--regexp)
                      (forward-char)
                      (point)))
         (end (progn (search-forward "{")
                     (backward-char)
                     (point))))
    (setq go-prettify--overlays
          (cons
           (go-prettify--get-or-make-overlay ;; if err != nil overlay can already exist
            buffer beginning end
            (go-lambda--string-after-overlay
             buffer beginning end))
           go-prettify--overlays))))


;;
;; Minor mode
;;

(defun go-prettify-regexp+overlayfn (feature)
  "Returns a regexp and a func that should be called if this regexp is found (by feature)."
  (pcase feature
    ('if-err-nil (list
                  go-if-err-nil--err-regexp
                  #'go-if-err-nil--make-overlay-at-point))
    ('1-code-block (list
                    go-simple-block--regexp
                    #'go-simple-block--make-overlay-at-point))
    ('range (list
             go-range--regexp
             #'go-range--make-overlay-at-point))
    ('lambda-func (list
                   go-lambda--regexp
                   #'go-lambda--make-overlay-at-point))
    (_ (error "cannot find this feature %s" feature))))

(defun go-prettify-hide-feature (buffer regexp overlayfn)
  "Find every match of the regexp and hide it with overlayfn."
  (goto-char (point-min))
  (while (search-forward-regexp regexp nil t 1)
    (if (string-search "//" (thing-at-point 'line 'no-properties))
        (end-of-line)
      (funcall overlayfn buffer))))

(defun go-prettify-turn-on (buffer)
  "Searches for every selected feature in the buffer and creates overlays for them."
  (interactive (list (current-buffer)))
  (add-to-invisibility-spec go-prettify--invisible-symbol)
  (save-excursion
    (with-current-buffer buffer
      (save-restriction
        (widen)
        (cl-map
         'list
         (lambda (feature)
           (let* ((regexp+overlayfn (go-prettify-regexp+overlayfn feature))
                  (regexp (cl-first regexp+overlayfn))
                  (overlayfn (cl-second regexp+overlayfn)))
             (go-prettify-hide-feature buffer overlayfn regexp)))
         go-prettify-feature-list)))))

(defun go-prettify-turn-off (buffer)
  "Removes old overlays from the buffer."
  (interactive (list (current-buffer)))
  (remove-from-invisibility-spec go-prettify--invisible-symbol)
  (mapcar #'delete-overlay go-prettify--overlays)
  (setq go-prettify--overlays nil))

;;;###autoload
(define-minor-mode go-prettify-mode
  "Minor mode that adds overlays to `if err != nil' statements and other features.

To turn it on in every Go buffer, add a hook:
    (add-hook 'go-mode-hook '(lambda () (go-prettify-mode 1)))

To toggle it via a hotkey add this code:
    (define-key go-mode-map (kbd \"C-c C-e\") #'go-prettify-mode)
   "
  :group 'go-prettify-mode
  (if go-prettify-mode
      (go-prettify-turn-on (current-buffer))
    (go-prettify-turn-off (current-buffer))))

(provide 'go-prettify)

;;; go-prettify-mode.el ends here
