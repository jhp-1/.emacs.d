# dotemacs

One Emacs configuration; four machines that agree about nothing.

A Windows box that reaches Unix through `.cmd` wrappers. A NixOS desktop where
half the packages arrive from the store instead. A ThinkPad X270 with no GUI, a
`noexec` `/home`, and a grudge. And, lately, a phone.

It reads org, writes org, files org under a timestamp, and browses the web in a
buffer. Everything else is negotiable — and on the phone, mostly negotiated
away.

```
                          ,           ,
                         /             \
                        ((__-^^-,-^^-__))
                         `-_---' `---_-'
                          <__|o` 'o|__>
                             \  `  /
                             ): :(
                             :o_o:
                              "-"
                        one gnu, four houses

                   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                 ~~~   S  Y  N  C  T  H  I  N  G   ~~~
               ~~~~~  a cloud, but one you can grep  ~~~~~
                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                   '  '  '  '  '  '  '  '  '  '  '
                  .org  .org  .bib  .org  .org  .org
                    '  '  '  '  '  '  '  '  '  '
                     v     v     v     v     v

    ┌──────────────────────────────────────────────────────────────┐
    │ >_  WINDOWS  --  the one that speaks .cmd                    │
    ├──────────────────────────────────────────────────────────────┤
    │                                                              │
    │  C:\Users\Joe\bin\notmuch.cmd                                │
    │       `--> wsl.exe --> notmuch --> your inbox, eventually    │
    │                                                              │
    │  d:/Notes    d:/Texts    d:/Noises                           │
    │  w32-pipe-read-delay 0    <- magit sends its regards         │
    │                                                              │
    └──────────────────────────────────────────────────────────────┘

           ╲______________________________________________________╱
            ╲____________________________________________________╱
                              ┌──────────┐
                              └──────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │ (*)  NIXDESKTOP  --  everything is a derivation              │
    ├──────────────────────────────────────────────────────────────┤
    │                                                              │
    │  emacsWithPackages ships pdf-tools, jinx and notmuch itself, │
    │  so here they are :ensure nil -- MELPA cannot build the      │
    │  native halves, and /home is noexec, so it could not load    │
    │  them if it had.                                             │
    │                                                              │
    │  ~/Notes   ~/Texts   /mnt/media/Noises  (a spinning disk)    │
    │                                                              │
    └──────────────────────────────────────────────────────────────┘

           ╲______________________________________________________╱
            ╲____________________________________________________╱
                              ┌──────────┐
                              └──────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │ ###  x270  --  the console appliance, and it holds a grudge  │
    ├──────────────────────────────────────────────────────────────┤
    │                                                              │
    │  x270 login: joe                                             │
    │  $ emacs -nw                                                 │
    │     no GUI ....... no window system. not hidden. absent.     │
    │     no icons ..... kmscon has no font fallback               │
    │     no .eln ...... /home is noexec; dlopen says no           │
    │     no auto-dark . so the sun decides it (solar.el)          │
    │                                                              │
    └──────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │  [`][1][2][3][4][5][6][7][8][9][0][-][=][ <--- ]             │
    │  [Tab][Q][W][E][R][T][Y][U][I][O][P][ [ ][ ] ]               │
    │  [Ctl][A][S][D][F][G][H][J][K][L][;]['][ Enter ]             │
    │  [Shft][Z][X][C][V][B][N][M][,][.][/][  Shift  ]             │
    │  [Fn][^][Alt][         space         ][Alt][<][v][>]         │
    └──────────────────────────────────────────────────────────────┘

                    ╭───────────────────────────╮
                    │ .:|  ((o))      [###] 87% │
                    ├───────────────────────────┤
                    │ File Edit Options Tools   │  <- yes, really
                    ├───────────────────────────┤
                    │ * TODO  ring the bell     │
                    │   SCHEDULED: <today>      │
                    │ * DONE  feed the gnu      │
                    │ ** [X] twice, it was rude │
                    │                           │
                    │ ~                         │
                    │ ~                         │
                    ├───────────────────────────┤
                    │ -:**- tasks.org   L3   ;  │
                    ├───────────────────────────┤
                    │ [C][M][S][A][Sup][Shift]  │  <- modifier-bar-mode
                    │ [M-x][www][cal][+][keys]  │  <- tool-bar, at the bottom
                    ╰───────────────────────────╯
                          ANDROID  --  org + eww
                      volume-down, three times, fast = C-g
```

```
╔═══════════════════════════════════════════════════════════════════╗
║  lisp/   --   the card catalogue                                  ║
╠═══════════════════════════════════════════════════════════════════╣
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-core            packages, paths, load-bearing tedium  (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-completion      vertico, corfu, consult, embark       (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-org-notes       org, denote, transclusion. the point. (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-research        citar, pdf-tools, a bibliography      (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-counting-house  capture, a menu, a garden walk        (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-files           dired, ibuffer, hiding your dotfiles  (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-ui              themes, modeline, fonts, olivetti     (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-eww             the web, but calm                     (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-android         a phone that thinks it is a terminal  (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-tools           magit, rg, shells, timers             (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-elfeed          feeds, tagged like a librarian        (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-mail            notmuch, mbsync, msmtp                (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-media           mpv, playing rain at you              (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-python          org-babel, but numerate               (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
║ ┌───────────────────────────────────────────────────────────────┐ ║
║ │  joe-ai              the robot drawer                      (o)│ ║
║ └───────────────────────────────────────────────────────────────┘ ║
╚═══════════════════════════════════════════════════════════════════╝
```

```
  0.0s              0.1s              0.5s              1.0s
   ●━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━━●
   ┃                 ┃                 ┃                 ┃
   joe-core          joe-org-notes     joe-ui            joe-tools
   joe-completion    joe-research      joe-files         joe-eww
   joe-android *     joe-python                          joe-ai
                     joe-counting-house                    joe-elfeed
                                                         joe-mail
                                                         joe-media

   * Android only, and eagerly, off the timetable altogether: the tool
     bar IS the keyboard there, and a phone cannot spend its first
     second unable to press Ctrl. On Android the 1.0s platform is
     closed and boarded up. Nothing stops there.
```

The long version, for when a machine misbehaves and you want to know whether it
was on purpose: **[NOTES.md](NOTES.md)**. Though the real documentation lives in
the module comments, next to the code that earned it.
