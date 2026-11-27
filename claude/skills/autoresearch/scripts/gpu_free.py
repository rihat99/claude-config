#!/usr/bin/env python3
"""Which GPUs are safe to take, based on a sampling window.

Samples nvidia-smi every --interval s for --window s (up to --confirm s when a
GPU with processes looks practically free), averages utilization and
VRAM per GPU, lists compute processes with owners and ages, and classifies
each GPU:

  FREE                        no util, no VRAM, no compute processes
  PRACTICALLY_FREE            processes present, but avg util <= --share-util
                              (default 25%), all of them older than --min-age,
                              and >= --need-gb VRAM left
  PRACTICALLY_FREE_NO_VRAM    same, but less than --need-gb VRAM left
  BUSY                        heavier use, or processes too young to tell from a
                              job still warming up

PRACTICALLY_FREE always comes with the GPU's avg util (we would share the GPU
with that load). FREE and PRACTICALLY_FREE are both OK to take; FREE ones are
recommended first, then PRACTICALLY_FREE by ascending util. The --confirm
phase runs only when fewer than --top GPUs are FREE: with enough FREE ones the
script returns right after --window and marks shared GPUs "unconfirmed".
Prints a table plus a CUDA_VISIBLE_DEVICES recommendation; --json for agents.
Exit code 0 if at least one usable GPU, else 1. Indices are nvidia-smi (PCI)
order — export CUDA_DEVICE_ORDER=PCI_BUS_ID so CUDA numbering matches.
"""
import argparse
import json
import subprocess
import sys
import time
from collections import defaultdict


def smi(query, fields):
    cmd = ["nvidia-smi", "--query-%s=%s" % (query, ",".join(fields)),
           "--format=csv,noheader,nounits"]
    try:
        out = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             universal_newlines=True, timeout=20)
    except FileNotFoundError:
        sys.exit("nvidia-smi not found — is this a GPU machine?")
    if out.returncode != 0:
        sys.exit("nvidia-smi failed: %s" % out.stderr.strip())
    return [[c.strip() for c in line.split(",")]
            for line in out.stdout.splitlines() if line.strip()]


def num(s):
    try:
        return float(s)
    except ValueError:
        return None  # "[N/A]" etc.


def sample(samples, meta, n, interval):
    for i in range(n):
        t0 = time.time()
        for r in smi("gpu", ["index", "uuid", "name", "utilization.gpu",
                             "memory.used", "memory.total"]):
            idx = int(r[0])
            meta[idx] = {"uuid": r[1], "name": r[2], "total_mb": num(r[5]) or 0.0}
            samples[idx].append((num(r[3]) or 0.0, num(r[4]) or 0.0))
        if i < n - 1:
            time.sleep(max(0.0, interval - (time.time() - t0)))


def processes(meta):
    by_uuid = {m["uuid"]: idx for idx, m in meta.items()}
    procs = defaultdict(list)
    for r in smi("compute-apps", ["gpu_uuid", "pid", "used_memory"]):
        if len(r) < 3 or r[0] not in by_uuid or num(r[1]) is None:
            continue
        procs[by_uuid[r[0]]].append({"pid": int(num(r[1])), "mem_mb": num(r[2])})

    pids = sorted({p["pid"] for pl in procs.values() for p in pl})
    users, ages = {}, {}
    if pids:
        out = subprocess.run(["ps", "-o", "pid=,user=", "-p", ",".join(map(str, pids))],
                             stdout=subprocess.PIPE, universal_newlines=True)
        for line in out.stdout.splitlines():
            parts = line.split(None, 1)
            if len(parts) == 2 and parts[0].isdigit():
                users[int(parts[0])] = parts[1].strip()
        out = subprocess.run(["ps", "-o", "pid=,etimes=", "-p", ",".join(map(str, pids))],
                             stdout=subprocess.PIPE, universal_newlines=True)
        for line in out.stdout.splitlines():
            parts = line.split()
            if len(parts) == 2 and parts[0].isdigit() and parts[1].isdigit():
                ages[int(parts[0])] = int(parts[1])
    for pl in procs.values():
        for p in pl:
            p["user"] = users.get(p["pid"], "?")
            p["age_min"] = round(ages[p["pid"]] / 60) if p["pid"] in ages else None
    return procs


def classify(samples, meta, procs, args):
    gpus = []
    for idx in sorted(samples):
        utils = [u for u, _ in samples[idx]]
        mems = [m for _, m in samples[idx]]
        total = meta[idx]["total_mb"]
        avg_util, peak_util = sum(utils) / len(utils), max(utils)
        avg_mem = sum(mems) / len(mems)
        plist = procs.get(idx, [])
        mem_floor = max(args.max_mem_frac * total, 1024.0)
        need_mb = args.need_gb * 1024 if args.need_gb is not None else total / 2
        old = plist and all(p["age_min"] is not None and p["age_min"] >= args.min_age
                            for p in plist)
        if not plist:
            status = ("FREE" if avg_util <= args.max_util and avg_mem <= mem_floor
                      else "BUSY")
        elif avg_util <= args.share_util and old:
            status = ("PRACTICALLY_FREE" if total - avg_mem >= need_mb
                      else "PRACTICALLY_FREE_NO_VRAM")
        else:
            status = "BUSY"
        gpus.append({"index": idx, "name": meta[idx]["name"],
                     "avg_util": round(avg_util, 1), "peak_util": round(peak_util, 1),
                     "avg_mem_mb": round(avg_mem), "total_mb": round(total),
                     "free_mb": round(total - avg_mem),
                     "procs": plist, "status": status})
    return gpus


