# `go-prettify-mode.el`
It is a minor mode for Emacs that replaces several Go statements, e.g. `if err != nil`, blocks with 1 code and `range` statement to make them shorter and more informative using overlays.

__Before:__

![before](./pictures/before.png)

__After:__

![after](./pictures/after.png)

Twice shorter!

## Customization
To turn it on in every Go buffer, add a hook:

``` emacs-lisp
(add-hook 'go-mode-hook '(lambda () (go-prettify-mode 1)))
```

To toggle it via a hotkey add this code:

``` emacs-lisp
(define-key go-mode-map (kbd \"C-c C-e\") #'go-prettify-mode)
```

You can customize a face for overlays or what to display in an overlay via customization options or just setting variables `go-if-err-nil-regexp-alist` and `go-prettify-face`.

How the configuration is looked in my `init.el` with `use-package`:
``` emacs-lisp
(use-package go-prettify
  :after (go-mode)
  :config
  (define-key go-mode-map (kbd "C-c C-e") #'go-prettify-mode))

(use-package go-mode
  :hook
  (go-mode . (lambda () (go-prettify-mode 1))))
```

