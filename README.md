# dotemacs

This is one Emacs configuration. It runs on three machines. It keeps a library
of notes, documents and correspondence, and it does the work that a library
needs.

## Function

**Notes.** Denote gives each new note a name that starts with a time stamp.

- It writes links and backlinks between the notes.
- It puts the text of one note inside another note, and keeps it current.
- It makes a journal entry for the day.
- It finds a note by its name or by its content.

**Org mode.** The agenda reads every Org file below the notes directory.

- Capture templates make a link, a task, a note, a journal entry or a record
  of a job application.
- `org-ql` searches the notes for a condition, and not only for a word.
- Speed keys move between the headlines with one key each.

**The Counting House.** This is a research system with four permanent notes: a
hub, a ledger, a commonplace book and a set of field notes.

- Each capture records its own source. The source is the document that you
  read at that moment.
- Two commands list the open questions and the recent traces.
- One command opens the garden-walk layout.
- One command collects the annotations from the documents of the last N days.
- A transient menu on `C-c n c` holds these commands.

**Documents.** The library holds PDF files and a BibTeX bibliography.

- citar shows the bibliography, and it opens the file for an entry.
- zotra makes an entry from a URL or from a DOI.
- Two commands import the annotations: one document, or all of them.
- One command imports new books from the download directory. It checks the
  ISBN, it compares the title, it asks a language model for keywords, and then
  it writes the entry.
- exiftool writes the keywords into the PDF metadata.
- A controlled vocabulary limits the keywords, and one command finds the
  entries that disobey it.
- recoll searches the full text of the library.

**Correspondence and news.**

- notmuch reads the mail. msmtp sends it. `auth-source-pass` holds the
  password.
- elfeed collects the feeds. curl fetches them together, not one at a time.
  A controlled vocabulary limits the tags here also.

**Other functions.**

- eww shows web pages.
- agent-shell speaks to Claude Code through the ACP protocol.
- mpv plays long ambient tracks.
- Org mode runs Python blocks.
- Magit, rg, Dired, Eshell and timers do the usual work.

## The machines

The three machines are not the same. Each one has a constant that identifies
it, and `early-init.el` sets these constants. A module reads the constant.

- **nixdesktop.** A NixOS workstation. Nix supplies pdf-tools, jinx and
  notmuch, thus these three packages use `:ensure nil`.
- **x270.** A ThinkPad X270 with no window system. Its `/home` directory is
  `noexec`, thus Emacs cannot load a `.eln` file. `solar.el` selects the theme
  from the time of day.
- **android.** A telephone with no keyboard. The tool bar, the menu bar and
  the modifier bar are the input devices. It loads only the modules that Org
  mode and eww need.

## The picture

