;;; go-prettify-mode.el --- Hide `if err != nil' and prettify them -*- lexical-binding: t -*-

;;; Commentary:

;; Author: Gleb Zakharov <snyssfx@posteo.net>
;; Version: 1.0
;; Keywords: languages go tools
;; Package-Requires: ((Emacs "28.1"))
;; URL: https://codeberg.org/snyssfx/go-prettify-mode.el

;;; Copyright © 2026 Gleb Zakharov <snyssfx@posteo.net>

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

;;; Code:


;;
;; Common things
;;

(require 'rx)

(defgroup go-prettify-group nil
  "Hide `if err != nil' and other statements in Go programs."
  :prefix "go-prettify-"
  :group 'convenience)

(defcustom go-prettify-feature-list
  '(lambda-func
    range
    if-err-nil
    1-code-block)
  "What features turn on in the package."
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

(defun go-prettify--make-overlay (beginning end replace-to-str)
  "Create overlay with all properties between BEGINNING and END.
Transforms it to the string REPLACE-TO-STR."
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

(defun go-prettify--get-or-make-overlay (beginning end replace-to-str)
  "If the overlay exists do nothing.
Else makes an overlay from BEGINNING to END,
with a text REPLACE-TO-STR and store it to the overlay dict"
  (let* ((ov
          (cl-find-if
           (lambda (ov) (eq
                         go-prettify--invisible-symbol
                         (overlay-get ov 'invisible)))
           (overlays-at beginning))))
    (or ov
        (go-prettify--make-overlay
         beginning end replace-to-str))))


;;
;; Hide `if err != nil', `if !ok' and inline them.
;;

(defcustom go-prettify--if-err-nil-regexp
  (rx
   (or ";" "if")
   " "
   (or "err != nil" "!ok")
   " {\n"
   (zero-or-more (not (any "\n{}")))
   "\n"
   (one-or-more (any "\t "))
   "}")

  "A variable of what regexp should be hidden in Go code."
  :type 'regexp
  :group 'go-prettify-group)

(defcustom go-prettify--if-err-nil-regexp-alist
  '(("^[ \t\n\r]*" "")
    ("if err != nil " "iferr: ")
    ("err != nil " "err: ")
    ("!ok " "!ok: ")
    ("{\\|}" "")
    ("return" "↵")
    ("fmt\\.Error[f]" "err")
    ("errors\\.Error[f]" "err")
    ("errors\\.New" "err")
    ("errors\\.Wrap" "ω")
    ("logger\\." "λ")
    ("logger()\\." "λ")
    ("log\\." "λ")
    ("can't" "c'")
    ("cannot" "c'")
    ("can not" "c'")
    ("couldn't" "c'")
    ("\"" ""))
  "Alist of pairs of regexps to their replaces for every line inside the block."
  :type '(alist :key-type regexp :value-type string)
  :group 'go-prettify-group)

(defun go-prettify--if-err-nil-transform-line (line)
  "Apply all regexp to replacements from alist to the LINE."
  (let* ((replaced-line (cl-reduce
                         (lambda (line kv)
                           (replace-regexp-in-string (first kv) (second kv) line))
                         go-prettify--if-err-nil-regexp-alist
                         :initial-value line))
         (shorten-line (string-limit replaced-line 27)))
    (concat
     shorten-line
     (when (length> replaced-line 27) "...")
     (unless (or
              (string-match-p "err != nil" line)
              (string-match-p "!ok" line)
              (string-empty-p replaced-line)) "; "))))

(defun go-prettify--if-err-nil-transform-block (beginning end)
  "Yields a line that should be displayed instead of `if err' statement.
The statement is from BEGINNING to END."
  (let* ((lines-raw (buffer-substring-no-properties beginning end))
         (lines (string-lines lines-raw))
         (lines-replaced (mapcar #'go-prettify--if-err-nil-transform-line lines)))
    (string-trim-right
     (string-join lines-replaced)
     "; ")))

(defun go-prettify--if-err-nil-overlayfn ()
  "Create an overlay and store it for the future use."
  (let* ((beginning (progn
                      (search-backward-regexp go-prettify--if-err-nil-regexp)
                      (point)))
         (end (progn
                (end-of-line)
                (backward-char)
                (forward-sexp)
                (point))))
    (setq go-prettify--overlays
          (cons
           (go-prettify--get-or-make-overlay
            beginning end
            (go-prettify--if-err-nil-transform-block beginning end))
           go-prettify--overlays))))

(defun go-prettify--if-err-nil ()
  "Hides if err nil blocks."
  (goto-char (point-min))
  (while (search-forward-regexp go-prettify--if-err-nil-regexp nil t 1)
    (if (string-search "//" (thing-at-point 'line 'no-properties))
        (end-of-line)
      (go-prettify--if-err-nil-overlayfn))))


;;
;; Replace `:= range' to just `in'
;;

(defcustom go-prettify--range-regexp
  ":= range"
  "Regexp for finding and hiding `:= range' code."
  :type 'regexp
  :group 'go-prettify-group)

(defun go-prettify--range-overlayfn ()
  "Find `:= range' and replace it to just `in' like in Python and other languages."
  (let* ((end (point))
         (beginning (progn
                      (search-backward-regexp go-prettify--range-regexp)
                      (point))))
    (end-of-line)
    (setq go-prettify--overlays
          (cons
           (go-prettify--get-or-make-overlay
            beginning end "in")
           go-prettify--overlays))))

(defun go-prettify--range ()
  "Hide := range expression."
  (goto-char (point-min))
  (while (search-forward-regexp go-prettify--range-regexp nil t 1)
    (if (string-search "//" (thing-at-point 'line 'no-properties))
        (end-of-line)
      (go-prettify--range-overlayfn))))


;;
;; Hide all blocks of code with only 1 statement
;;

(defcustom go-prettify--simple-block-regexp
  (rx (* not-newline)
      " {\n"
      (* (not (any "\n{}")))
      "\n"
      (+ (any "\t "))
      "}")

  "Regexp that represents simple blocks of code (i.e. consists of 1 expression)."
  :type 'regexp
  :group 'go-prettify-group)

(defcustom go-prettify-simple-block-regexp-alist
  '((" {" ": ")
    ("}" "")
    ("^[ \t\n\r]*" "")
    ("return" "↵")
    ("fmt\\.Error[f]" "err")
    ("errors\\.Error[f]" "err")
    ("errors\\.New" "err")
    ("errors\\.Wrap" "ω")
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
  :group 'go-prettify-group)

(defun go-prettify--simple-block-transform-line (line)
  "Apply all regexp to replacements from alist to the LINE.
Shorten it if the first line is too long."
  (let* ((replaced-line (cl-reduce
                         (lambda (line kv)
                           (replace-regexp-in-string (first kv) (second kv) line))
                         go-prettify-simple-block-regexp-alist
                         :initial-value line))
         (shorten-line (string-limit replaced-line 70)))
    (concat
     shorten-line
     (when (length> replaced-line 70) "..."))))

(defun go-prettify--simple-block-transform-block (beginning end)
  "Yield a line that should be displayed instead of a simple block.
From BEGINNING to END."
  (let* ((lines-raw (buffer-substring-no-properties beginning end))
         (lines (string-lines lines-raw))
         (lines-replaced (mapcar #'go-prettify--simple-block-transform-line lines)))
    (string-join lines-replaced)))

(defun go-prettify--simple-block-else-before-p ()
  "Check if there is else word before the braces.
The point should be on the open brace {."
  (save-excursion
    (search-forward "else" (line-beginning-position) t -1)))

(defun go-prettify--simple-block-else-after-p ()
  "Check if there is else word after the braces.
The point should be on the closed brace {."
  (save-excursion
    (search-forward "else" (line-end-position) t 1)))

(defun go-prettify--simple-block-overlayfn ()
  "Create an overlay and store it for the future use.
Do not hide it if the first line is too long."
  (let* ((beginning (progn
                      (search-backward-regexp go-prettify--simple-block-regexp)
                      (end-of-line)
                      (backward-char 2) ;; open { and space before it
                      (point)))
         (line-length (- (line-end-position) (line-beginning-position)))

         (else-before-p (go-prettify--simple-block-else-before-p))

         (end (progn (forward-sexp)
                     (point)))
         (else-after-p (go-prettify--simple-block-else-after-p)))

    (when (and (< line-length 50)
               (not else-before-p)
               (not else-after-p))
      (setq go-prettify--overlays
            (cons
             (go-prettify--get-or-make-overlay ;; if err != nil overlay can already exist
              beginning end
              (go-prettify--simple-block-transform-block beginning end))
             go-prettify--overlays)))))

(defun go-prettify--simple-block ()
  "Hide 1-statement blocks."
  (goto-char (point-min))
  (while (search-forward-regexp go-prettify--simple-block-regexp nil t 1)
    (if (string-search "//" (thing-at-point 'line 'no-properties))
        (end-of-line)
      (go-prettify--simple-block-overlayfn))))


;;
;; lambdas
;;

(defcustom go-prettify--lambda-regexp
  (rx (any " \t")
      "func(")
  "A variable of regexp that represents a lambda (anonymous function) in Go code."
  :type 'regexp
  :group 'go-prettify-group)

(defun go-prettify--lambda-transform-args (beginning)
  "Yield a line that hides types in anonymous functions.
The function begins at BEGINNING."
  (let* ((args-beginning (progn
                           (goto-char beginning)
                           (search-forward "(")
                           (point)))
         (args-end (progn
                     (backward-char)
                     (forward-sexp)
                     (point)))
         (args (buffer-substring-no-properties args-beginning args-end))
         (args-regex (rx (group (+ (not (any " \t\n,)"))))
                         " "
                         (group (+ (not (any " \t\n,)"))))
                         (group (any ",)"))))
         (args-refined (replace-regexp-in-string args-regex "\\1\\3" args))
         (args-lines (string-lines args-refined))
         (args-lines-trimmed (cl-map 'list #'string-trim args-lines))
         (args-joined (string-join args-lines-trimmed " ")))
    (concat "fn(" args-joined "" " ")))

(defun go-prettify--lambda-overlayfn ()
  "Create an overlay and store it for the future use."
  (let* ((beginning (progn
                      (search-backward-regexp go-prettify--lambda-regexp)
                      (forward-char)
                      (point)))
         (end (progn (search-forward "{")
                     (backward-char)
                     (point))))
    (setq go-prettify--overlays
          (cons
           (go-prettify--get-or-make-overlay ;; if err != nil overlay can already exist
            beginning end
            (go-prettify--lambda-transform-args beginning))
           go-prettify--overlays))))

(defun go-prettify--lambda ()
  "Hide arguments of anonymous functions."
  (goto-char (point-min))
  (while (search-forward-regexp go-prettify--lambda-regexp nil t 1)
    (if (string-search "//" (thing-at-point 'line 'no-properties))
        (end-of-line)
      (go-prettify--lambda-overlayfn))))


;;
;; Minor mode
;;

(defun go-prettify-turn-on (buffer)
  "Search for every selected feature in the BUFFER and create overlays for them."
  (interactive (list (current-buffer)))
  (add-to-invisibility-spec go-prettify--invisible-symbol)
  (save-excursion
    (with-current-buffer buffer
      (save-restriction
        (widen)

        (when (member 'lambda-func go-prettify-feature-list)
          (go-prettify--lambda))

        (when (member 'if-err-nil go-prettify-feature-list)
          (go-prettify--if-err-nil))

        (when (member '1-code-block go-prettify-feature-list)
          (go-prettify--simple-block))

        (when (member 'range go-prettify-feature-list)
          (go-prettify--range))))))

(defun go-prettify-turn-off ()
  "Remove old overlays from the buffer."
  (interactive)
  (remove-from-invisibility-spec go-prettify--invisible-symbol)
  (mapc #'delete-overlay go-prettify--overlays)
  (setq go-prettify--overlays nil))

;;;###autoload
(define-minor-mode go-prettify-mode
  "Minor mode that adds overlays to `if err != nil' statements and other features.

To turn it on in every Go buffer, add a hook:
    (add-hook \='go-mode-hook \='(lambda () (go-prettify-mode 1)))

To toggle it via a hotkey add this code:
    (define-key go-mode-map (kbd \"C-c C-e\") #\='go-prettify-mode)"
  :group 'go-prettify-group
  (if go-prettify-mode
      (go-prettify-turn-on (current-buffer))
    (go-prettify-turn-off)))

(provide 'go-prettify-mode)

;;; go-prettify-mode.el ends here
