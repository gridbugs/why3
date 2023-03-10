;; why3.el - GNU Emacs mode for Why3

(defvar why3-mode-map
  (let ((map (make-sparse-keymap)))
    ;; (define-key map "\C-c\C-c" 'why3-generate-obligations) **)
    ;; (define-key map "\C-c\C-a" 'why3-find-alternate-file) **)
    ;; (define-key map "\C-c\C-v" 'why3-viewer) **)
    (define-key map [(control return)] 'font-lock-fontify-buffer)
    map))

(setq auto-mode-alist
      (append
       '(("\\.\\(why\\|mlw\\)\\'" . why3-mode))
       auto-mode-alist))

;; font-lock

(defun why3-regexp-opt (l)
  (regexp-opt l 'words))

;; keep synchronized with src/parser/lexer.mll
(defconst why3-font-lock-keywords-1
  (list
   `(,(why3-regexp-opt
       '("absurd" "alias" "assert" "assume"
         "check" "diverges" "ensures" "invariant"
         "raises" "reads" "requires" "returns"
         "variant" "writes")) . font-lock-type-face)
   `(,(why3-regexp-opt
       '("abstract" "any" "as" "at" "axiom"
         "begin" "break" "by"
         "clone" "coinductive" "constant" "continue"
         "do" "done" "downto"
         "else" "end" "epsilon" "exception" "exists" "export"
         "false" "float" "for" "forall" "fun" "function"
         "ghost" "goal" "if" "import" "in" "inductive"
         "label" "lemma" "let"
         "match" "meta" "module" "mutable" "not"
         "old" "partial" "predicate" "private" "pure"
         "raise" "range" "rec" "ref" "return"
         "scope" "so" "then" "theory" "to" "true" "try" "type"
         "use" "val" "while" "with")) . font-lock-keyword-face)
   )
  "Minimal highlighting for Why3 mode")

(defvar why3-font-lock-keywords why3-font-lock-keywords-1
  "Default highlighting for Why3 mode")

(defvar why3-indent 2
  "How many spaces to indent in why3 mode.")
(make-variable-buffer-local 'why3-indent)

;; syntax

(defvar why3-mode-syntax-table
  (let ((st (make-syntax-table)))
    ; identifiers
    (modify-syntax-entry ?' "w" st)
    (modify-syntax-entry ?_ "w" st)
    ; strings
    (modify-syntax-entry ?\" "\"" st)
    ; comments
    (modify-syntax-entry ?\( "()1n" st)
    (modify-syntax-entry ?\) ")(4n" st)
    (modify-syntax-entry ?* ". 23" st)
    st)
  "Syntax table for why3-mode")

;indentation

;http://www.emacswiki.org/emacs/ModeTutorial
(defun why3-indent-line ()
  "Indent current line as why3 logic"
  (interactive)
  (save-excursion
    (beginning-of-line)
    ;(debug)
    (if (bobp)  ; Check for rule 1
        (indent-line-to 0)
      (let ((not-indented t) cur-indent)
        (if (looking-at "^[ \t]*end") ; Check for rule 2
            (progn
              (save-excursion
                (forward-line -1)
                (setq cur-indent (- (current-indentation) why3-indent)))
              (if (< cur-indent 0)
                  (setq cur-indent 0)))
          (progn
            (if (looking-at "^[ \t]*\\(logic\\|type\\|prop\\)") ; check for clone
                (progn
                  (save-excursion
                    (forward-line -1)
                    (if (looking-at "^[ \t]*\\(logic\\|type\\|prop\\).*,[ \t]*$")
                        (progn
                          (setq cur-indent (current-indentation))
                          (setq not-indented nil))
                      (if (looking-at "^[ \t]*clone.*with ")
                          (progn
                            (setq cur-indent (+ (current-indentation) why3-indent))
                            (setq not-indented nil)
                            ))))))
        ;For the definition its very badly done...
          (if (looking-at "^[ \t]*$")
	      ;; (save-excursion
	      ;; 	(forward-line -1)
	      ;; 	(setq cur-indent (current-indentation))
	      ;; 	(setq not-indented nil))
              (progn
                (setq cur-indent 0)
                (setq not-indented nil))
	    (if (not
		 (looking-at "^[ \t]*(\*.*"))
            (if (not
                 (looking-at "^[ \t]*\\(logic\\|type\\|axiom\\|goal\\|lemma\\|inductive\\|use\\|theory\\|clone\\)"))
                (save-excursion
                  (condition-case nil
                      (save-excursion
                        (backward-up-list)
                        (setq cur-indent (+ (current-column) 1))
                        (setq not-indented nil))
                    (error
                     (forward-line -1)
                     (if (looking-at
                          "^[ \t]*\\(logic\\|type\\|axiom\\|goal\\|lemma\\|inductive\\)")
                         (setq cur-indent (+ (current-indentation) why3-indent))
                       (setq cur-indent (current-indentation)))
                     (setq not-indented nil)))))))
          ;For inside theory or namespace
          (save-excursion
            (while not-indented
              (forward-line -1)
              (if (looking-at "^[ \t]*end") ; Check for rule 3
                  (progn
                    (setq cur-indent (current-indentation))
                    (setq not-indented nil))
                                        ; Check for rule 4
                (if (looking-at "^[ \t]*\\(theory\\|namespace\\)")
                    (progn
                      (setq cur-indent (+ (current-indentation) why3-indent))
                      (setq not-indented nil))
                  (if (bobp) ; Check for rule 5
                      (setq not-indented nil)))))))
        (if cur-indent
            (indent-line-to cur-indent)
          (indent-line-to 0)))))))

; compile will propose "why3 ide file" if no Makefile is present

(add-hook 'why3-mode-hook
          (lambda ()
            (unless (file-exists-p "Makefile")
              (set (make-local-variable 'compile-command)
                   (let ((file (file-name-nondirectory buffer-file-name)))
                     (format "why3 ide %s" file))))))

(defconst why3--syntax-propertize
  (syntax-propertize-rules
    ; attributes: [@foo]
    ("\\(\\[\\)@[^]]*\\(]\\)" (1 "!]") (2 "!["))
    ; star: (*)
    ("\\((\\)\\*\\()\\)" (1 "()") (2 ")("))
  ))

(defvar compilation-first-column)
(defvar compilation-error-screen-columns)

;; setting the mode
(define-derived-mode why3-mode
  prog-mode "Why3"
  "Major mode for editing WhyML programs.

\\{why3-mode-map}"
  ; hilight
  (setq-local font-lock-defaults '(why3-font-lock-keywords))
  (setq-local font-lock-multiline t)
  ; indentation
  ;(setq-local indent-line-function 'why3-indent-line)
  ; error locations
  (setq-local compilation-first-column 0)
  (setq-local compilation-error-screen-columns nil)
  ; OCaml style comments for comment-region, comment-dwim, etc.
  (setq-local comment-start "(*")
  (setq-local comment-end   "*)")
  (setq-local syntax-propertize-function why3--syntax-propertize))

(provide 'why3)
