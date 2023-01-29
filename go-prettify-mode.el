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
  '(if-err-nil
    ;; 1-code-block
    range
    ;; lambda-func
    )
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
                 go-if-err-nil--invisible-symbol)
    (overlay-put overlay
                 'after-string
                 replace-to-str)
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
         (shorter-line (string-limit replaced-line 27)))
    (concat
     shorter-line
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

(defcustom go-range--err-regexp
  ":= range"
  ""
  :type 'regexp
  :group 'go-prettify-mode)

(defun go-range--make-overlay-at-point (buffer)
  ""
  (let* ((end (point))
         (beginning (progn
                      (search-backward-regexp go-range--err-regexp)
                      (point))))
    (end-of-line)
    (setq go-prettify--overlays
          (cons
           (go-prettify--get-or-make-overlay
            buffer beginning end "in")
           go-prettify--overlays))))


;;
;; Minor mode
;;

(defun go-prettify-regexp+overlayfn (feature)
  (pcase feature
    ('if-err-nil (list
                  go-if-err-nil--err-regexp
                  #'go-if-err-nil--make-overlay-at-point))
    ('1-code-block (list
                    nil
                    nil))
    ('range (list
             go-range--err-regexp
             #'go-range--make-overlay-at-point))
    ('lambda-func (list
                   nil
                   nil))
    (_ (error "cannot find this feature %s" feature))))

(defun go-prettify-hide-feature (regexp overlayfn buffer)
  (goto-char (point-min))
  (while (search-forward-regexp regexp nil t 1)
    (if (string-search "//" (thing-at-point 'line 'no-properties))
        (end-of-line)
      (funcall overlayfn buffer))))

(defun go-prettify-turn-on (buffer)
  "Searches for every `err != nil' in the buffer and creates overlays for them."
  (interactive (list (current-buffer)))
  (add-to-invisibility-spec go-if-err-nil--invisible-symbol)
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
             (go-prettify-hide-feature regexp overlayfn buffer)))
         go-prettify-feature-list)))))

(defun go-prettify-turn-off (buffer)
  "Removes old overlays from the buffer."
  (interactive (list (current-buffer)))
  (remove-from-invisibility-spec go-prettify--invisible-symbol)
  (mapcar #'delete-overlay go-prettify--overlays)
  (setq go-prettify--overlays nil))

;;;###autoload
(define-minor-mode go-prettify-mode
  "Minor mode that adds overlays to `if err != nil' statements.

To turn it on in every Go buffer, add a hook:
    (add-hook 'go-mode-hook '(lambda () (go-if-err-nil-mode 1)))

To toggle it via a hotkey add this code:
    (define-key go-mode-map (kbd \"C-c C-e\") #'go-if-err-nil-mode)
   "
  :group 'go-prettify-mode
  (if go-prettify-mode
      (go-prettify-turn-on (current-buffer))
    (go-prettify-turn-off (current-buffer))))

(provide 'go-prettify)

;;; go-prettify-mode.el ends here
