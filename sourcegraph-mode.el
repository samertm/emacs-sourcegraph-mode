;;; sourcegraph-mode.el --- Major mode for the Go programming language

;; Copyright 2014 The sourcegraph-mode Authors. All rights reserved. Use of this
;; source code is governed by a BSD-style license that can be found in the
;; LICENSE file.

;; Author: The sourcegraph-mode Authors
;; Version: 1
;; Keywords: sourcegraph
;; URL: https://github.com/sourcegraph/emacs-sourcegraph-mode
;;
;; This file is not part of GNU Emacs.

;;; Code:

(require 'cl)
(require 'etags)
(require 'ffap)
(require 'find-file)
(require 'ring)
(require 'json)
(require 'url)

(defmacro sourcegraph--xemacs-p ()
  `(featurep 'xemacs))

;; declare-function is an empty macro that only byte-compile cares
;; about. Wrap in always false if to satisfy Emacsen without that
;; macro.
(if nil
    (declare-function sourcegraph--position-bytes "sourcegraph-mode" (point)))

;; XEmacs unfortunately does not offer position-bytes. We can fall
;; back to just using (point), but it will be incorrect as soon as
;; multibyte characters are being used.
(if (fboundp 'position-bytes)
    (defalias 'sourcegraph--position-bytes #'position-bytes)
  (defun sourcegraph--position-bytes (point) point))

(defcustom sourcegraph-mode-hook nil
  "Hook called by `sourcegraph-mode'."
  :type 'hook
  :group 'sourcegraph)

(defcustom src-command "src"
  "The 'src' command."
  :type 'string
  :group 'sourcegraph)


(defcustom gofmt-show-errors 'buffer
  "Where to display gofmt error output. It can either be
displayed in its own buffer, in the echo area, or not at all.

Please note that Emacs outputs to the echo area when writing
files and will overwrite gofmt's echo output if used from inside
a before-save-hook."
  :type '(choice
          (const :tag "Own buffer" buffer)
          (const :tag "Echo area" echo)
          (const :tag "None" nil))
  :group 'sourcegraph)

;;;###autoload
(define-minor-mode sourcegraph-mode
  "Minor mode for using Emacs with Sourcegraph and srclib.

The following extra functions are defined:

- `foo-bar'
- `baz-qux'

If you want to use `godef-jump' instead of etags (or similar),
consider binding godef-jump to `M-.', which is the default key
for `find-tag':

\(add-hook 'sourcegraph-mode-hook (lambda ()
                          (local-set-key (kbd \"M-.\") #'godef-jump)))

Please note that srclib is an external dependency. You can install
it with

go get github.com/sourcegraph/srclib/cmd/src
"
  :lighter " srcgraph"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-M-.") 'sourcegraph-describe)
            map))

;;;###autoload
;(add-hook 'sourcegraph-mode-hook 'sourcegraph-mode)

(defun sourcegraph--coverage-origin-buffer ()
  "Return the buffer to base the coverage on."
  (or (buffer-base-buffer) (current-buffer)))

(defun sourcegraph--call (point)
  "Call src, acquiring definition position and expression
description at POINT."
  (if (sourcegraph--xemacs-p)
      (error "src does not reliably work in XEmacs, expect bad results"))
  (if (not (buffer-file-name (sourcegraph--coverage-origin-buffer)))
      (error "Cannot use src on a buffer without a file name")
    (let ((outbuf (get-buffer-create "*srcgraph*")))
      (with-current-buffer outbuf
        (erase-buffer))
      (call-process-region (point-min)
                           (point-max)
                           "src"
                           nil
                           outbuf
                           nil
                           "api"
                           "describe"
                           "--file"
                           (file-truename (buffer-file-name (sourcegraph--coverage-origin-buffer)))
                           "--start-byte"
                           (number-to-string (sourcegraph--position-bytes (+ point -1))))
      (with-current-buffer outbuf
        (json-read-from-string (buffer-substring-no-properties (point-min) (point-max)))))))

(defun sourcegraph-describe (point)
  "Describe the expression at POINT."
  (interactive "d")
  (save-selected-window 
    (condition-case nil
        (if (buffer-modified-p)
            (message "Can't describe from an unsaved buffer; save and try again.")
          (let ((resp (sourcegraph--call point)))
            (if (not resp)
                (message "No description found for expression at point")
              (let ((outbuf (get-buffer-create "*srcgraph*")))
                (let ((case-fold-search nil))
                  (with-current-buffer outbuf
                    (erase-buffer)
                    (insert (concat
                             "<base href='https://sourcegraph.com'>"
                             "<h1>" (assoc-default 'Name (assoc-default 'Def resp)) "</h1>"
                             "<br><br>"
                             (assoc-default 'DocHTML (assoc-default 'Def resp))
                             "<br><br>"
                             "<h3>Details</h3>"
                             "<table>"
                             "<tr><th>Repository</th><td>" (assoc-default 'Repo (assoc-default 'Def resp)) "</td></tr>"
                             "<tr><th>File</th><td>" (assoc-default 'File (assoc-default 'Def resp)) "</td></tr>"
                             (mapconcat (lambda (e) (format "<tr><th>%s</th><td>%s</td></tr>" (car e) (json-encode (cdr e)))) (assoc-default 'Data (assoc-default 'Def resp)) "\n")
                             "</table>"
                             "<br><br><br>"
                             (if (> (length (assoc-default 'Examples resp)) 0)
                                 (concat
                                  "<h2>Examples on ✱ Sourcegraph</h2>"
                                  "<hr>"
                                  "<br><br>"
                                  (mapconcat
                                   (lambda (x) (concat "<h3>" (assoc-default 'Repo x) "<br>&nbsp;@ " (assoc-default 'File x) ":" (number-to-string (assoc-default 'StartLine x)) "-" (number-to-string (assoc-default 'EndLine x)) "</h3>" "<pre style='background-color:#333'>" (replace-regexp-in-string (concat (assoc-default 'Path (assoc-default 'Def resp)) "\" class=\"ref\"><span") (concat (assoc-default 'Path (assoc-default 'Def resp)) "\" class=\"ref\"><span style=\"color:orange;font-weight:bold\"") (assoc-default 'SrcHTML x)) "</pre>")) (assoc-default 'Examples resp) "<br><hr><br>")))
                             ))
                    (shr-render-buffer outbuf)
                    ))))))
      (file-error (message "Could not run src binary")))))

;; an in-buffer browser
;; workaround for Emacs<24.4
;; TODO(sqs): how to disable for Emacs>=24.4?
(defun add-face-text-property (beg end face &optional appendp object)
  "Combine FACE BEG and END."
  (let ((b beg))
    (while (< b end)
      (let ((oldval (get-text-property b 'face)))
        (put-text-property
         b (setq b (next-single-property-change b 'face nil end))
         'face (cond ((null oldval)
                      face)
                     ((and (consp oldval)
                           (not (keywordp (car oldval))))
                      (if appendp
                          (nconc oldval (list face))
                        (cons face oldval)))
                     (t
                      (if appendp
                          (list oldval face)
                        (list face oldval)))))))))

(provide 'sourcegraph-mode)

; TODO(sqs): add define-globalized-minor-mode http://www.gnu.org/software/emacs/manual/html_node/elisp/Defining-Minor-Modes.html

;;; sourcegraph-mode.el ends here
