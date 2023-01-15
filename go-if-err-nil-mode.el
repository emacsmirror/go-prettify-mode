;;; go-if-err-nil.el --- Hide `if err != nil' statements in Go in an informative way. -*- lexical-binding: t -*-

;; Author: Gleb Zakharov <snyssfx@gmail.com>
;; Version: 1.0
;; Keywords: languages go tools
;; URL: https://git.sr.ht/~snyssfx/go-if-err-nil.el

;;; Copyright © 2023 Gleb Zakharov <snyssfx@gmail.com>

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

(defgroup go-if-err-nil nil
  "Hide `if err != nil' statements in Go programs."
  :prefix "go-if-err-nil-"
  :group 'convenience)

(defcustom go-if-err-nil-regexp-alist
  '(("^[ \t\n\r]*" "")
    ("if err != nil " "iferr: ")
    ("err != nil" "err: ")
    ("{\\|}" "")
    ("return" "↵")
    ("fmt\\.Error[f]" "ϕ")
    ("logger\\." "λ")
    ("logger()\\." "λ")
    ("log\\." "λ")
    ("can't " "c'")
    ("cannot " "c'")
    ("can not " "c'")
    ("couldn't " "c'")
    ("\"" ""))
  "Alist of pairs of regexps to their replaces for every line inside if err != nil code blocks."
  :type '(alist :key-type regexp :value-type string)
  :group 'go-if-err-nil)

(defface go-if-err-nil-face
  '((t :inherit font-lock-comment-face))
  "Face of an overlay for `if err != nil' statement."
  :group 'go-if-err-nil)

(defvar go-if-err-nil--overlays '()
  "Private variable, alist of buffers to their overlays.")

(defun go-if-err-nil--append-to-value-in-alist! (alist key elem)
  (let ((kv (assoc key alist))
        (new-alist (assoc-delete-all key alist)))
    (if (eq kv nil)
        (cons (list key elem) new-alist)
      (cons (append kv (list elem)) new-alist))))

(defun go-if-err-nil--replace-line-in-overlay (line)
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
              (string-empty-p replaced-line)) "; "))))

(defun go-if-err-nil--string-after-overlay (buffer beginning end)
  (let* ((lines-raw (buffer-substring-no-properties beginning end))
         (lines (string-lines lines-raw))
         (lines-replaced (mapcar #'go-if-err-nil--replace-line-in-overlay lines)))
    (string-trim-right
     (string-join lines-replaced)
     "; ")))

(defun go-if-err-nil--make-overlay (buffer beginning end)
  (let ((overlay (make-overlay beginning end))
        (str (go-if-err-nil--string-after-overlay
              buffer beginning end)))
    (put-text-property
     0 (length str)
     'face go-if-err-nil-face
     str)
    (overlay-put overlay
                 'invisible
                 'go-if-err-nil--invisible-symbol)
    (overlay-put overlay
                 'after-string
                 str)
    overlay))

(defun go-if-err-nil--make-overlay-at-point (buffer)
  ;; TODO: if this overlay already exists at point, do nothing.
  ;; TODO: in turn off, remove all overlays with the property for the buffer
  ;; TODO: add comments everywhere
  (let* ((beginning (progn
                      (search-backward-regexp ";\\|if") ; search to the beginning of the match
                      (point)))
         (end (progn
                (end-of-line)
                (backward-char)
                (forward-sexp)
                (point))))
    (setq go-if-err-nil--overlays
          (go-if-err-nil--append-to-value-in-alist!
           go-if-err-nil--overlays
           buffer
           (go-if-err-nil--make-overlay buffer beginning end)))))

(defun go-if-err-nil-turn-on (buffer)
  (interactive (list (current-buffer)))
  (add-to-invisibility-spec 'go-if-err-nil--invisible-symbol)
  (save-excursion
    (with-current-buffer buffer
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (search-forward-regexp "if.*err != nil {" nil t 1)
          (go-if-err-nil--make-overlay-at-point buffer))))))

(defun go-if-err-nil-turn-off (buffer)
  (interactive (list (current-buffer)))
  (remove-from-invisibility-spec 'go-if-err-nil--invisible-symbol)
  (mapcar
   #'delete-overlay
   (cdr (assoc buffer go-if-err-nil--overlays)))
  (setq go-if-err-nil--overlays
        (assoc-delete-all buffer go-if-err-nil--overlays)))

;;;###autoload
(define-minor-mode go-if-err-nil-mode
  "Minor mode that adds overlays to `if err != nil' statements."
  :global t
  (if go-if-err-nil-mode
      (go-if-err-nil-turn-on (current-buffer))
    (go-if-err-nil-turn-off (current-buffer))))

;;;###autoload
(define-global-minor-mode
  global-go-if-err-nil-mode
  go-if-err-nil-mode
  (lambda () (go-if-err-nil-mode 1)))

(provide 'go-if-err-nil)

;;; go-if-err-nil.el ends here
