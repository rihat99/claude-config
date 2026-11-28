---
name: self-compact
description: Compact this session's own context without the user typing /compact. Use when the user asks you to compact yourself, compact the conversation, shrink or free up your context, or "compact and continue", and when another skill's protocol says to self-issue a compact (autoresearch does). Works when Claude Code runs inside tmux or as a background session; anywhere else it produces the ready /compact line for the user to paste. Not for subagents, and not something to start on your own because the context is large.
---

# Self-compact

`/compact <message>` typed into the session's terminal starts a compaction, and the message tells the summarizer what to keep. You cannot type into your own terminal, so you queue the line in a file and end your reply; a Stop hook then types it for you.

## Steps

1. **Reach a clean point.** Finish the step you are in. Anything that must survive exactly (a number, a path, a decision, how to watch a running job) goes into a file first: the project's notes folder, or the place the invoking skill names. The summary keeps the narrative; files keep the facts.
2. **Write the compact message** by the rules below. If the user said what to keep, their words lead.
3. **Queue it:**
   ```bash
   python3 ~/.claude/skills/self-compact/scripts/request_compact.py "/compact <message>"
   python3 ~/.claude/skills/self-compact/scripts/request_compact.py "/compact <message>" --then "<follow-up>"
   ```
   Pass `--then` only when work remains and you should carry on by yourself after the compact; the text is typed as the next user message, for example `--then "continue with the evaluation script"`. When the user only asked for a compact, leave it out and the session waits for them.
4. **End your reply at once** with one line saying the compact is queued. No further tool calls: the hook fires when the turn ends, and a request older than 10 minutes is dropped.
5. **If the script refuses** because the session is neither in tmux nor a background session, give the user the line in a code block to paste, and stop:
   ```
   /compact <message>
   ```

After the compact, read the files you wrote in step 1 before trusting your memory of the conversation.

## The compact message

One or two sentences, strictly high-level. The compaction keeps details by itself; the message only says which topics matter.

1. Name the layers of context, not only the current subtask: the project and its goal, the part being worked on, the conclusions reached so far, the current task and its state.
2. Point to files instead of restating them: notes, plans and reports hold the details.
3. No implementation details: no flags, values, `file:line` references, configs or code.
4. If it does not fit in two sentences it is too detailed. Go up a level; do not enumerate. The script refuses a line over 800 characters.

Good:

> Keep the overall project context (dyn_gghead GAN generator being adapted to TexAvatars' texel-Gaussian overfitting harness, the architectures involved, and what we're trying to achieve), the batch-2 conclusions, and the agreed batch-3 plan with my in-progress implementation of its training knobs.

Bad, too detailed:

> Keep the batch-3 spec (C1 B4+all-6e-4+eps1e-15+undo lr_mult = boost mapping fc0/fc1 group lr ×100 ...), the file map (`gancnn/generator.py` predict_raw stashes `_ws_syn` ...), and the smoke checklist ...

## How it works

- `scripts/request_compact.py` writes `~/.claude/self-compact/compact_request_<key>.json`. The key is the tmux pane (`$TMUX_PANE`) or, for a background session (`claude --bg`), the job (`$CLAUDE_JOB_DIR`), so sessions never pick up each other's requests and any shell cwd works.
- `hooks/deliver.py` runs on Stop, takes this session's request and starts `scripts/tmux_deliver.py` detached.
- `scripts/tmux_deliver.py` waits until the screen shows no spinner, types the line in 200-character pieces (one big write is taken for a paste, and a pasted `/compact` is sent to the model as plain text), then sends Enter as a separate key. Two seconds later it types the `--then` text; Claude Code queues input typed during a compaction and runs it as the next turn. A background session is reached through `claude attach <job>` in a scratch window of the tmux session `self_compact`, which is closed afterwards.
- Log: `~/.claude/self-compact/deliver.log`. A failed delivery is recorded there with the line that was not typed.
- Only `/compact` and `/clear` lines are accepted, and the follow-up may not start with `/`.

The Stop hook is registered in `~/dotfiles/claude/settings.json` and installed by `install.sh`. `bash ~/dotfiles/tests/verify_self_compact.sh` checks the chain end to end, including a real tmux pane.

Subagents never compact: a subagent that outgrows its context writes its findings to a file and returns.