def collect(args):
    samples, meta = defaultdict(list), {}
    sample(samples, meta, max(1, int(round(args.window / args.interval))), args.interval)
    procs = processes(meta)
    gpus = classify(samples, meta, procs, args)
    extra = int(round((args.confirm - args.window) / args.interval))
    shared = [g for g in gpus if g["status"].startswith("PRACTICALLY_FREE")]
    n_free = sum(g["status"] == "FREE" for g in gpus)
    if extra > 0 and shared and n_free < (args.top or 1):
        # a job pausing for validation, a checkpoint or a data stall looks idle
        # for 15 s; before sharing its GPU watch it for --confirm seconds in all.
        # Skipped when enough GPUs are FREE outright: the agent takes those now.
        sample(samples, meta, extra, args.interval)
        gpus = classify(samples, meta, processes(meta), args)
        shared = [g for g in gpus if g["status"].startswith("PRACTICALLY_FREE")]
        for g in shared:
            g["confirmed"] = True
    else:
        for g in shared:
            g["confirmed"] = extra <= 0 or not shared
    return gpus, len(samples[min(samples)]) if samples else 0


def label(g):
    if g["status"].startswith("PRACTICALLY_FREE"):
        return "%s (util %.0f%%%s)" % (g["status"], g["avg_util"],
                                       "" if g.get("confirmed") else ", unconfirmed")
    return g["status"]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--window", type=float, default=15.0, help="sampling window, s (default 15)")
    ap.add_argument("--confirm", type=float, default=60.0,
                    help="if a GPU with processes looks practically free after the window, keep "
                         "sampling up to this many seconds in all before trusting it (default 60)")
    ap.add_argument("--interval", type=float, default=1.0, help="sample period, s (default 1)")
    ap.add_argument("--max-util", type=float, default=5.0,
                    help="avg util %% at or below which a GPU counts as idle (default 5)")
    ap.add_argument("--max-mem-frac", type=float, default=0.05,
                    help="avg used-VRAM fraction counting as free (default 0.05, min 1 GiB)")
    ap.add_argument("--share-util", type=float, default=25.0,
                    help="max avg util %% of a GPU with processes for it to count as "
                         "practically free (default 25; up to 50 for light jobs)")
    ap.add_argument("--min-age", type=float, default=30.0,
                    help="min age, minutes, of every process on a GPU before it can "
                         "count as practically free (default 30)")
    ap.add_argument("--need-gb", type=float, default=None,
                    help="VRAM we need on a practically-free GPU (default: half of it)")
    ap.add_argument("--top", type=int, default=None,
                    help="GPUs the job needs: recommend at most N; when N are FREE outright the "
                         "script returns right after --window without confirming shared ones")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    args = ap.parse_args()

    gpus, nsamples = collect(args)
    if not gpus:
        sys.exit("no GPUs reported by nvidia-smi")

    rank = {"FREE": 0, "PRACTICALLY_FREE": 1}
    usable = sorted((g for g in gpus if g["status"] in rank and g.get("confirmed", True)),
                    key=lambda g: (rank[g["status"]], g["avg_util"], g["avg_mem_mb"]))
    free = [g["index"] for g in usable]
    rec = free[:args.top] if args.top else free

    if args.json:
        print(json.dumps({"window_s": nsamples * args.interval, "samples": nsamples, "gpus": gpus,
                          "usable": [{"index": g["index"], "status": g["status"],
                                      "avg_util": g["avg_util"], "free_mb": g["free_mb"]}
                                     for g in usable],
                          "recommended": ",".join(map(str, rec))}, indent=2))
    else:
        print("sampled %d snapshots over %.0fs" % (nsamples, nsamples * args.interval))
        hdr = "%3s  %-28s %9s %6s  %18s  %-30s %s"
        print(hdr % ("GPU", "name", "util avg", "peak", "VRAM avg (MiB)",
                     "procs (owners, youngest age)", "status"))
        for g in gpus:
            owners = sorted({p["user"] for p in g["procs"]})
            known = [p["age_min"] for p in g["procs"] if p["age_min"] is not None]
            age = " %dm" % min(known) if known else ""
            pstr = ("%d (%s%s)" % (len(g["procs"]), ",".join(owners), age)
                    if g["procs"] else "-")
            print(hdr % (g["index"], g["name"][:28], "%.1f%%" % g["avg_util"],
                         "%.0f%%" % g["peak_util"],
                         "%d/%d" % (g["avg_mem_mb"], g["total_mb"]), pstr, label(g)))
        if rec:
            print("\nusable: %s\n  ->  export CUDA_VISIBLE_DEVICES=%s"
                  % (", ".join("%d %s" % (g["index"], label(g)) for g in usable),
                     ",".join(map(str, rec))))
        else:
            print("\nno usable GPUs right now")
        if any(g["status"].startswith("PRACTICALLY_FREE") and not g.get("confirmed") for g in gpus):
            print("shared GPUs left unconfirmed: enough are FREE for --top %d; rerun with a larger "
                  "--top to confirm them (%.0fs)" % (args.top or 1, args.confirm))
    sys.exit(0 if free else 1)


if __name__ == "__main__":
    main()
