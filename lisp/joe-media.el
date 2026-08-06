;;; joe-media.el --- Ambient noise playback via mpv -*- lexical-binding: t; -*-

;;; Commentary:
;; Long-form ambient/background noise tracks from joe/noises-dir (D:\Noises,
;; opus files, several hundred MB / 8-12 hours each).
;;
;; Not bongo: its only backends are mpg123/vlc/mplayer (checked its actual
;; source - no mpv support in the MELPA snapshot, which is itself six years
;; stale). mpg123 can't decode opus at all; vlc/mplayer are exactly the
;; heavier, cover-art-rendering direction explicitly not wanted here. mpv.el
;; instead drives mpv - already confirmed working end-to-end through
;; PipeWire - directly over its JSON IPC socket.

;;; Code:

(require 'joe-core)

(use-package mpv
  :ensure t
  :commands (mpv-play mpv-pause mpv-kill mpv-toggle-loop)
  :custom
  ;; The actual guarantee against album art: opus files often carry embedded
  ;; cover art as an attached-picture stream, which mpv will otherwise open a
  ;; window to display as if it were a video. This disables video decoding
  ;; entirely, not just window chrome - confirmed against mpv.el's real
  ;; defcustom, not assumed.
  (mpv-default-options '("--no-video")))

(defun joe/play-noise ()
  "Pick a file from `joe/noises-dir' and play it via mpv."
  (interactive)
  (let* ((files (directory-files joe/noises-dir nil
                                  "\\.\\(opus\\|mp3\\|ogg\\|flac\\|wav\\)\\'"))
         (choice (completing-read "Play: " files nil t)))
    (mpv-play (expand-file-name choice joe/noises-dir))))

(defun joe/stop-noise ()
  "Stop whatever mpv is currently playing."
  (interactive)
  (mpv-kill))

(define-key global-map (kbd "C-c n p") #'joe/play-noise)
(define-key global-map (kbd "C-c n P") #'joe/stop-noise)
(define-key global-map (kbd "C-c n SPC") #'mpv-pause)
;; Not bound on by default; C-c n l toggles it manually if wanted for a
;; particular track (files are 8-12 hours already, so looping is rarely
;; needed, but mpv.el's own toggle is right there when it is).
(define-key global-map (kbd "C-c n l") #'mpv-toggle-loop)

(provide 'joe-media)
;;; joe-media.el ends here
