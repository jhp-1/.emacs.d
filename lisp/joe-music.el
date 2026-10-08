;;; joe-music.el --- SuperCollider in the existing Emacs daemon -*- lexical-binding: t; -*-

;; The NixOS SuperCollider package links JACK2. PipeWire's JACK library must
;; be first in LD_LIBRARY_PATH for both sclang and the scsynth it starts.
;; Resolve the store path only when music starts, not during Emacs startup.

(defvar joe/music--jack-library-directory nil)

(defconst joe/music-project-directory
  "/home/joe/projects/emacs-music-spike/"
  "Project used for the SuperCollider/Overtone comparison.")

(defun joe/music--jack-library-directory ()
  "Return this system's executable PipeWire JACK library directory."
  (or joe/music--jack-library-directory
      (let* ((store-path
              (car (process-lines
                    "nix-instantiate" "--eval" "--raw" "--expr"
                    "(import <nixpkgs> {}).pipewire.jack.outPath")))
             (directory (expand-file-name "lib" store-path)))
        (unless (file-exists-p (expand-file-name "libjack.so" directory))
          (error "PipeWire JACK library is not in the Nix store: %s" directory))
        (setq joe/music--jack-library-directory directory))))

(defun joe/music-start-sclang ()
  "Start SCEL with PipeWire JACK, without changing Emacs's global environment."
  (interactive)
  (require 'sclang)
  (let ((process-environment (copy-sequence process-environment))
        (jack (joe/music--jack-library-directory)))
    (setenv "LD_LIBRARY_PATH"
            (concat jack
                    (when-let ((existing (getenv "LD_LIBRARY_PATH")))
                      (concat ":" existing))))
    (sclang-start)))

(defun joe/music-start-overtone ()
  "Start CIDER in the pinned Overtone project with executable native libraries."
  (interactive)
  (require 'cider)
  (let* ((native-directory
          (file-truename (expand-file-name "jna-native/lib"
                                           joe/music-project-directory)))
         (entry-file
          (expand-file-name "src/music_spike/live.clj"
                            joe/music-project-directory)))
    (unless (file-exists-p
             (expand-file-name "libjnidispatch.so" native-directory))
      (error "Matching JNA native library is missing: %s" native-directory))
    (let ((process-environment (copy-sequence process-environment)))
      (setenv "LD_LIBRARY_PATH"
              (concat (joe/music--jack-library-directory)
                      (when-let ((existing (getenv "LD_LIBRARY_PATH")))
                        (concat ":" existing))))
      (setenv "JAVA_TOOL_OPTIONS"
              (concat "-Djna.boot.library.path=" native-directory
                      (when-let ((existing (getenv "JAVA_TOOL_OPTIONS")))
                        (concat " " existing))))
      (with-current-buffer (find-file-noselect entry-file)
        (cider-jack-in-clj
         (list :project-dir joe/music-project-directory
               :project-type 'clojure-cli))))))

(provide 'joe-music)
;;; joe-music.el ends here
