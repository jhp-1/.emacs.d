;;; joe-elfeed.el --- Elfeed feeds + Karl-Voit-style tag vocabulary -*- lexical-binding: t; -*-

;; Performance on Windows: fetch with curl, never url.el.  Emacs's own
;; `url-retrieve' is single-threaded and flaky on Windows (the same lesson
;; joe-research.el learned for zotra); curl fetches every feed in parallel over
;; Schannel and `--compressed' asks for gzip.  curl.exe ships in System32 on
;; Win10+ and is already on `exec-path' (init.el), and this build reports libz,
;; so `--compressed' is safe.  The DB lives in .emacs.d/elfeed/ (gitignored).

(use-package elfeed
  :ensure t
  :bind ("C-c w" . elfeed)
  :custom
  (elfeed-use-curl t)
  (elfeed-curl-max-connections 16)
  (elfeed-curl-timeout 30)
  (elfeed-db-directory (expand-file-name "elfeed" user-emacs-directory))
  ;; Shipping/energy feeds post many times a day — keep the default search
  ;; window small so the buffer renders fast; press `s' to widen it.
  (elfeed-search-filter "@1-month-ago +unread")
  :config
  (setq elfeed-curl-extra-arguments '("--compressed"))

  ;;;; Controlled tag vocabulary (after Karl Voit; one tag language with the
  ;;;; bibliography's `joe/bib-keywords' in joe-research.el).
  ;; Reuse the bib subject words wherever a feed's domain coincides, so a note
  ;; spun off a feed and a note spun off a citation carry the same tags.  The
  ;; fine philosophy subjects (metaphysics, epistemology, ...) are too narrow
  ;; for whole-feed tagging, so they collapse to one `philosophy' tag (the bib
  ;; drops `philosophy' because it IS the whole library; feeds are not).  Six
  ;; tags are new, for the current-affairs / health / tooling warrant a
  ;; philosophy library has none of.  Few; lower-case; single-word; general;
  ;; non-overlapping; English.
  ;;
  ;;   reused from the bib vocabulary:
  ;;     economics    political economy, macro, finance, marxian economics
  ;;     politics     political theory, movements, radical commentary
  ;;     history      historiography & history proper
  ;;     anthropology ethnology, prehistory, myth, ritual
  ;;     literature   books, criticism, literary culture
  ;;     esotericism  western esotericism, occult, hermetica, myth-as-tradition
  ;;     religion     theology, scripture
  ;;     psychology   psychoanalysis, empirical/historical psychology
  ;;     science      the natural sciences & their history
  ;;     computing    software, CS, tools, cybernetics
  ;;   coarsened:
  ;;     philosophy   all philosophy proper (vs the bib's metaphysics/ethics/...)
  ;;   new (feed warrant only):
  ;;     geopolitics  war, foreign affairs, current conflict (vs `politics' = theory)
  ;;     china        the one region facet with enough feeds to earn a tag
  ;;     shipping     maritime, logistics, freight trade press
  ;;     energy       energy systems & commodities
  ;;     health       nutrition, metabolism, the body
  ;;     emacs        Emacs specifically (a deliberate carve-out of `computing')
  ;;
  ;; Feeds with no tag below could not be placed confidently from their name —
  ;; tag or drop them after a first look.  A bare string is a valid feed.
  (setq elfeed-feeds
        '(;; --- economics ---
          ("https://adamtooze.substack.com/feed" economics)              ; Adam Tooze
          ("https://www.phenomenalworld.org/feed/" economics)            ; Phenomenal World
          ("https://www.bruegel.org/rss.xml" economics)                  ; Bruegel
          ("https://daviskedrosky.substack.com/feed" economics history)  ; Great Transformations
          ("https://damnjehu.substack.com/feed" economics)               ; Jehu
          ("https://monthlyreview.org/feed/" economics politics)         ; Monthly Review
          ("https://paulcockshott.wordpress.com/feed" economics computing) ; Paul Cockshott
          ("https://therealmovement.wordpress.com/feed/" economics)      ; The Real Movement
          ("https://labourleisure.com/feed" economics)                   ; Labour & Leisure  (verify)
          ("https://edberg.substack.com/feed" economics)                 ; Reciprocal Contradiction  (verify)

          ;; --- politics ---
          ("https://illwill.com/feed.xml" politics)                      ; Ill Will
          ("https://cordeliers.substack.com/feed" politics)              ; Club des Cordeliers
          ("https://redkahina.substack.com/feed" politics)               ; Red's Newsletter  (verify)

          ;; --- geopolitics ---
          ("https://www.crisisgroup.org/rss.xml" geopolitics)            ; Crisis Group
          ("https://eventsinukraine.substack.com/feed" geopolitics)      ; Events in Ukraine
          ("https://www.craigmurray.org.uk/feed/" geopolitics)           ; Craig Murray
          ("https://nemets.substack.com/feed" geopolitics history)       ; Nemets
          ("https://mujammaharaket.substack.com/feed" geopolitics)       ; Mujamma Haraket  (verify)

          ;; --- china ---
          ("https://chinai.substack.com/feed" china computing)           ; ChinAI
          ("https://www.readingthechinadream.com/2/feed" china politics) ; Reading the China Dream

          ;; --- shipping ---
          ("https://theloadstar.com/feed/" shipping)                     ; The Loadstar
          ("https://splash247.com/feed" shipping)                        ; Splash247
          ("https://gcaptain.com/feed/" shipping)                        ; gCaptain

          ;; --- energy ---
          ("https://www.iea.org/rss/news" energy)                        ; IEA
          ("https://www.oxfordenergy.org/feed/" energy)                  ; Oxford Energy

          ;; --- health ---
          ("https://fireinabottle.net/feed/" health)                     ; Fire In A Bottle
          ("https://high-fat-nutrition.blogspot.com/feeds/posts/default" health) ; Hyperlipid
          ("https://dannyroddy.substack.com/feed" health)                ; The Danny Roddy Weblog
          ("https://t3uncoupled.substack.com/feed" health)               ; T3Uncoupled
          ("https://constantinek.substack.com/feed" health)              ; Maladies & Remedies
          ("https://stewartk.substack.com/feed" health)                  ; An Autodidact's N = 1
          ("https://breatheless.substack.com/feed/" health)              ; BreatheLess

          ;; --- philosophy ---
          ("https://sootyempiric.blogspot.com/feeds/posts/default?alt=rss" philosophy) ; The Sooty Empiric
          ("https://philosopheroftheoilsands.substack.com/feed" philosophy)            ; Philosopher of the Oil Sands
          ("https://henadology.wordpress.com/feed/" philosophy religion) ; Henadology
("https://plato.stanford.edu/rss/sep.xml" philosophy)
          ;; --- esotericism ---
          ("https://shwep.net/podcast/feed/" esotericism history)        ; SHWEP
          ("https://eliasartista.substack.com/feed" esotericism)         ; Avalon  (verify)
          ("https://vitaeaether.substack.com/feed" esotericism)          ; Vitae Aether  (verify; .com dup dropped)
          ("https://hieropunk.substack.com/feed" esotericism)            ; return of the onryō  (verify)

          ;; --- history & anthropology ---
          ("https://www.stoneageherbalist.com/feed" history anthropology) ; Grey Goose Chronicles
          ("https://www.patreon.com/rss/wydna?auth=ehq36sdUUCe8Tqp98rtrGYezQC9fHhR_&show=866564" history) ; Pseudodoxology

          ;; --- literature ---
          ("https://clereviewofbooks.com/feed/" literature)              ; Cleveland Review of Books
          ("https://apocalypse-confidential.com/feed/" literature)       ; Apocalypse Confidential
          ("https://thespouter.substack.com/feed" literature)            ; The Spouter
          ("https://asemic-horizon.com/feed/" literature)                ; asemic horizon  (verify)

          ;; --- computing ---
          ("https://feeds.simplecast.com/L9810DOa" computing)            ; Signals and Threads
          ("https://blog.andymatuschak.org/rss" computing)               ; Square Signals
          ("https://fmhy.net/feed.rss" computing)                        ; FMHY blog
          ("https://lateralthinkingtechnology.wordpress.com/feed/" computing) ; lateral thinking

          ;; --- emacs ---
          ("https://emacsredux.com/atom.xml" emacs)                      ; Emacs Redux
          ("https://protesilaos.com/master.xml" emacs)                   ; Protesilaos
          ("https://sachachua.com/blog/category/emacs/feed" emacs)       ; Sacha Chua (emacs)


          ;; --- science ---
          ("https://booty.substack.com/feed" science)                    ; Nuts & Boltzmann  (verify)

          ;; --- psychology ---
          ("https://www.patreon.com/rss/TheReturnOfTheRepressed?auth=f-ODlQ8p7jMc4o0hV1v0wz7LsVlgsoKI" psychology) ; The Return of The Repressed

          ;; --- untagged: place or drop after a look ---
          "https://justinusa2025.blogspot.com/feeds/posts/default?alt=rss" ; "1" — looks like a placeholder feed; probably delete
          "https://seanpmccarthy.substack.com/feed"                      ; $ean's Newsletter
          "https://electricsematic.wordpress.com/feed/"                  ; ELECTRIC SEMATIC
          "https://gardenscenery.net/feed"                               ; Garden Scenery (gardening)
          "https://tannerfboyle.substack.com/feed"                       ; Getting Spooked
          "https://oh4.co/links/rss.xml"                                 ; OH4 (linklog)
          "https://newsletter.ozwrites.com/feed"                         ; Oz's Newsletter
          "https://www.paradise-almanac.net/feed"                        ; Paradise Almanac
          "https://seer2005.substack.com/feed"                           ; The Limitless Readings
          "https://tropik.space/index.xml"                               ; Tropik
          "https://irregularnotes.substack.com/feed")))                  ; irregular notes

(provide 'joe-elfeed)
;;; joe-elfeed.el ends here
