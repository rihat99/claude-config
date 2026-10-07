#!/usr/bin/env python3
"""Write ~/.claude/settings.json and ~/.claude/agents/*.md from this repo.

claude/models.json is the single place where model versions live:
  fable / opus / sonnet   {"id": exact model id, "effort": low|medium|high|xhigh|max}
  session                 alias the main session starts on: opus, opus[1m], fable, sonnet
  subagents               alias a subagent gets when nothing else picks its model

settings.json = the existing ~/.claude/settings.json with every key from
claude/settings.json (+ claude/settings.macos.json on a Mac) and the model keys derived
from models.json written over it. Keys the repo does not define (hooks from the
autoresearch installer, choices Claude Code saves at runtime) stay as they are, except the
RETIRED_* keys below; "env" and "modelSettings" are merged per entry. The previous file is kept in the home trash
(~/.trash, on macOS the Finder Trash) with a timestamp. A file that is not valid JSON stops the run instead of being overwritten.

agents = claude/agents/*.md with {{opus.effort}}, {{sonnet.effort}}, {{fable.effort}}
(and {{<tier>.id}}, {{session.effort}} = effort of the "session" tier) filled in, written as plain files. They replace whatever is in
~/.claude/agents under the same name, including the mars_* files the autoresearch
installer copies there, so run this after that installer.
"""
import json
import os
import platform
import re
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CL = os.path.expanduser("~/.claude")
TIERS = ("fable", "opus", "sonnet")
# keys the repo once set and later dropped: removed from the live file (everything else it does not define is kept)
RETIRED_KEYS = ("skipDangerousModePermissionPrompt",)
RETIRED_ENV = ("CLAUDE_AFK_TIMEOUT_MS",)
EFFORTS = ("low", "medium", "high", "xhigh")  # max is per session only, not a tier default


def tier_of(alias, models):
    """'opus[1m]' -> 'opus'; exits on an alias that is not a tier."""
    base = re.sub(r"\[.*\]$", "", alias)
    if base not in TIERS:
        sys.exit("models.json: %r is not one of %s" % (alias, "/".join(TIERS)))
    return base


def render_settings(models):
    repo = json.load(open(os.path.join(REPO, "claude", "settings.json")))
    overlay = os.path.join(REPO, "claude", "settings.macos.json")
    if platform.system() == "Darwin" and os.path.isfile(overlay):
        repo.update(json.load(open(overlay)))
    repo["model"] = models["session"]
    repo["effortLevel"] = models[tier_of(models["session"], models)]["effort"]
    tier_of(models["subagents"], models)
    repo_env = repo.setdefault("env", {})
    for t in TIERS:
        repo_env["ANTHROPIC_DEFAULT_%s_MODEL" % t.upper()] = models[t]["id"]
    repo_env["CLAUDE_CODE_SUBAGENT_MODEL"] = models["subagents"]
    repo_models = {models[t]["id"]: {"effortLevel": models[t]["effort"]} for t in TIERS}

    dst = os.path.join(CL, "settings.json")
    old = {}
    if os.path.isfile(dst):
        try:
            old = json.load(open(dst))
        except ValueError as e:
            sys.exit("%s is not valid JSON (%s); fix or move it first, nothing was written" % (dst, e))
    new = dict(old)
    for k in RETIRED_KEYS:
        new.pop(k, None)
    new.update(repo)
    new["env"] = dict(old.get("env", {}), **repo_env)
    for k in RETIRED_ENV:
        new["env"].pop(k, None)
    new["modelSettings"] = dict(old.get("modelSettings", {}))
    for model_id, entry in repo_models.items():
        new["modelSettings"][model_id] = dict(new["modelSettings"].get(model_id, {}), **entry)
    if old == new:
        print("    settings.json unchanged")
        return
    if old:
        trash = os.path.expanduser("~/.trash")  # on macOS the Finder Trash
        os.makedirs(trash, exist_ok=True)
        bak = os.path.join(trash, "settings.json.%s" % time.strftime("%Y%m%d-%H%M%S"))
        with open(bak, "w") as f:
            json.dump(old, f, indent=2)
    tmp = dst + ".tmp"
    with open(tmp, "w") as f:
        json.dump(new, f, indent=2)
        f.write("\n")
    os.replace(tmp, dst)  # a session that reads the file meanwhile sees either version, never a half
    print("    wrote %s" % dst)


def render_agents(models):
    src_dir = os.path.join(REPO, "claude", "agents")
    dst_dir = os.path.join(CL, "agents")
    os.makedirs(dst_dir, exist_ok=True)
    values = {}
    for t in TIERS:
        values[t + ".effort"] = models[t]["effort"]
        values[t + ".id"] = models[t]["id"]
    # for agents with `model: inherit`: the effort of the tier the default session runs on
    values["session.effort"] = models[tier_of(models["session"], models)]["effort"]

    changed = []
    for name in sorted(os.listdir(src_dir)):
        if not name.endswith(".md"):
            continue
        text = open(os.path.join(src_dir, name)).read()

        def fill(m):
            key = m.group(1)
            if key not in values:
                sys.exit("agents/%s: unknown placeholder {{%s}}" % (name, key))
            return values[key]

        text = re.sub(r"\{\{([a-z]+\.[a-z]+)\}\}", fill, text)
        dst = os.path.join(dst_dir, name)
        if os.path.islink(dst):
            os.remove(dst)
        if os.path.isfile(dst) and open(dst).read() == text:
            continue
        with open(dst, "w") as f:
            f.write(text)
        changed.append(name[:-3])
    print("    agents %s" % (("rendered: " + " ".join(changed)) if changed else "unchanged"))


def main():
    models = json.load(open(os.path.join(REPO, "claude", "models.json")))
    for t in TIERS:
        if t not in models or "id" not in models[t] or models[t].get("effort") not in EFFORTS:
            sys.exit("models.json: %s needs an id and an effort in %s" % (t, "/".join(EFFORTS)))
    render_settings(models)
    render_agents(models)


if __name__ == "__main__":
    main()
