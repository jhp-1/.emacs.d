;;; joe-media.el --- Ambient noise via mpv; torrents via transmission -*- lexical-binding: t; -*-

;;; Commentary:
;; Two unrelated media concerns share this file: mpv for ambient noise
;; playback, and the transmission RPC client for torrents.
;;
;; Long-form ambient/background noise tracks from joe/noises-dir (opus files,
;; several hundred MB / 8-12 hours each).
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


;;;; Torrents - transmission.el against the daemon's RPC on localhost:9091.
;;
;; The daemon deliberately runs as its own uid (70, the static NixOS
;; ids.uids.transmission), not as joe. Barrier 4's OUTPUT chain is
;; policy-drop, and BitTorrent needs outbound connections to *arbitrary* high
;; ports, because every peer listens on its own random one. Allowing
;; `dport 51413' would not have fixed the Sep 6 failure: 51413 is only our own
;; listen port, not the peers'. So configuration.nix carries a
;; `meta skuid 70 accept' exemption covering the daemon and nothing else joe
;; runs. This file only drives the RPC - it cannot open that hole itself, which
;; is why nothing here worked before admin applied the rebuild.
;;
;; Bound to C-c T, not the C-c f prefix: `C-c f t' is already
;; joe/bib-set-keywords and `C-c f T' is joe/bib-tag-untagged-entries.
;;
;; host/service/rpc-path defaults already match the daemon - `rpc-url' is the
;; base "/transmission/" and the endpoint is base + "rpc", so the apparent
;; mismatch with transmission-rpc-path is not one.

(use-package geoip
  :ensure t
  :defer t)

(declare-function geoip-new-buffer "geoip" (path))
(declare-function geoip-lookup "geoip" (geoip-buffer ip))

;; DB-IP Country Lite is supplied by DB-IP under CC BY 4.0:
;; https://db-ip.com/db/download/ip-to-country-lite
(defconst joe/transmission-geoip-database
  (expand-file-name "transmission/dbip-country-lite.mmdb"
                    (or (getenv "XDG_CACHE_HOME") "~/.cache/"))
  "Local IP-to-country database used by the Transmission peers buffer.")

(defvar joe/transmission--geoip-buffer nil
  "Buffer containing `joe/transmission-geoip-database'.")

(defun joe/transmission--geoip-months ()
  "Return the current and previous months in DB-IP's URL format."
  (let* ((now (decode-time nil t))
         (month (nth 4 now))
         (year (nth 5 now))
         (previous-month (if (= month 1) 12 (1- month)))
         (previous-year (if (= month 1) (1- year) year)))
    (list (format "%04d-%02d" year month)
          (format "%04d-%02d" previous-year previous-month))))

(defun joe/transmission--download-geoip-database ()
  "Download the current free DB-IP country database.
Try the previous month's database too, because a new monthly file can appear
a few days after the start of the month."
  (require 'url-handlers)
  (let ((directory (file-name-directory joe/transmission-geoip-database)))
    (make-directory directory t)
    (let* ((prefix (expand-file-name ".dbip-country-lite-" directory))
           (compressed (make-temp-file prefix nil ".mmdb.gz"))
           (uncompressed (make-temp-file prefix))
           downloaded)
      (unwind-protect
          (progn
            (dolist (month (joe/transmission--geoip-months))
              (unless downloaded
                (condition-case nil
                    (progn
                      (message "Downloading the %s DB-IP country database..." month)
                      (url-copy-file
                       (format "https://download.db-ip.com/free/dbip-country-lite-%s.mmdb.gz"
                               month)
                       compressed t)
                      (setq downloaded t))
                  (error nil))))
            (unless downloaded
              (error "Could not download the DB-IP country database"))
            (with-temp-buffer
              (set-buffer-multibyte nil)
              (unless (zerop (call-process "gzip" nil t nil "-dc" compressed))
                (error "Could not decompress the DB-IP country database"))
              (let ((coding-system-for-write 'no-conversion))
                (write-region nil nil uncompressed nil 'silent)))
            (rename-file uncompressed joe/transmission-geoip-database t)
            (message "Downloaded the DB-IP country database"))
        (dolist (file (list compressed uncompressed))
          (when (file-exists-p file)
            (delete-file file)))))))

(defun joe/transmission--geoip-buffer ()
  "Return a live buffer for the local DB-IP country database."
  (unless (file-readable-p joe/transmission-geoip-database)
    (joe/transmission--download-geoip-database))
  (unless (buffer-live-p joe/transmission--geoip-buffer)
    (require 'geoip)
    (setq joe/transmission--geoip-buffer
          (geoip-new-buffer joe/transmission-geoip-database)))
  joe/transmission--geoip-buffer)

(defun joe/transmission-peer-location (ip)
  "Return the English country name associated with peer address IP."
  (require 'geoip)
  (let* ((record (geoip-lookup (joe/transmission--geoip-buffer) ip))
         (country (or (alist-get 'country record)
                      (alist-get 'registered_country record))))
    (alist-get 'en (alist-get 'names country))))

(use-package transmission
  :ensure t
  :commands (transmission transmission-add)
  :bind ("C-c T" . transmission)
  :custom
  (transmission-host "localhost")
  (transmission-service 9091)
  ;; transmission.el deliberately leaves this nil by default.  Supplying a
  ;; local lookup function makes its otherwise-empty Location column useful
  ;; without sending every connected peer address to a web API.
  (transmission-geoip-function #'joe/transmission-peer-location)
  (transmission-geoip-use-cache t)
  ;; Without this the buffers are static and progress only moves on a manual
  ;; `g'; these are the four views where live refresh is actually wanted.
  (transmission-refresh-modes '(transmission-mode
                                transmission-files-mode
                                transmission-info-mode
                                transmission-peers-mode))
  ;; nil matches rpc-authentication-required = false. If that is ever turned
  ;; on, set this to '(:username "joe") and put the secret in ~/.authinfo.gpg -
  ;; the value is an auth-source spec, so it looks up host/service itself
  ;; rather than needing the password inline.
  (transmission-rpc-auth nil))

(provide 'joe-media)
;;; joe-media.el ends here
