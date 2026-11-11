#!/usr/bin/env python3
"""The code witness: for every BASIC program the Godot port has taken the
rules of, which of the program's lines a rule cites, which of them a
recording ever ran, and which lines that do something to the game no
rule cites at all.

The port's rules are held to the real game's behaviour by replaying
recordings (godot-remake/tests/check_*_rules.gd). That is a witness from
the interface. This is the witness from the code: the listing, line by
line (from analysis/basic_callmap.json, itself built from the tokenized
programs), against what the port says it follows.

A rule says what it follows with a tag in a comment, anywhere under
godot-remake/scripts:

    ## @witness SHORE LEAVE 2087-2098, 2090

(the program's name as the call map spells it, then lines and ranges of
lines). A program is in scope once any file cites it.

Every line of an in-scope program is put in one of:

  logic         changes something the game keeps (a POKE of a game byte,
                a PEEK of one, MISC FILE's variables, RND, a CALL) or
                decides something (IF, ON..GOTO, GET)
  presentation  everything else: PRINT, HTAB, VTAB, SPEED=, drawing,
                the delay loops, the text window and character switches
  waived        named in analysis/witness/manifest.json with a reason

and the ledger, analysis/witness/<PROGRAM>.md, says for each line who
cites it and how many recordings ran it. It fails (exit 1) for

  - a cited line that is not in the program,
  - a logic line that no rule cites and no waiver excuses,
  - a CALL into machine code that no rule cites by address
    (@witness-asm 38825 ...).

and reports, without failing, the cited lines no recording ever ran: the
rules there rest on the listing alone.

Usage: tools/witness.py [--check] [PROGRAM ...]
    --check  write nothing; exit 1 if a ledger differs from what is on disk
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "analysis", "witness")
SCRIPTS = os.path.join(ROOT, "godot-remake", "scripts")

TAG = re.compile(r"@witness\s+([A-Z][A-Z0-9 ._#]*?)\s+([0-9][0-9, \-]*)$")
TAG_ASM = re.compile(r"@witness-asm\s+([0-9][0-9, ]*)")

GAME_BYTES = re.compile(r"(PEEK\s*\(\s*|POKE\s+)(2[0-9]{4}|3[0-9]{4})\b")
MISC = re.compile(r"\b(CR|TR|SD)\s*=")
LOGIC = [GAME_BYTES, MISC, re.compile(r"\bRND\b"), re.compile(r"\bCALL\b"), re.compile(r"\bIF\b"),
         re.compile(r"\bON\b.*\bGOTO\b"), re.compile(r"\bGET\b"), re.compile(r"\bRUN\b"),
         re.compile(r"\b(CR|TR|SD)\b")]


def strip_strings(text):
    return re.sub(r'"[^"]*"', '""', text)


def spans(spec):
    """[(first, last)] of "2087-2098, 2090"."""
    out = []
    for part in spec.split(","):
        part = part.strip()
        if part:
            a, _, b = part.partition("-")
            out.append((int(a), int(b or a)))
    return out


def cited():
    """{program: [(first, last, file:line)]}, {call address: [file:line]}"""
    programs, asm = {}, {}
    for path in sorted(glob.glob(os.path.join(SCRIPTS, "**", "*.gd"), recursive=True)):
        rel = os.path.relpath(path, ROOT)
        with open(path) as f:
            for n, text in enumerate(f, 1):
                text = text.rstrip()
                m = TAG_ASM.search(text)
                if m:
                    for a, _ in spans(m.group(1)):
                        asm.setdefault(a, []).append("%s:%d" % (rel, n))
                    continue
                m = TAG.search(text)
                if m:
                    for a, b in spans(m.group(2)):
                        programs.setdefault(m.group(1), []).append((a, b, "%s:%d" % (rel, n)))
    return programs, asm


def executed(name, spec):
    """{line: number of recordings that ran it} for one program."""
    seen = {}
    for pattern in spec["logs"]:
        for path in sorted(glob.glob(os.path.join(ROOT, pattern))):
            lines = set()
            inside = "after_get" not in spec and "ran" not in spec
            after_key = False
            with open(path) as f:
                for text in f:
                    if "-- ran " in text:
                        word = text.split("-- ran ", 1)[1].split()[0]
                        inside = word == spec.get("ran")
                        continue
                    if "after_get" in spec:
                        m = re.search(r"-- get (\S+)", text)
                        if m:
                            if m.group(1) == spec["until_get"]:
                                inside = False
                            if m.group(1) == spec["after_get"]:
                                after_key = True
                            continue
                        if after_key and "-- key" in text:
                            inside, after_key = True, False
                            continue
                    if inside:
                        m = re.match(r"\S+ \[\d+\] line (\d+)\s", text)
                        if m:
                            lines.add(int(m.group(1)))
                        m = re.match(r"\S+ \[\d+\] -- (?:at|get) \S+ .*?\bline=(\d+)", text)
                        if m:
                            lines.add(int(m.group(1)))
            for line in lines:
                seen[line] = seen.get(line, 0) + 1
    return seen


def classify(text):
    code = strip_strings(text)
    code = re.sub(r"\bDATA\b.*", "", code)
    return "logic" if any(p.search(code) for p in LOGIC) else "presentation"


def ledger(name, entry, tags, asm_cites, manifest):
    listing = {int(k): v for k, v in entry["listing"].items()}
    # a range cites the lines of the program inside it; a lone number must be one
    citations = {}
    problems = []
    for a, b, where in tags:
        inside = [n for n in listing if a <= n <= b]
        if not inside:
            problems.append("lines %d-%d are cited (%s) and the program has none there" % (a, b, where))
        if a == b and a not in listing:
            continue
        for n in inside:
            citations.setdefault(n, []).append(where)
    waive = dict(manifest["waive"].get("_all", {}))
    waive.update(manifest["waive"].get(name, {}))
    spec = manifest["recordings"].get(name)
    ran = executed(name, spec) if spec else {}
    unran = []
    rows = []
    for number in sorted(listing):
        kind = classify(listing[number])
        who = citations.get(number, [])
        if str(number) in waive:
            kind = "waived"
        if kind == "logic" and not who:
            problems.append("line %d is logic and no rule cites it: %s" % (number, listing[number][:70]))
        if who and number not in ran and spec:
            unran.append(number)
        rows.append((number, kind, who, ran.get(number, 0), listing[number]))
    for call in entry["calls"]:
        address = call["addr"] if "addr" in call else call.get("target")
        if address not in asm_cites:
            problems.append("line %s CALLs %s into machine code and no rule cites that address" % (call["line"], address))
    out = ["# %s: the code witness" % name, "",
           "Written by `tools/witness.py`; do not edit. Rules cite lines with `@witness` tags under",
           "`godot-remake/scripts`; recordings are listed in `analysis/witness/manifest.json`.", ""]
    count = {k: sum(1 for r in rows if r[1] == k) for k in ("logic", "presentation", "waived")}
    out.append("%d lines: %d logic, %d presentation, %d waived. %d lines cited by a rule; %d of them never run in a recording."
               % (len(rows), count["logic"], count["presentation"], count["waived"],
                  sum(1 for r in rows if r[2]), len(unran)))
    out.append("Machine-code calls: %s." % (", ".join("line %s -> %s" % (c["line"], c.get("addr", c.get("target")))
                                                      for c in entry["calls"]) or "none"))
    if spec is None:
        out.append("No recordings are listed for this program.")
    out += ["", "## Problems", ""] + (["- " + p for p in problems] or ["none"])
    out += ["", "## Cited, and never run in a recording (the listing alone)", "",
            ", ".join(map(str, unran)) or "none", "", "## Every line", "",
            "| line | | cited by | runs | listing |", "|---|---|---|---|---|"]
    for number, kind, who, runs, text in rows:
        out.append("| %d | %s | %s | %s | `%s` |" % (number, kind[0].upper(), "<br>".join(sorted(set(who))) or "", runs or "",
                                                     text.replace("|", "\\|")[:90]))
    return "\n".join(out) + "\n", problems, unran, sum(1 for r in rows if r[2])


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    callmap = json.load(open(os.path.join(ROOT, "analysis", "basic_callmap.json")))["files"]
    manifest = json.load(open(os.path.join(OUT, "manifest.json")))
    citations, asm_cites = cited()
    failed = 0
    for name in sorted(citations):
        if args and name not in args:
            continue
        if name not in callmap:
            print("FAIL  %s: not a program in the call map" % name)
            failed += 1
            continue
        text, problems, unran, cited_count = ledger(name, callmap[name], citations[name], asm_cites, manifest)
        path = os.path.join(OUT, name.replace(" ", "_") + ".md")
        if check:
            if not os.path.exists(path) or open(path).read() != text:
                print("FAIL  %s: the ledger on disk is not what the listing, the tags and the recordings give" % name)
                failed += 1
        else:
            with open(path, "w") as f:
                f.write(text)
        for p in problems:
            print("FAIL  %s: %s" % (name, p))
        failed += len(problems)
        print("%s  %-14s %3d lines cited, %d never run in a recording" % ("PASS" if not problems else "FAIL", name,
                                                                         cited_count, len(unran)))
    print("witness: %d problems" % failed)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
