<p align="center">
  <img src=".claude-plugin/icon.png" width="140" alt="/gta-6 icon">
</p>

<h1 align="center">/gta-6</h1>

<p align="center">
  <b>GTA VI comes out on a Thursday. Your job doesn't care.<br>Now your job doesn't have to know.</b>
</p>

<p align="center">
  An open-source agent skill for Claude Code, Grok, Codex, Cursor, Copilot and friends.
</p>

<p align="center">
  <img src="assets/demo.gif" alt="A terminal scrolling a fake build, test and deploy log, ending in MISSION PASSED, RESPECT +">
  <br><i>What your manager sees.</i>
</p>

## What it does

| Your manager sees | What's actually happening |
|---|---|
| Six hours of green deploys | A bash loop printing fake logs with suspicious service names |
| You, active on Slack all day | Your cursor moving **one pixel** every 4 minutes |
| A Mac that never locks | `caffeinate` |
| A crisp standup update tomorrow | Your agent wrote it while you were in Leonida |

## Install

### Claude Code (and Grok Build)

```
/plugin marketplace add wonkylamp/gta-6
/plugin install gta-6@wonkylamp
```

Grok Build reads Claude Code plugins automatically, so that's both done.

### Everything else, in one line

```bash
npx skills add wonkylamp/gta-6 -g
```

[`skills`](https://github.com/vercel-labs/skills) (Node 22.20+) detects your agents and installs to each one. Add `-a codex -a cursor` to pick specific ones.

### Or by hand

```bash
git clone https://github.com/wonkylamp/gta-6 ~/.gta-6
```

Then copy `~/.gta-6/skills/gta-6` into your agent's skills folder:

| Agent | Skills folder | Run it |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `/gta-6` |
| Grok Build | `~/.grok/skills/` | `/gta-6` |
| OpenAI Codex | `~/.agents/skills/` | `$gta-6` |
| Cursor | `~/.cursor/skills/` | `/gta-6` |
| GitHub Copilot (VS Code, CLI) | `~/.copilot/skills/`, or `copilot skill add ~/.gta-6/skills/gta-6` | `/gta-6` |
| Gemini CLI | `gemini skills install https://github.com/wonkylamp/gta-6 --path skills/gta-6` | "run gta-6" |
| Amp | `amp skill add wonkylamp/gta-6 --global` | "run gta-6" |
| OpenCode | `~/.config/opencode/skills/` | "run gta-6" |
| Windsurf | `~/.codeium/windsurf/skills/` | `/gta-6` |

`~/.agents/skills/` is read by most of these, if you'd rather copy it once. Tested in Claude Code; the rest follow each tool's documented skill folder. If yours does something weird, open a PR.

## Usage

```
/gta-6          # before Nov 19: a countdown and a lecture
/gta-6          # on launch day: the cover goes up
/gta-6 force    # skip the countdown ("dentist appointment")
/gta-6 stop     # MISSION PASSED. RESPECT +
```

On launch day your agent:

1. Opens a Terminal window that scrolls a convincing build, test and deploy log forever.
2. Keeps the Mac awake and nudges the cursor 1px every 4 minutes so Slack and Teams show you active.
3. Drafts a Slack status, a calendar block and tomorrow's standup line. Vague, impressive, unfalsifiable. You paste them; it posts nothing.

## Requirements

- **macOS.** It uses `caffeinate`, Terminal and a 5-line Swift file. On Linux or Windows you still get the alibi; the cover needs a PR.
- **Xcode Command Line Tools** for the cursor nudge (`xcode-select --install`). Without them you get a warning and no nudge.
- **A PS5 or Xbox Series X|S.** GTA VI is console-only at launch, which is the whole trick: the Mac is free to put on a show.

## Read the code first

It's ~150 lines of bash and 5 lines of Swift. Read them before you run them, which is good practice for anything you install from a README with jokes in it.

- [`skills/gta-6/SKILL.md`](skills/gta-6/SKILL.md) is what your agent follows.
- [`skills/gta-6/busy.command`](skills/gta-6/busy.command) prints the fake logs, ties `caffeinate` to its own PID so it dies with the window, and nudges the cursor every 4 minutes (`JIGGLE_EVERY` to change).
- [`skills/gta-6/jiggle.swift`](skills/gta-6/jiggle.swift) moves the cursor 1px right, then back.

Nothing touches the network. Close the window or run `/gta-6 stop` and everything is gone.

## Easter eggs

There are at least six GTA references hidden in the logs. Coworkers won't find them. Coworkers who are also playing will.

## FAQ

**Will this actually keep me green on Slack?**
It resets the macOS idle timer (measured: 142s → 0s), which is what the Slack and Teams desktop apps go by. We have not measured your manager.

**Is this a good idea?**
It's a mouse jiggler in a costume. Your company's endpoint software may have opinions about synthetic input. Or book the day off like an adult.

**It says there are 20 days to go.**
That's the feature. Do real work now so you can afford the special edition.

**Rockstar delayed it again.**
Edit `LAUNCH =` at the top of `SKILL.md`. Then go outside.

**How do I uninstall it?**
`/plugin uninstall gta-6@wonkylamp`, or delete the folder.

**How do I regenerate the GIF?**
`vhs assets/demo.tape`

## License

[MIT](LICENSE). Fan-made parody; not affiliated with Rockstar Games or Take-Two Interactive. No game assets were used.
