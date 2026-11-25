;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Alvaro Garcia"
      user-mail-address "alvarogarcia7@noreply.users.github.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

  ;; AGB - Make tags complete for all agenda files
;; From https://emacs.stackexchange.com/questions/36402/org-mode-tags-are-not-available-across-agenda-files
;(after! org
;  (setq-local org-complete-tags-always-offer-all-agenda-tags t))

;; AGB https://www.reddit.com/r/DoomEmacs/comments/jca63l/how_to_see_all_of_error_message/?rdt=45574
;; in ~/.doom.d/config.el
(after! lsp-ui
  (setq lsp-ui-sideline-diagnostic-max-lines 2))

(setq projectile-project-search-path '(
    ("~/org" . 2) 
    ("~/org-b3" . 2) 
    ("~/.config" . 1)))

;; https://emacs.stackexchange.com/questions/29152/how-to-use-global-tags-list-when-tagging-text-files-with-org-mode-and-helm
(setq org-complete-tags-always-offer-all-agenda-tags t)

;; 2026-11-25 15:59:16 AGB
;; This part is unstable: I want to automatically propose the datetime when SPC m d t/T
;; Link: https://share.google/aimode/kgOWm3sHbxcA6hcRu



;;in emacs how to org-time-stamp with the default value
;;
;;To insert an Org timestamp using the default value (today's date and/or current time), you can either accept the prompt immediately or bypass it using prefix arguments.
;;
;;Interactive Keybindings
;;
;;• Accept the default date at the prompt. Press C-c . (org-time-stamp), then immediately press RET without typing anything to insert today's date (<YYYY-MM-DD Day>).
;;• Accept the default date and time at the prompt. Press C-u C-c ., then immediately press RET to insert today's date with the current time (<YYYY-MM-DD Day HH:MM>).
;;• Insert current date and time immediately (no prompt). Press C-u C-u C-c . (two universal prefix arguments). According to the Org Mode Manual, this skips the interactive calendar prompt and inserts an active timestamp with the current time right away.
;;• Insert an inactive timestamp. Replace . with ! in any of the commands above (for example, C-u C-u C-c ! for the current date and time without prompting).
;;
;;Emacs Lisp (Programmatic)
;;
;;If you are writing a custom function or capture template in Elisp, use org-insert-time-stamp:
;;elisp
;;;; Insert active timestamp with current date only
;;(org-insert-time-stamp (current-time))
;;
;;;; Insert active timestamp with current date and time
;;(org-insert-time-stamp (current-time) t)
;;
;;;; Insert inactive timestamp with current date and time
;;(org-insert-time-stamp (current-time) t t)
;;Kodu dikkatli kullanın.
;;If you're trying to automate this, let me know:
;;• Trigger event (creating a heading, changing a TODO state, or using a capture template)
;;• Timestamp type (active <...> or inactive [...])
;;I can provide the exact Elisp snippet for your config.
;;Yapay zeka hata yapabildiğinden verdiği yanıtları doğrulayın 
;;• 
;;Stack Overflow
;;How to insert current time in the emacs org
;;July 2, 2012 — In emacs-lisp, you could use (org-insert-time-stamp (current-time) t) With default settings, it will generate a time stamp on the ...
;;• 
;;Org mode
;;Creating Timestamps (The Org Manual)
;;With two prefix arguments, insert an active timestamp with the current time without prompting. C-c ! ( org-timestamp-inactive ) bu...
;;• 
;;Org mode
;;The date/time prompt (The Org Manual)
;;Org mode date/time prompt: accepts flexible string formats starting at string beginning, deriving unspecified values from default ...
;;
;;how to set the default (org-insert-time-stamp (current-time) t t)
;;
;;To make (org-insert-time-stamp (current-time) t t) your default behavior—meaning it inserts an inactive timestamp with the current date and time immediately without prompting—you can either create a custom keybinding or override the default timestamp command in your Emacs configuration (init.el).
;;
;;Option 1: Bind a Custom Shortcut (Recommended)
;;
;;This leaves standard C-c . and C-c ! behavior intact while giving you a fast, one-step shortcut for your preferred format:
;;elisp
;;(defun my/org-insert-current-inactive-timestamp ()
;;  "Insert an inactive timestamp with the current date and time without prompting."
;;  (interactive)
;;  (org-insert-time-stamp (current-time) t t))
;;
;;(with-eval-after-load 'org
;;  (define-key org-mode-map (kbd "C-c t") #'my/org-insert-current-inactive-timestamp))
;;Kodu dikkatli kullanın.
;;(You can replace "C-c t" with any key combination you prefer.)
;;
;;Option 2: Override C-c ! (Inactive Timestamp Command)
;;
;;If you want C-c ! (org-time-stamp-inactive) to insert the current date and time immediately without opening the prompt, add this to your init.el:
;;elisp
;;(with-eval-after-load 'org
;;  (define-key org-mode-map (kbd "C-c !")
;;    (lambda ()
;;      (interactive)
;;      (org-insert-time-stamp (current-time) t t))))
;;Kodu dikkatli kullanın.
;;
;;Option 3: Override C-c . (Active Timestamp Command)
;;
;;If you want the primary C-c . shortcut to run this instead:
;;elisp
;;(with-eval-after-load 'org
;;  (define-key org-mode-map (kbd "C-c .")
;;    (lambda ()
;;      (interactive)
;;      (org-insert-time-stamp (current-time) t t))))
;;Kodu dikkatli kullanın.
;;If you also want this timestamp added automatically without pressing any keys, let me know:
;;• When it should happen (e.g., creating a new heading, saving a file, or via org-capture)
;;• Where it should go (e.g., inside a :CREATED: property drawer or directly under the heading)
;;I can share the hook or template setup for that.

(defun insert-now-timestamp()
  "Insert org mode timestamp at point with current date and time."
  (interactive)
  (org-insert-time-stamp (current-time) t))

(defun my/org-insert-current-inactive-timestamp ()
  "Insert an inactive timestamp with the current date and time without prompting."
  (interactive)
  (org-insert-time-stamp (current-time) t t))

;;(with-eval-after-load 'org
;;  (define-key org-mode-map (kbd "SPC m d 5") #'my/org-insert-current-inactive-timestamp))
;;
;;(with-eval-after-load 'org
;;  (define-key org-mode-map (kbd "SPC m d t")
;;    (lambda ()
;;      (interactive)
;;      (org-insert-time-stamp (current-time) t t))))
