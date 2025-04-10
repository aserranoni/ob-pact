;;; ob-pact.el --- Org Babel support for Pact -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Ariel Serranoni
;; Author: Ariel Serranoni <arielserranoni@gmail.com>
;; Maintainer: Ariel Serranoni <arielserranoni@gmail.com>
;; Created: March 26, 2025
;; Version: 0.0.1
;; Keywords: languages, lisp, tools
;; Homepage: https://github.com/aserranoni/ob-pact
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; Org Babel support for the Pact language.
;;
;;; Code:

(require 'org)
(require 'ob)
(require 'comint)
;; Removed: (require 'cl-lib)

;; Polyfill for string-trim (for older Emacs versions)
(unless (fboundp 'string-trim)
  (defun string-trim (string)
    "Remove leading and trailing whitespace from STRING."
    (replace-regexp-in-string
     "\\`[ \t\n\r]+\\|[ \t\n\r]+\\'" "" string)))

;; Polyfill for string-join (for older Emacs versions)
(unless (fboundp 'string-join)
  (defun string-join (strings &optional separator)
    "Join STRINGS into one string separated by SEPARATOR.
Default SEPARATOR is \"\"."
    (mapconcat 'identity strings (or separator ""))))

(defvar org-babel-pact-repl-buffer "*pact-repl*"
  "Name of the buffer for the Pact REPL session.")

(defvar org-babel-pact--prompt "pact> "
  "The prompt string used by the Pact REPL.")

(defun org-babel-pact--start-repl ()
  "Start a Pact REPL if it's not already running.
This uses the `pact` executable without any extra arguments."
  (unless (comint-check-proc org-babel-pact-repl-buffer)
    (make-comint-in-buffer "pact-repl" org-babel-pact-repl-buffer "pact"))
  org-babel-pact-repl-buffer)

(defun org-babel-pact--wait-for-prompt (prompt &optional timeout)
  "Wait until the current buffer shows the PROMPT.
PROMPT defaults to `org-babel-pact--prompt'. TIMEOUT (in seconds)
defaults to 5. Signal an error if the prompt does not appear within TIMEOUT."
  (let ((prompt (or prompt org-babel-pact--prompt))
        (timeout (or timeout 5))
        (start-time (float-time)))
    (while (and (< (- (float-time) start-time) timeout)
                (not (save-excursion
                       (goto-char (point-max))
                       (search-backward prompt nil t))))
      (accept-process-output (get-buffer-process (current-buffer)) 0.1))
    (unless (save-excursion
              (goto-char (point-max))
              (search-backward prompt nil t))
      (error "Timeout waiting for REPL prompt"))))

(defun org-babel-pact--get-output (cmd)
  "Return the text between the last two occurrences of \"pact>\" in the \"*pact-repl*\" buffer,
with the initial CMD (and any surrounding whitespace) removed from the beginning if present.
Signal an error if fewer than two occurrences are found."
  (with-current-buffer "*pact-repl*"
    (save-excursion
      (goto-char (point-max))
      ;; Find the last occurrence of "pact>".
      (unless (search-backward "pact>" nil t)
        (error "No occurrence of \"pact>\" found in buffer"))
      (let ((last-prompt-start (match-beginning 0)))
        ;; Find the second-to-last occurrence of "pact>".
        (unless (search-backward "pact>" nil t)
          (error "Fewer than two occurrences of \"pact>\" found in buffer"))
        (let* ((second-last-prompt-end (match-end 0))
               (raw-output (buffer-substring-no-properties second-last-prompt-end last-prompt-start))
               ;; Build a regex that matches any whitespace, the command, then any whitespace, at the start.
               (cmd-regex (concat "^[ \t\r\n]*" (regexp-quote cmd) "[ \t\r\n]*"))
               (output (replace-regexp-in-string cmd-regex "" raw-output)))
          output)))))



(defun org-babel-pact--send-command (cmd)
  "Send CMD directly to the Pact REPL and return its output.
Assumes the REPL is already running and ready to accept input.
Only the newly printed output (with echoed input and prompt lines removed)
is returned."
  (with-current-buffer (org-babel-pact--start-repl)
    ;; Move to the end of the buffer and ensure the prompt is ready.
    (goto-char (point-max))
    (org-babel-pact--wait-for-prompt org-babel-pact--prompt 5)
    ;; Set a marker to capture output produced after sending the command.
    (let ((start-marker (point-marker)))
      ;; Insert the command and send it.
      (insert cmd)
      (comint-send-input)
      (org-babel-pact--get-output cmd)
      )))



(defun org-babel-execute:pact (body params)
  "Execute a block of Pact code by sending BODY to the REPL.
PARAMS is a plist of execution parameters (currently unused).
Returns the result output so that Org Babel can print it."
  (let ((result (org-babel-pact--send-command body)))
    result))

;;;###autoload
(defun org-babel-pact-initiate-session (&optional session _params)
  "Initiate a Pact session named SESSION if one is not already running."
  (org-babel-pact--start-repl))


(provide 'ob-pact)
;;; ob-pact.el ends here
