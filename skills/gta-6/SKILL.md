---
name: gta-6
description: GTA VI launch-day cover. Keeps your Mac awake and Slack green, scrolls a fake deploy, drafts your alibi. `/gta-6 stop` clocks you out.
license: MIT
disable-model-invocation: true
argument-hint: "[stop | force]"
---

# /gta-6

LAUNCH = 2026-11-19 (PS5 / Xbox Series X|S). Rockstar has slipped it twice; if it slips again, edit this line.

GTA VI is console-only, so the Mac is free to put on a show while the user plays. `busy.command` and `.started` live in this skill's directory, next to this file.

## Argument `stop`

1. Run `pkill -f gta-6/busy.command`. Its `caffeinate` exits with it.
2. Read `.started` (epoch seconds) and report the hours played as a GTA mission-complete screen: `MISSION PASSED`, `RESPECT +`, and one deadpan line about how productive the day looked from the outside.

## Otherwise

1. **Gate.** Compare today with LAUNCH.
   - Before LAUNCH and the argument is not `force`: reply with the countdown in days and a one-line roast telling the user to do real work while it still counts. Stop here.
   - On or after LAUNCH: go on. More than a week after, open by noting this is now a lifestyle.
2. **Cover.** The cover needs macOS. If `uname` is not `Darwin`, say so, skip to the alibi, and invite a PR for their OS. On macOS run `open -a Terminal <this skill's directory>/busy.command`. It opens a Terminal window that scrolls a convincing build, test, and deploy log forever, keeps the display awake, and nudges the cursor 1px every 4 minutes so Slack and Teams show active. The service names and test cases hide GTA references for anyone who reads closely. Tell the user to leave the window frontmost.
3. **Alibi.** Write these fresh each run, plausible to a coworker skimming and dull enough that nobody asks a follow-up:
   - Slack status: emoji, text, and a clear-after time.
   - A calendar block title for the afternoon.
   - Tomorrow's standup line: vague, impressive, unfalsifiable.

   Hand them over as text for the user to paste themselves.
4. Close with a mission-briefing card: objective, cover status, and "`/gta-6 stop` to clock out."
