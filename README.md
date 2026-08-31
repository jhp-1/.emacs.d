# dotemacs

This is one Emacs configuration for three machines.

## Function

The configuration does these tasks:

- It reads Org files and changes them.
- It gives each new note a name that starts with a time stamp.
- It shows web pages in an `eww` buffer.

All other functions are secondary. The telephone has only the tasks above.

## The machines

The three machines are not the same. Each one has a constant that identifies
it, and `early-init.el` sets these constants. A module reads the constant. A
module does not examine the machine again.

- **nixdesktop.** A NixOS workstation. Nix supplies pdf-tools, jinx and
  notmuch. Thus these three packages use `:ensure nil`.
- **x270.** A ThinkPad X270 with no window system. Its `/home` directory is
  `noexec`, thus Emacs cannot load a `.eln` file. `solar.el` selects the theme
  from the time of day.
- **android.** A telephone with no keyboard. The tool bar, the menu bar and
  the modifier bar are the input devices.

## Structure

`init.el` loads `joe-core` and `joe-completion` immediately. Idle timers load
the other modules. The image below shows the modules and the sequence.

```
╔════════════════════════════╡ d o t e m a c s ╞═════════════════════════════╗
║                                                                            ║
║                               ,           ,                                ║
║                              /             \                               ║
║                             ((__-^^-,-^^-__))                              ║
║                              `-_---' `---_-'                               ║
║                               <__|o` 'o|__>                                ║
║                                  \  `  /                                   ║
║                                   ): :(                                    ║
║                                   :o_o:                                    ║
║                                    "-"                                     ║
║                                                                            ║
║                     one configuration, three machines                      ║
║                                                                            ║
║                                  ~  ~  ~                                   ║
║              .--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--.              ║
║         .-~                                                    ~-.         ║
║        (             S   Y   N   C   T   H   I   N   G            )        ║
║         `-.                                                    .-'         ║
║              `--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--'              ║
║            |                         |                         |           ║
║          .org                      .org                      .org          ║
║            |                         |                         |           ║
║            v                         v                         v           ║
║                                                                            ║
║                           ┌────────────────────┐       ╭──────────────╮    ║
║ ┌────────────────────┐    │ x270               │       │ .:| ((o))  87│    ║
║ │ nixdesktop         │    ├────────────────────┤       ├──────────────┤    ║
║ ├────────────────────┤    │ $ emacs -nw        │       │ File Edit    │    ║
║ │ ~/Notes            │    │                    │       ├──────────────┤    ║
║ │ ~/Texts            │    │ no window system   │       │ * TODO  ring │    ║
║ │ /mnt/media/Noises  │    │ no icons           │       │   the bell   │    ║
║ │                    │    │ no .eln files      │       │ * DONE  feed │    ║
║ │ Nix supplies       │    │                    │       │   the gnu    │    ║
║ │ pdf-tools, jinx    │    │ solar.el sets the  │       │ ~            │    ║
║ │ and notmuch, so    │    │ theme              │       ├──────────────┤    ║
║ │ they are           │    └────────────────────┘       │ -:**- tasks  │    ║
║ │ :ensure nil        │    ┌────────────────────┐       ├──────────────┤    ║
║ └────────────────────┘    │ [][][][][][][][][] │       │[C][M][S][A]  │    ║
║   ╲________________╱      │ [][][][][][][][][] │       │[M-x][www][+] │    ║
║      ┌──────────┐         │ [__][_______][___] │       ╰──────────────╯    ║
║      └──────────┘         └────────────────────┘           android         ║
║                                                                            ║
║                                  ·  ·  ·                                   ║
║                                                                            ║
║  ╭──────────────────────────────────────────────────────────────────────╮  ║
║  │ lisp/                                                                │  ║
║  ├──────────────────────────────────────────────────────────────────────┤  ║
║  │ joe-core            Packages, paths, and shared constants.      [==] │  ║
║  │ joe-completion      Vertico, Corfu, Consult, and Embark.        [==] │  ║
║  │ joe-org-notes       Org mode, Denote, and capture templates.    [==] │  ║
║  │ joe-research        Citar, pdf-tools, and the bibliography.     [==] │  ║
║  │ joe-counting-house  Capture commands and a transient menu.      [==] │  ║
║  │ joe-files           Dired and Ibuffer.                          [==] │  ║
║  │ joe-ui              Themes, the mode line, and fonts.           [==] │  ║
║  │ joe-eww             The eww web browser.                        [==] │  ║
║  │ joe-android         Touchscreen input for the telephone.        [==] │  ║
║  │ joe-tools           Magit, rg, Eshell, and timers.              [==] │  ║
║  │ joe-elfeed          Feeds, with a controlled tag vocabulary.    [==] │  ║
║  │ joe-mail            Notmuch, mbsync, and msmtp.                 [==] │  ║
║  │ joe-media           mpv plays the sound files.                  [==] │  ║
║  │ joe-python          Python blocks in Org mode.                  [==] │  ║
║  │ joe-ai              Interfaces to AI assistants.                [==] │  ║
║  ╰──────────────────────────────────────────────────────────────────────╯  ║
║                                                                            ║
║                                  ·  ·  ·                                   ║
║                                                                            ║
║  ╭──────────────────────────────────────────────────────────────────────╮  ║
║  │ init.el                                                              │  ║
║  ├──────────────────────────────────────────────────────────────────────┤  ║
║  │  0.0s              0.1s              0.5s              1.0s          │  ║
║  │   ●━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━━━━━●            │  ║
║  │   ┃                 ┃                 ┃                 ┃            │  ║
║  │   joe-core          joe-org-notes     joe-ui            joe-tools    │  ║
║  │   joe-completion    joe-research      joe-files         joe-eww      │  ║
║  │   joe-android *     joe-python                          joe-ai       │  ║
║  │                     joe-counting-house                  joe-elfeed   │  ║
║  │                                                         joe-mail     │  ║
║  │                                                         joe-media    │  ║
║  │                                                                      │  ║
║  │   * The telephone only, and immediately. There, the tool bar is the  │  ║
║  │     keyboard. The 1.0s group does not load on the telephone.         │  ║
║  ╰──────────────────────────────────────────────────────────────────────╯  ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝
```

## More data

`NOTES.md` gives the full description of each machine. The comments in each
module give more data than `NOTES.md`, and they are adjacent to the code that
they explain.