```
╔════════════════════════════════════════════════════════════════════════════╗
║                                       |                                    ║
║                    (o>                |                                    ║
║                    //)              .-'-.                                  ║
║                   <\_/             /     \                                 ║
║ .------------------------.         `--=--'       .----------------------.  ║
║ | .--..--..--..--..--..--.|          ...         |   .        *      .  |  ║
║ | |==||==||  ||==||  ||==||                      |         .--.         |  ║
║ | '--''--''--''--''--''--'|                      |        (    )    .   |  ║
║ | .--..--..--..--..--..--.|      .-----.         |         `--'         |  ║
║ | |  ||==||==||  ||==||==||     /   |   \        |   .              *   |  ║
║ | '--''--''--''--''--''--'|     |   |    |       |      |       |       |  ║
║ | .--..--..--..--..--..--.|     |   '--  |       |      |       |    |  |  ║
║ | |==||  ||==||==||==||  ||     \        /       |     _|_    __|__ _|_ |  ║
║ | '--''--''--''--''--''--'|      `-----'         |    \___/  \_____/\_/ |  ║
║ '------------------------'                       | ~~~~~~~~~~~~~~~~~~~~ |  ║
║                                                  | ~~~~~~~~~~~~~~~~~~~~ |  ║
║ .------------------------.                       '----------------------'  ║
║ ||||| ||| |||| || ||||| ||                                                 ║
║ ||| |||| ||| ||||| || || |                                                 ║
║ '========================'                               ___               ║
║                                                         /  /               ║
║                               ,           ,            /  /                ║
║                              /             \          (__/                 ║
║                             ((__-^^-,-^^-__))           ||                 ║
║                              `-_---' `---_-'           _||_                ║
║                               <__|o` 'o|__>           |____|               ║
║                                  \  `  /             .--------.            ║
║                                  ): :(               |        |            ║
║                                  :o_o:               |________|            ║
║                                   "-"                 |      |             ║
║           ______________________________________________________           ║
║          /                                                      \          ║
║          |  .----------------.    ()    .----------------.  __  |          ║
║          | /  ~~~~~  ~~~~~~~  \   ||   | =-=-=-=-=-=-=-= | (__) |          ║
║          ||  ~~~~~~~  ~~~~~~~  |  ||   | =-=-=-=-=-=-=-= |  \/  |          ║
║          ||  ~~~~~~  ~~~~~~~~  |  \/   | =-=-=-=-=-=-=-= |      |          ║
║          | \__________________/        '----------------'       |          ║
║          |                                                      |          ║
║          | .--------------------------------------------------. |          ║
║          | |     ______________________________________       | |          ║
║          | '--------------------------------------------------' |          ║
║          '------------------------------------------------------'   /\_/\  ║
║            ||                                                  ||  ( -.- ) ║
║            ||                                                  ||   >   <  ║
║  ========================================================================  ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝
```

The picture is a metaphor. It is not a diagram of the code.

- The **wall of pigeonholes** is Denote. Each note has its own compartment,
  and the time stamp on the compartment never changes.
- The **shelf of books** is the bibliography and the PDF library.
- The **window** is elfeed and notmuch. The ships bring the news and the mail
  from outside the room.
- The **lamp** is the theme, which changes with the hour.
- The **clock** is the timers.
- The **open ledger** is Org mode: the agenda, and the Counting House ledger.
- The **inkwell** is the capture templates.
- The **card index** is Vertico, Consult and Embark. You find things with it.
- The **gramophone** is mpv.
- The **bird** is agent-shell. It repeats what it hears elsewhere.
- The **gnu** is Emacs. The gnu does the work.
- The **cat** is only a cat.

## The modules

| Module | Content |
|---|---|
| `joe-core` | Packages, paths, and the shared constants. |
| `joe-completion` | Vertico, Corfu, Cape, Consult, Embark, Orderless. |
| `joe-org-notes` | Org mode, Denote, transclusion, capture templates. |
| `joe-research` | citar, zotra, pdf-tools, the importers, the vocabulary. |
| `joe-counting-house` | The Counting House commands and its transient menu. |
| `joe-files` | Dired, Ibuffer, deadgrep. |
| `joe-ui` | Themes, the mode line, fonts, Olivetti, Pulsar. |
| `joe-eww` | The eww web browser. |
| `joe-android` | Touchscreen input for the telephone. |
| `joe-tools` | Magit, rg, Eshell, timers. |
| `joe-elfeed` | The feeds and their tag vocabulary. |
| `joe-mail` | notmuch, mbsync, msmtp. |
| `joe-media` | mpv and the ambient tracks. |
| `joe-python` | Python blocks in Org mode. |
| `joe-ai` | agent-shell. |

## Load sequence

`init.el` loads `joe-core` and `joe-completion` immediately. Idle timers load
the other modules: the notes and the library at 0.1 s, the interface and the
files at 0.5 s, and the remainder at 1.0 s.

The telephone is different. It loads `joe-android` immediately, because the
tool bar is its keyboard. It then loads the notes and eww at 0.1 s, and the
interface and the files at 0.5 s. It does not load the 1.0 s group at all.

## More data

`NOTES.md` gives the full description of each machine. The comments in each
module give more data than `NOTES.md`, and they are adjacent to the code that
they explain.
