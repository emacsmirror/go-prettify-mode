# `go-if-err-nil.el`
It is a minor mode for Emacs that replaces `if err != nil` statements in Go code to make them shorter and more informative using overlays.

The mode converts popular words that is used in handling errors to just Greek letters or symbols.  

__Before:__

![before](./pictures/before.png)

__After:__

![after](./pictures/after.png)

Twice shorter!

## Customization
To turn it on in every Go buffer, add a hook:

``` emacs-lisp
(add-hook 'go-mode-hook '(lambda () (go-if-err-nil-mode 1)))
```

To toggle it via a hotkey add this code:

``` emacs-lisp
(define-key go-mode-map (kbd \"C-c C-e\") #'go-if-err-nil-mode)
```

You can customize a face for overlays or what to display in an overlay via customization options or just setting variables `go-if-err-nil-regexp-alist` and `go-if-err-nil-face`.

How the configuration is looked in my `init.el` with `use-package`:
``` emacs-lisp
(use-package go-if-err-nil
  :after (go-mode)
  :config
  (define-key go-mode-map (kbd "C-c C-e") #'go-if-err-nil-mode))
```

