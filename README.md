# `go-prettify-mode.el`
It is a minor mode for Emacs that replaces several Go statements, e.g. `if err != nil`, blocks with 1 code, `range` statement and hide types in anonymous functions. All these make a code shorter and more informative using overlays.

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

## TODO
- [x] change regexps to rx elisp package
- [x] change regexps to their own functions that return start point
- [x] make its own namespace (go-prettify)
- [x] codeberg
- [x] fix 2 cases in test.go
  - [x] if/else
  - [x] method func
- MELPA
- [ ] test case with structs
- [ ] change : to { } like in Goland
  - that should be done with 2 overlays that hide new lines, so the syntax is still highlighted
- [ ] commenting out doesn't work well (should be added a webhook that turns off and then turns on the feature)
- [ ] sometimes it fails to load go-mode with this thing, need to be debugged
