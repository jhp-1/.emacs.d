# dotemacs

One Emacs configuration. Three machines. It keeps a library of notes,
documents and correspondence, and it does the work that a library needs.

## What it does

- Denote names each note with a time stamp. It links the notes, and it puts
  one note inside another.
- Org mode builds the agenda, captures new items, and searches with `org-ql`.
- The Counting House is a research system: a hub, a ledger, a commonplace book
  and field notes. Each capture records its source. One command collects the
  annotations from the documents.
- citar and zotra keep the bibliography. Importers read the annotations and
  the new books. exiftool writes the keywords. A controlled vocabulary limits
  them.
- notmuch reads the mail and msmtp sends it. elfeed collects the feeds.
- eww shows web pages.
- agent-shell speaks to Claude Code. mpv plays ambient tracks. Org mode runs
  Python blocks.
- Magit, rg, Dired, Eshell and timers do the usual work.

## The machines

Each machine has a constant that identifies it, and `early-init.el` sets them.

- **nixdesktop.** NixOS. Nix supplies pdf-tools, jinx and notmuch, thus these
  three use `:ensure nil`.
- **x270.** No window system. Its `/home` is `noexec`, thus Emacs cannot load
  a `.eln` file. `solar.el` selects the theme.
- **android.** A telephone with no keyboard. The tool bar is the keyboard. It
  loads only what Org mode and eww need.

```
╔════════════════════════════════════════════════════════════════════════════╗
║                     ~v~                                    ~v~             ║
║                                                                            ║
║                                              ( )                           ║
║             ~v~                             (   )                          ║
║                                            ( ( ) )                ~v~      ║
║                             ~v~             (   )                          ║
║                              //__            ( )                           ║
║                            ///==_____  _                                   ║
║                          =//========_______|____|                          ║
║                         //==============___|_|__|                          ║
║                       ///==================|:|..|___                       ║
║                     ///====================|:|..|__/____                   ║
║                     _____==================|:|..|///:_________             ║
║                        |_____===================//:::::::::::              ║
║                        |:#_______=============///:::::::_.|                ║
║                     ___|:___#:::_____=======///::::::__##.|  ___           ║
║                 _____  |:::__:::|__|_____==//::::....____.||__ __|         ║
║                 ____   |:::::,,,|  |::____//:__#....._....||__|__|         ║
║             ~~~~|::_____   :(o:o)  |::__##|.#___.......... |++|==|___      ║
║         ~~~~~~~~~~~::::_____ /|\|  |:::___|.__........     |+_|==|  _____  ║
║     ~~~~~~~~~~~~~~~~~~~::::_____   :::::::|.......        |_____|       __|║
║   ~~~~~~~~~~~~~~~~~~~~~~~~~::::_____   :::|...            |__|__|   _____.|║
║     ~~~~~~~~~~~~~~~~~~~~~~~~~~~::::_____                  |++|==|____....  ║
║         ~~~~~~~~~~~~~~~~~~~~~~~~~~~::::_____                +|=__....      ║
║             ~~~~~~~~~~~~~~~~~~~~~~~~~~~::::_____        _____....          ║
║                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~::::__________....              ║
║                     ~~~~~~~~~~~~~~~~~~~~~~~~~~~::::__....                  ║
║                         ~~~~~~~~~~~~~~~~~~~~~~~~~~~:|                      ║
║                             ~~~~~~~~~~~~~~~~~~~~~                          ║
║                                 ~~~~~~~~~~~~~                              ║
║                                     ~~~~~                                  ║
╚════════════════════════════════════════════════════════════════════════════╝
```

`NOTES.md` holds the long version. The comments in each module hold more than
that, and they sit beside the code that they explain.
