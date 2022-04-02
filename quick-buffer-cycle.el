;;; quick-buffer-cycle.el --- Quickly cycle between buffers

;; Copyright (C) 2020-2020  Mathias Dahl

;; Author: Mathias Dahl <mathias.dahl@gmail.com>
;; Maintainer: Mathias Dahl <mathias.dahl@gmail.com>
;; Version: 1.1.0
;; Keywords: convenience
;; URL: http://www.emacswiki.org/cgi-bin/wiki.pl?QuickBufferCycle

;; This file is not part of GNU Emacs.

;; This is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; For a long time (*) I have had the F1 key bound to a command that
;; takes me to the previous buffer.  It has been a very simple command
;; and it has served me well.  I use this in every editing session more
;; or less.
;;
;; * I think I first got the idea here:
;;   https://www.emacswiki.org/emacs/DedicatedKeys
;;
;; Certain days I am repeating the same buffer switching pattern over
;; and over again.  I switch to buffer A, then B, then C, and then A
;; again (or whatever).  Those days, my convenient F1 binding does not
;; work for me and I have to use some sort of classic "buffer
;; selector" (sometimes I use the standard one in Emacs, but often I
;; use Anything (precursor to Helm)), which of course works but is
;; slower/boring.
;;
;; This hack is my attempt to solve it.  The idea is that, in a given
;; scenario, I will quickly learn that I first press F1 once, to
;; switch to buffer A and do some work there.  Then I press the key
;; twice to switch to buffer C and work there, then press twice again
;; to switch to buffer B, and so on.  In my use cases, probably I will
;; seldom press the key more than twice, but we'll see about that.
;;
;; Before I wrote this hack I made an attempt to find if there were a
;; package like this already, but could not find one.  Turns out I was
;; wrong (perhaps I did not want to find it, it is fun to reinvent the
;; wheel afterall...), but I learned this after developing this
;; one... At any rate, now it's done and I will try to use it to see
;; if I like it.  Preliminary results shows that I will...
;;
;; About the approach using a timer:
;;
;; At first I tried an approach where I measured the time between each
;; call to the "switch" command.  Long story short I could not get it
;; work the way I wanted to (it now seems others have succeeded and at
;; least one of those solution seems to be quite complex, which is
;; perhaps why I did not succeed) and got the idea that a timer would
;; be the solution - simply wait with switching buffers until the user
;; has stopped "cycling".
;;
;; The solution is very simple, but it has one major drawback,
;; especially for the impatient: you can never switch to a buffer more
;; quickly than what the timer delay is set to (0.4 seconds by
;; default).  You can tweak the timer value to whatever suits you.  If
;; you have a fast computer and if you are a fast typist, you should
;; certainly try with 0.3 or even 0.2. If you can live with this
;; delay, this simple hack will probably work well for you.
;;
;; Usage:
;;
;; Bind `quick-buffer-cycle' to a convenient key.  I prefer the F1 key:
;;
;; (global-set-key [f1] 'quick-buffer-cycle)
;;
;; Now, the most common scenario (for me) is that I want to switch to
;; the previous buffer.  To do that, press the key once, and wait (the
;; default time to wait is 0.4 seconds).  The previous buffer will be
;; selected.
;;
;; If you know "where" in the buffer stack/list the buffer is that you
;; want to go to, quickly press the key as many times is needed to
;; select that buffer (let's say two times, if you know the buffer you
;; want is the one previous to the previous one).  Here, "quickly"
;; means to press the key with a maximum delay of
;; `quick-buffer-cycle-timeout' (default 0.4 seconds).
;;
;; To make it easier to select the correct buffer, the last X buffers
;; can be listed in the header line.  See `quick-buffer-cycle-hint-limit'.
;;
;; It's also possible to provide a numeric argument when calling
;; `quick-buffer-cycle', to jump directly to the buffer with that
;; number in the list.
;;

;;; Code:

(defvar quick-buffer-cycle-timer nil
  "Timer used to activate the actual switch.")

(defgroup quick-buffer-cycle nil
  "Quickly cycle between buffers."
  :group 'extensions
  :group 'convenience
  :prefix "quick-buffer-cycle-")

