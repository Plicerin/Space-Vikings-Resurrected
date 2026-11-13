#!/usr/bin/env python3
"""Independent checks on tools/basic_callmap.py, plus concrete execution
of the keyboard-dispatch blocks.

Part 1 re-counts things a second way (regexes over the text listings in
detokenized/, raw byte scans) and compares with what the mapper found.
Part 2 runs a block of real program lines through a small Applesoft
interpreter once per possible key, so "what does key X do" is computed
rather than traced by eye.

Usage: tools/verify_callmap.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import basic_callmap as cm

DETOK = os.path.join(cm.ROOT, "detokenized")
failures = []


def check(label, ok, detail=""):
    print("%s  %s%s" % ("PASS" if ok else "FAIL", label, "  " + detail if detail else ""))
    if not ok:
        failures.append(label)


def raw(name):
    with open(os.path.join(cm.EXTRACTED, name + ".bas"), "rb") as f:
        return f.read()


# --------------------------------------------------------------------------
# Part 1: census checks
# --------------------------------------------------------------------------

def blank(line):
    """Listing line with strings, REM tails and DATA lists removed."""
    line = re.sub(r'"[^"]*("|$)', '""', line)
    line = re.sub(r" REM .*$", "", line)
    return re.sub(r" DATA [^:]*", " ", line)


def census():
    from extract_files import TOKENS as other_tokens
    check("token table matches tools/extract_files.py", cm.TOKENS == other_tokens)

    model, _ = cm.build()
    names = sorted(model["files"])
    bad_rt, bad_jump, bad_mem, bad_dos = [], [], [], []
    tot = {"jumps": 0, "peek": 0, "poke": 0, "call": 0, "ctrl_d": 0}
    for name in names:
        info = model["files"][name]
        with open(os.path.join(DETOK, name + ".bas"), encoding="utf-8") as f:
            listing = f.read().split("\n")
        mine = ["%d %s" % (num, cm.detok(body)) for num, body in cm.read_lines(raw(name))]
        if mine != listing:
            bad_rt.append(name)

        text = [blank(l) for l in listing]
        n_targets = 0
        for l in text:
            for m in re.finditer(r" (?:GOTO|GOSUB) +(\d+(?: *, *\d+)*)", l):
                n_targets += len(m.group(1).split(","))
            n_targets += len(re.findall(r" THEN +\d", l))
        found = len(info["jumps"]) + len(info["undefined_targets"])
        tot["jumps"] += n_targets
        if n_targets != found:
            bad_jump.append("%s text=%d map=%d" % (name, n_targets, found))

        counts = {k: sum(len(re.findall(" %s " % k, l)) for l in text)
                  for k in ("PEEK", "POKE", "CALL")}
        got = {"PEEK": sum(m["op"] == "PEEK" for m in info["mem"]),
               "POKE": sum(m["op"] == "POKE" for m in info["mem"]),
               "CALL": len(info["calls"])}
        for k in counts:
            tot[k.lower()] += counts[k]
        if counts != got:
            bad_mem.append("%s text=%s map=%s" % (name, counts, got))

        # every Ctrl-D byte in the file is either a DOS command the mapper
        # reported or the definition of a D$-style variable
        n_ctrl_d = sum(body.count(b"\x04") for _, body in cm.read_lines(raw(name)))
        literal = sum(1 for d in info["dos"]) - sum(
            1 for nd in cm.program(raw(name))[0]
            if nd["kind"] == "PRINT" and not any(k == "str" and b"\x04" in v for k, v in nd["items"])
            and any(k == "id" and cm.varkey(v) in info["ctrl_d_vars"] for k, v in nd["items"]))
        defs = sum(1 for nd in cm.program(raw(name))[0]
                   if nd["kind"] == "LET" and nd.get("var") in info["ctrl_d_vars"]
                   and any(k == "str" and b"\x04" in v for k, v in nd["items"]))
        tot["ctrl_d"] += n_ctrl_d
        if n_ctrl_d != literal + defs:
            bad_dos.append("%s bytes=%d literal=%d defs=%d" % (name, n_ctrl_d, literal, defs))

    check("listing round-trips against detokenized/ (%d programs)" % len(names),
          not bad_rt, ", ".join(bad_rt))
    check("branch targets: text census = map (%d)" % tot["jumps"], not bad_jump, "; ".join(bad_jump))
    check("PEEK/POKE/CALL: text census = map (%d/%d/%d)" % (tot["peek"], tot["poke"], tot["call"]),
          not bad_mem, "; ".join(bad_mem))
    check("every Ctrl-D byte accounted for (%d)" % tot["ctrl_d"], not bad_dos, "; ".join(bad_dos))
    return model


# --------------------------------------------------------------------------
# Part 2: concrete execution
# --------------------------------------------------------------------------

class Stop(Exception):
    pass


class Machine:
    """Just enough Applesoft to run straight-line dispatch code: numeric
    scalars, IF, GOTO, GOSUB/RETURN, ON, POKE, PEEK, CALL, PRINT.  It
    stops (and says why) at anything else rather than guessing."""

    def __init__(self, name, mem=None, variables=None):
        self.nodes, self.first, self.next_line = cm.program(raw(name))
        self.mem = dict(mem or {})
        self.vars = dict(variables or {})
        self.events, self.stack, self.trace = [], [], []

    def ev(self, ast):
        k = ast[0]
        if k == "num":
            return ast[1]
        if k == "var":
            return self.vars.get(ast[1], 0)
        if k == "un":
            v = self.ev(ast[2])
            return -v if ast[1] == "-" else (0 if v else 1)
        if k == "bin":
            a, b = self.ev(ast[2]), self.ev(ast[3])
            op = ast[1]
            if op in ("+", "-", "*", "/"):
                return a + b if op == "+" else a - b if op == "-" else a * b if op == "*" else a / b
            if op == "AND":
                return 1 if a and b else 0
            if op == "OR":
                return 1 if a or b else 0
            return 1 if {"<": a < b, ">": a > b, "=": a == b, "<>": a != b,
                         "<=": a <= b, ">=": a >= b}[op] else 0
        if k == "fn" and ast[1] == "PEEK":
            addr = int(self.ev(ast[2][0])) % 65536
            if addr not in self.mem:
                raise Stop("PEEK(%d) has no value supplied" % addr)
            return self.mem[addr]
        if k == "fn" and ast[1] == "INT":
            return int(self.ev(ast[2][0]) // 1)
        raise Stop("cannot evaluate %s" % cm.fmt(ast))

    def goto(self, line):
        if line not in self.first:
            raise Stop("UNDEF'D STATEMENT %d" % line)
        return self.first[line]

    def run(self, start_line, stop_lines=(), max_steps=200):
        pc = self.first[start_line]
        try:
            for _ in range(max_steps):
                nd = self.nodes[pc]
                kind = nd["kind"]
                if nd["line"] in stop_lines:
                    raise Stop("back at line %d" % nd["line"])
                if not self.trace or self.trace[-1] != nd["line"]:
                    self.trace.append(nd["line"])
                nxt = pc + 1
                if kind == "IF":
                    if not self.ev(cm.parse_expr(nd["cond"])):
                        nxt = self.next_line.get(nd["line"])
                elif kind == "LET" and "var" in nd:
                    self.vars[nd["var"]] = self.ev(cm.parse_expr(nd["rhs"]))
                elif kind == "GOTO":
                    nxt = self.goto(nd["targets"][0])
                elif kind == "GOSUB":
                    self.stack.append(pc + 1)
                    nxt = self.goto(nd["targets"][0])
                elif kind in ("ONGOTO", "ONGOSUB"):
                    v = int(self.ev(cm.parse_expr(nd["expr"])))
                    if v < 0:
                        raise Stop("ILLEGAL QUANTITY in ON (%d)" % v)
                    if 1 <= v <= len(nd["targets"]):
                        if kind == "ONGOSUB":
                            self.stack.append(pc + 1)
                        nxt = self.goto(nd["targets"][v - 1])
                elif kind == "RETURN":
                    if not self.stack:
                        raise Stop("RETURN without GOSUB")
                    nxt = self.stack.pop()
                elif kind == "POKE":
                    a = int(self.ev(cm.parse_expr(nd["addr_items"]))) % 65536
                    v = self.ev(cm.parse_expr(nd["value_items"]))
                    self.mem[a] = v
                    self.events.append("POKE %d,%s" % (a, ("%g" % v)))
                elif kind == "CALL":
                    self.events.append("CALL %d" % self.ev(cm.parse_expr(nd["addr_items"])))
                elif kind == "PRINT" and "dos" in nd or kind == "PRINT" and cm.dos_command(nd, set()):
                    d = cm.dos_command(nd, set())
                    self.events.append("DOS %s %s" % (d["verb"], d["name"]))
                    if d["verb"] == "RUN":
                        raise Stop("program replaced")
                else:
                    raise Stop("reached %s at line %d" % (kind, nd["line"]))
                if nxt is None:
                    raise Stop("end of program")
                pc = nxt
            raise Stop("step limit")
        except Stop as e:
            self.stop = str(e)
        return self


def key_table(model, name, start_line, stop_lines=(), kbd=49152, variables=None, label=""):
    """Run the block once per key code the keyboard latch can hold.
    Variables start from the program's own constants (the mapper's list),
    as they would after its initialisation lines have run."""
    print("\n%s line %d, one run per key%s" % (name, start_line, label))
    groups = {}
    start = dict(model["files"][name]["constants"], **(variables or {}))
    for code in range(128, 256):
        m = Machine(name, mem={kbd: code}, variables=start).run(start_line, stop_lines)
        # speed changes show up as the final POKE value; keep them readable
        key = (tuple(m.events), m.stop, tuple(m.trace))
        groups.setdefault(key, []).append(code)
    rows = []
    for (events, stop, trace), codes in groups.items():
        keys = "".join(chr(c - 128) if 33 <= c - 128 < 127 else "" for c in codes)
        others = sum(1 for c in codes if not 33 <= c - 128 < 127)
        rows.append((codes[0], keys, others, events, stop, trace))
    for _, keys, others, events, stop, trace in sorted(rows):
        who = (keys if len(keys) <= 12 else "%s…%s (%d keys)" % (keys[:4], keys[-2:], len(keys)))
        if others:
            who += " +%d control/space codes" % others
        print("  %-34s %s  -> %s" % (who, "; ".join(events) or "(nothing)", stop))
        print("  %-34s lines %s" % ("", " ".join(map(str, trace))))
    return groups


def main():
    model = census()
    # speed S starts mid-range so the clamps at 207/208 stay out of the way;
    # line 1 is the flight program's re-initialisation, reached by GOTO 1
    g = key_table(model, "STARSHIP SIMULATOR", 200, stop_lines=(1,),
                  variables={"S": 60}, label=" (S=60 on entry)")
    h = [ev for (ev, stop, tr), codes in g.items() if 200 in codes]
    check("STARSHIP SIMULATOR: 'H' reaches line 209 and issues RUN H/D",
          h and "DOS RUN H/D" in h[0], str(h))
    print()
    if failures:
        print("%d check(s) failed: %s" % (len(failures), "; ".join(failures)))
        return 1
    print("all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
