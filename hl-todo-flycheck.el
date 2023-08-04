
;;; hl-todo-flycheck --- Summary

;;; Commentary:


;; Based on https://emacs.stackexchange.com/questions/29496/automatically-run-org-lint-through-flycheck
;; TODO: test with flycheck-projectile-list-errors

(require 'hl-todo)
(require 'flycheck)

;;; Code:

;; PROMT: elisp function that receives a regex and returns a list of
;; line numbers where the regex matches the current buffer
(defun hl-todo-flycheck--occur-to-error (&optional buffer regex)
  "Find lines in BUFFER where the given REGEX matches.  Return a list of (position text id)."
  (let* ((buffer (or buffer (current-buffer)))
         (regex (or regex (hl-todo--regexp)))
         (occurrences '()))
    (with-current-buffer buffer
      (with-syntax-table hl-todo--syntax-table ; TODO: from hl-todo-occur, dont know the actual effect
        (save-excursion
          (goto-char (point-min))
          (let ((case-fold-search nil)) ; Only exact case in search
            (while (re-search-forward regex nil t)
              ;;(message "buscando en:%s" (point))word

              (let* ((pos (point))
                     (id (thing-at-point 'symbol))
                     (bol (line-beginning-position))
                     (eol (line-end-position))
                     (line-at-point (buffer-substring bol eol))
                     (msg (substring line-at-point (string-match regex line-at-point))))
                (push (list pos msg id) occurrences)))))))
    occurrences))

(defun hl-todo-flycheck--start (checker callback)
  "Start function of hl-todo checker.  See `flycheck-define-generic-checker'."
  ;;(message "hl-todo-flycheck--start")
  (funcall
   callback 'finished
   (mapcar (lambda (pos-msg-id)
             (let ((pos (nth 0 pos-msg-id))
                   (msg (nth 1 pos-msg-id))
                   (id  (nth 2 pos-msg-id)))
               ;;(message "nuevo error:%s %s" pos msg)
               (flycheck-error-new-at-pos pos 'info msg :id id :checker checker)
               ))
           (hl-todo-flycheck--occur-to-error))))

(defun hl-todo-flycheck--get-all-modes ()
  "Computes all modes referenced by existing checkers."
  (seq-uniq
   (mapcan (lambda (checker)
             (let* ((modes (flycheck-checker-get checker 'modes))
                    ;; Ensure modes is a list
                    (modes ( if (listp modes)
                               modes
                             (list modes))))
               ;; Copy the list, to do not modify original list of checker
               (copy-sequence modes)))
           flycheck-checkers)))


;; FIXME: Convert to customizable variable
(defvar hl-todo-flycheck-disabled-modes '())

(defvar hl-todo-flycheck-enabled nil)

(make-variable-buffer-local 'hl-todo-flycheck-enabled)

(defun hl-todo-flycheck-enabled-p ()
  "Decide if hl-todo-flycheck is enabled."
  hl-todo-flycheck-enabled)

(defun hl-todo-flycheck-enable ()
  "Install and enable hl-todo-flycheck."
  (interactive)

  (setq hl-todo-flycheck-enabled t)

  ;; Create hl-todo checker
  (flycheck-define-generic-checker 'hl-todo
    "Syntax checker for hl-todo."
    :start 'hl-todo-flycheck--start
    :predicate 'hl-todo-flycheck-enabled-p
    :modes (hl-todo-flycheck--get-all-modes))

  ;; Register hl-todo checker
  (add-to-list 'flycheck-checkers 'hl-todo t)
  
  ;; Chain hl-todo checker to all existing checkers, except disabled modes
  (dolist (checker flycheck-checkers)
    (unless (or
             (eq checker 'hl-todo)
             (member checker hl-todo-flycheck-disabled-modes))
      (flycheck-add-next-checker checker 'hl-todo t))))

(defun hl-todo-flycheck-uninstall ()
  "Disable hl-todo-flycheck."
  (interactive)
  (setq hl-todo-flycheck-enabled nil))

(provide 'hl-todo-flycheck)

;;; hl-todo-flycheck.el ends here