(defcustom quick-buffer-cycle-hint-limit 10
  "The number of buffers to display in the header line.
If set to a number N, shows N buffer names.  If set to nil, do
not show any buffers."
  :type 'integer
  :group 'quick-buffer-cycle)

(defcustom quick-buffer-cycle-number-items 'prefix
  "If non-nil, prefix or suffix buffer names with a number.
The number is the number of times you need to activate
`quick-buffer-cycle' in order to select that buffer.  The value
'prefix means to add the number before the buffer name, the value
'suffix to add it after."
  :type '(choice (const nil)
                 (const prefix)
                 (const suffix))
  :group 'quick-buffer-cycle)

(defface quick-buffer-cycle-buffer-name-face-normal
  '((t :inherit header-line))
  "Face for buffer names."
  :version "27.1"
  :group 'quick-buffer-cycle-faces)

(defface quick-buffer-cycle-buffer-name-face-selected
  '((t :inherit quick-buffer-cycle-buffer-name-face-normal :inverse-video t))
  "Face for selected buffer names.
Applies when `quick-buffer-cycle-add-selected-face' is non-nil."
  :version "27.1"
  :group 'quick-buffer-cycle-faces)

(defcustom quick-buffer-cycle-add-selected-face t
  "Add face `quick-buffer-cycle-buffer-name-face' to buffer name.
When non-nil, a face is added to the current buffer name during
cycling."
  :type '(choice (const t)
                 (const nil))
  :group 'quick-buffer-cycle)

(defcustom quick-buffer-cycle-show-number-threshold 4
  "Threshold for when to add a number to the buffer name.
To number all buffer names, set the number to 1.  Only has effect
when `quick-buffer-cycle-number-items' is non-nil."
  :type 'integer
  :group 'quick-buffer-cycle)

(defcustom quick-buffer-cycle-timeout 0.4
  "After this timeout a buffer will be switched to.
Depending on your typing speed and how fast computer you have,
you can experiment with values from 0.2 to 1.0 seconds.  A sweet
spot seems to be somewhere around 0.5 seconds."
  :type 'float
  :group 'quick-buffer-cycle)

(defcustom quick-buffer-cycle-buffer-with-no-hint nil
  "Regexp matching buffer names that should have no hint."
  :type 'string)

(defvar quick-buffer-cycle-count 0
  "Track repeated invocations of the cycle command.")

(defun quick-buffer-cycle-buffers ()
  "Return the list of buffers to chose from."
  (cl-remove-if (lambda (buf)
                  (string-match "^ " (buffer-name buf)))
                (buffer-list)))

(defun quick-buffer-cycle-switch ()
  "Switch to the last buffer that was cycled to."
  (switch-to-buffer (nth quick-buffer-cycle-count
                         (quick-buffer-cycle-buffers)))
  (quick-buffer-cycle-show-hint)
  (setq quick-buffer-cycle-count 0))

(defun quick-buffer-cycle-start-timer ()
  "Start timer."
  (setq quick-buffer-cycle-timer
        (run-with-timer quick-buffer-cycle-timeout nil
                        'quick-buffer-cycle-switch)))

(defun quick-buffer-cycle-stop-timer ()
  "Stop timer."
  (if (timerp quick-buffer-cycle-timer)
      (cancel-timer quick-buffer-cycle-timer)))

(defun quick-buffer-cycle-restart-timer ()
  "Restart timer."
  (quick-buffer-cycle-stop-timer)
  (quick-buffer-cycle-start-timer))

(defun quick-buffer-cycle-buffer-name (N)
  "Get the name of buffer number N from the buffer list."
  (buffer-name (nth N (quick-buffer-cycle-buffers))))

(defvar quick-buffer-cycle-skip-hint-buffers nil
  "Experimental.
A regular expression matching buffer names where
the header line should not be shown.")

(defun quick-buffer-cycle-show-hint (&optional mark)
  "Show buffers in the header line.
Optional argument MARK marks the selected buffer."
  (when (and quick-buffer-cycle-hint-limit
             (not (and quick-buffer-cycle-skip-hint-buffers
                       (string-match quick-buffer-cycle-skip-hint-buffers (buffer-name)))))
    (setq header-line-format
          (list (quick-buffer-cycle-get-hint mark)))))

(defun quick-buffer-cycle-get-hint (mark)
  "Get list of buffers to show in header line.
Argument MARK marks the selected buffer."
  (concat "  "
          (mapconcat
           (lambda (n)
             (let ((name (quick-buffer-cycle-buffer-name n)))
               (quick-buffer-cycle-format-item
                name n quick-buffer-cycle-count mark)))
           (number-sequence
            1 (min quick-buffer-cycle-hint-limit
                   (- (length (quick-buffer-cycle-buffers)) 1)))
           (propertize " | " 'face 'quick-buffer-cycle-buffer-name-face-normal))))

(defun quick-buffer-cycle-add-number (new-name n)
  "Add number in front of buffer name.
Argument NEW-NAME is the name of the buffer.
Argument N is the number of the buffer."
  (when (>= n quick-buffer-cycle-show-number-threshold)
    (when (eq 'prefix quick-buffer-cycle-number-items)
      (setq new-name (format "%d:%s" n new-name)))
    (when (eq 'suffix quick-buffer-cycle-number-items)
      (setq new-name (format "%s:%d" new-name n))))
  new-name)

(defun quick-buffer-cycle-format-item (name n count mark)
  "Format buffer NAME, based on its number N and COUNT.
Argument MARK marks the selected buffer."
  (let ((new-name name))
    (setq new-name (quick-buffer-cycle-add-number new-name n))
    (if (and mark (= n quick-buffer-cycle-count))
        (progn
          (when quick-buffer-cycle-add-selected-face
            (setq new-name
                  (propertize new-name 'face
                              'quick-buffer-cycle-buffer-name-face-selected))))
      (setq new-name (propertize
                      new-name
                      'face 'quick-buffer-cycle-buffer-name-face-normal)))
    new-name))

(defun quick-buffer-cycle (&optional arg)
  "Cycle between buffers quickly.
Successive rapid invocations cycle buffers further down on the
buffer list.  When pausing for the amount of time specified by
`quick-buffer-cycle-timeout', a buffer will be switched to.
After a buffer have been switched to, a hint is shown to help
switch to other buffers more easily.  With a numeric prefix
argument ARG, select the buffer with that number.  Typically
useful together with a relatively high hint limit, to reach
buffers that are far down in the buffer list."
  (interactive "^p")
  (setq quick-buffer-cycle-count (+ arg quick-buffer-cycle-count))
  (quick-buffer-cycle-show-hint t)
  (quick-buffer-cycle-restart-timer))

(add-hook 'buffer-list-update-hook 'quick-buffer-cycle-show-hint)

(defun quick-buffer-cycle-remove-buffer-list-update-hook ()
  "Remove hook that update the header line."
  (interactive)
  (remove-hook 'buffer-list-update-hook 'quick-buffer-cycle-show-hint))

(provide 'quick-buffer-cycle)

;;; quick-buffer-cycle.el ends here
