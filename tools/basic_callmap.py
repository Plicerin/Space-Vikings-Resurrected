#!/usr/bin/env python3
"""Call-level map of the Applesoft programs, built from the tokenized bytes.

Reads extracted/*.bas (raw DOS 3.3 Applesoft files, still tokenized) and
writes a machine-generated map of everything that transfers control or
passes data between routines, including the forms that are not spelled
as GOSUB/CALL:

  * DOS commands hidden behind a Ctrl-D byte in a PRINT string
    (RUN/BLOAD/BSAVE/OPEN/...), i.e. the cross-file scene graph
  * CALL sites with resolved addresses, the binary that owns the
    address, and the POKEs that precede the CALL on the same line
  * a per-address PEEK/POKE reader/writer table across all programs
  * the intra-file GOTO/GOSUB/ON/THEN graph, subroutine extents and
    statement-level reachability

This is a candidate-finder, not an oracle: it reports structure, never
meaning.  Anything it flags still needs to be read (or watched live in
MAME) before it is believed.

Usage: tools/basic_callmap.py            (writes analysis/basic_callmap.json
                                          and analysis/BASIC_CALL_MAP.md)
"""
import json
import os
import re
import struct
import sys
from collections import defaultdict, deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTRACTED = os.path.join(ROOT, "extracted")
OUT_JSON = os.path.join(ROOT, "analysis", "basic_callmap.json")
OUT_MD = os.path.join(ROOT, "analysis", "BASIC_CALL_MAP.md")

# Applesoft token table, 0x80-0xEA, in ROM order.
_TOKEN_NAMES = """END FOR NEXT DATA INPUT DEL DIM READ GR TEXT PR# IN# CALL PLOT
HLIN VLIN HGR2 HGR HCOLOR= HPLOT DRAW XDRAW HTAB HOME ROT= SCALE= SHLOAD
TRACE NOTRACE NORMAL INVERSE FLASH COLOR= POP VTAB HIMEM: LOMEM: ONERR
RESUME RECALL STORE SPEED= LET GOTO RUN IF RESTORE & GOSUB RETURN REM STOP
ON WAIT LOAD SAVE DEF POKE PRINT CONT LIST CLEAR GET NEW TAB( TO FN SPC(
THEN AT NOT STEP + - * / ^ AND OR > = < SGN INT ABS USR FRE SCRN( PDL POS
SQR RND LOG EXP COS SIN TAN ATN PEEK LEN STR$ VAL ASC CHR$ LEFT$ RIGHT$
MID$""".split()
TOKENS = {0x80 + i: name for i, name in enumerate(_TOKEN_NAMES)}
assert TOKENS[0xEA] == "MID$" and TOKENS[0xAB] == "GOTO" and TOKENS[0xE2] == "PEEK"

FUNCTIONS = {"SGN", "INT", "ABS", "USR", "FRE", "PDL", "POS", "SQR", "RND",
             "LOG", "EXP", "COS", "SIN", "TAN", "ATN", "PEEK", "LEN", "STR$",
             "VAL", "ASC", "CHR$", "LEFT$", "RIGHT$", "MID$"}
PAREN_TOKENS = {"TAB(", "SPC(", "SCRN("}

# DOS 3.3 command table, in the order DOS itself scans it.
DOS_VERBS = ["INIT", "LOAD", "SAVE", "RUN", "CHAIN", "DELETE", "LOCK",
             "UNLOCK", "CLOSE", "READ", "EXEC", "WRITE", "POSITION", "OPEN",
             "APPEND", "RENAME", "CATALOG", "MON", "NOMON", "PR#", "IN#",
             "MAXFILES", "FP", "INT", "BSAVE", "BLOAD", "BRUN", "VERIFY"]

# Standard Apple II locations (machine facts, not findings about this game).
KNOWN_ADDRS = {
    0xC000: "KBD (key waiting if >127)", 0xC010: "KBDSTRB (clear key)",
    0xC030: "SPKR (speaker click)", 0xC050: "TXTCLR (graphics)",
    0xC051: "TXTSET (text)", 0xC052: "MIXCLR (full screen)",
    0xC053: "MIXSET (mixed)", 0xC054: "LOWSCR (page 1)",
    0xC055: "HISCR (page 2)", 0xC056: "LORES", 0xC057: "HIRES",
    0xC061: "PB0 (button 0)", 0xC062: "PB1 (button 1)",
    0xC070: "PTRIG (paddle strobe)",
    32: "WNDLFT", 33: "WNDWDTH", 34: "WNDTOP", 35: "WNDBTM", 36: "CH",
    37: "CV", 54: "CSWL (output hook lo)", 55: "CSWH (output hook hi)",
    56: "KSWL (input hook lo)", 57: "KSWH (input hook hi)",
    216: "ERRFLG (ONERR active)", 222: "ERRNUM",
    228: "HCOLOR byte", 230: "HPAG (hi-res draw page)",
    232: "SHAPE table ptr lo", 233: "SHAPE table ptr hi",
}


# Two-byte pointers the firmware jumps or reads through.  POKEing both
# halves installs a routine or table without any CALL at the site.
VECTORS = {
    (54, 55): ("CSW", "every character PRINTed is passed to this routine"),
    (56, 57): ("KSW", "every key read (GET/INPUT) comes from this routine"),
    (232, 233): ("SHAPE", "DRAW/XDRAW take their shape table from here"),
    (1014, 1015): ("AMPERSAND", "the & statement jumps here"),
    (11, 12): ("USR", "USR() jumps here"),
    (1010, 1011): ("RESET", "Ctrl-Reset jumps here"),
}


def u16(b, i):
    return struct.unpack_from("<H", b, i)[0]


def text(b):
    return b.decode("latin-1").replace("\x04", "^D")


# --------------------------------------------------------------------------
# Tokenized program -> lines -> lexical items
# --------------------------------------------------------------------------

def read_lines(data):
    """[(line_number, body_bytes)] from a DOS 3.3 Applesoft file image."""
    prog = data[2:2 + u16(data, 0)]
    lines, i = [], 0
    while i + 4 <= len(prog) and u16(prog, i) != 0:
        num = u16(prog, i + 2)
        j = prog.index(0, i + 4)
        lines.append((num, prog[i + 4:j]))
        i = j + 1
    return lines


def detok(body):
    """Same rendering as tools/extract_files.py, for round-trip checks."""
    return "".join(" %s " % TOKENS[b] if b >= 0x80 else chr(b) for b in body).strip()


def lex(body):
    """Items: ('tok',name) ('id',name) ('num',text) ('str',bytes)
    ('raw',text) ('p',char)."""
    items, i, n = [], 0, len(body)
    while i < n:
        b = body[i]
        c = chr(b)
        if b >= 0x80:
            name = TOKENS[b]
            items.append(("tok", name))
            i += 1
            if name == "REM":
                items.append(("raw", text(body[i:])))
                break
            if name == "DATA":
                j, inq = i, False
                while j < n and (inq or body[j] != 0x3A):
                    if body[j] == 0x22:
                        inq = not inq
                    j += 1
                items.append(("raw", text(body[i:j])))
                i = j
        elif c == '"':
            j = body.find(b'"', i + 1)
            if j < 0:
                j = n
            items.append(("str", bytes(body[i + 1:j])))
            i = j + 1
        elif c.isalpha():
            j = i
            while j < n and body[j] < 0x80 and chr(body[j]).isalnum():
                j += 1
            if j < n and chr(body[j]) in "$%":
                j += 1
            items.append(("id", body[i:j].decode("ascii")))
            i = j
        elif c.isdigit() or c == ".":
            j = i
            while j < n and (chr(body[j]).isdigit() or chr(body[j]) == "."):
                j += 1
            items.append(("num", body[i:j].decode("ascii")))
            i = j
        elif c == " ":
            i += 1
        else:
            items.append(("p", c))
            i += 1
    return items


def show(items):
    """Compact readable rendering of an item list."""
    out = []
    for kind, v in items:
        if kind == "tok":
            out.append(v if v in "+-*/^=<>" or v.endswith("(") else " %s " % v)
        elif kind == "str":
            out.append('"%s"' % text(v))
        else:
            out.append(v)
    return re.sub(r"\s+", " ", "".join(out)).strip()


def varkey(name):
    """Applesoft only distinguishes the first two characters (+ type)."""
    suffix = name[-1] if name[-1] in "$%" else ""
    return name.rstrip("$%")[:2] + suffix


# --------------------------------------------------------------------------
# Expressions
# --------------------------------------------------------------------------

class ParseError(Exception):
    pass


class _Parser:
    """Applesoft precedence: ^, unary -, * /, + -, relational, NOT, AND, OR."""

    def __init__(self, items):
        self.items, self.i = items, 0

    def peek(self):
        return self.items[self.i] if self.i < len(self.items) else (None, None)

    def take(self, kind, value=None):
        k, v = self.peek()
        if k == kind and (value is None or v == value):
            self.i += 1
            return v
        raise ParseError("expected %s %s at %d in %s" % (kind, value, self.i, show(self.items)))

    def istok(self, *names):
        k, v = self.peek()
        return k == "tok" and v in names

    def or_(self):
        a = self.and_()
        while self.istok("OR"):
            self.i += 1
            a = ("bin", "OR", a, self.and_())
        return a

    def and_(self):
        a = self.not_()
        while self.istok("AND"):
            self.i += 1
            a = ("bin", "AND", a, self.not_())
        return a

    def not_(self):
        if self.istok("NOT"):
            self.i += 1
            return ("un", "NOT", self.not_())
        return self.rel()

    def rel(self):
        a = self.add()
        while self.istok("<", "=", ">"):
            ops = set()
            while self.istok("<", "=", ">"):
                ops.add(self.peek()[1])
                self.i += 1
            op = "".join(c for c in "<>=" if c in ops)
            a = ("bin", op, a, self.add())
        return a

    def add(self):
        a = self.mul()
        while self.istok("+", "-"):
            op = self.peek()[1]
            self.i += 1
            a = ("bin", op, a, self.mul())
        return a

    def mul(self):
        a = self.neg()
        while self.istok("*", "/"):
            op = self.peek()[1]
            self.i += 1
            a = ("bin", op, a, self.neg())
        return a

    def neg(self):
        if self.istok("-"):
            self.i += 1
            return ("un", "-", self.neg())
        if self.istok("+"):
            self.i += 1
            return self.neg()
        return self.pow()

    def pow(self):
        a = self.prim()
        while self.istok("^"):
            self.i += 1
            a = ("bin", "^", a, self.neg())
        return a

    def args(self):
        out = [self.or_()]
        while self.peek() == ("p", ","):
            self.i += 1
            out.append(self.or_())
        self.take("p", ")")
        return out

    def prim(self):
        k, v = self.peek()
        if k == "num":
            self.i += 1
            return ("num", float(v) if "." in v else int(v))
        if k == "str":
            self.i += 1
            return ("str", text(v))
        if (k, v) == ("p", "("):
            self.i += 1
            a = self.or_()
            self.take("p", ")")
            return a
        if k == "id":
            self.i += 1
            if self.peek() == ("p", "("):
                self.i += 1
                return ("idx", varkey(v), self.args())
            return ("var", varkey(v))
        if k == "tok" and v in FUNCTIONS:
            self.i += 1
            self.take("p", "(")
            return ("fn", v, self.args())
        if k == "tok" and v in PAREN_TOKENS:
            self.i += 1
            return ("fn", v.rstrip("("), self.args())
        if k == "tok" and v == "FN":
            self.i += 1
            name = self.take("id")
            self.take("p", "(")
            return ("fn", "FN " + name, self.args())
        raise ParseError("unexpected %r in %s" % ((k, v), show(self.items)))


def parse_expr(items):
    p = _Parser(items)
    ast = p.or_()
    if p.i != len(items):
        raise ParseError("trailing items in %s" % show(items))
    return ast


def fmt(ast):
    k = ast[0]
    if k == "num":
        return str(ast[1])
    if k == "str":
        return '"%s"' % ast[1]
    if k == "var":
        return ast[1]
    if k == "un":
        return ("NOT " if ast[1] == "NOT" else "-") + fmt(ast[2])
    if k == "bin":
        sp = " %s " if ast[1] in ("AND", "OR") else "%s"
        return "(%s%s%s)" % (fmt(ast[2]), sp % ast[1], fmt(ast[3]))
    if k == "idx":
        return "%s(%s)" % (ast[1], ",".join(fmt(a) for a in ast[2]))
    return "%s(%s)" % (ast[1], ",".join(fmt(a) for a in ast[2]))


def strip_parens(s):
    return s[1:-1] if s.startswith("(") and s.endswith(")") else s


def const_eval(ast, consts):
    """Integer value of an expression made only of literals and constant
    variables, else None."""
    k = ast[0]
    if k == "num":
        return ast[1] if isinstance(ast[1], int) else None
    if k == "var":
        return consts.get(ast[1])
    if k == "un" and ast[1] == "-":
        v = const_eval(ast[2], consts)
        return None if v is None else -v
    if k == "bin" and ast[1] in "+-*":
        a, b = const_eval(ast[2], consts), const_eval(ast[3], consts)
        if a is None or b is None:
            return None
        return a + b if ast[1] == "+" else a - b if ast[1] == "-" else a * b
    return None


def addr_of(items, consts):
    """Resolve an address expression.  Returns a dict with either
    {'addr': n} or {'base': n|None, 'index': text} plus 'expr'."""
    try:
        ast = parse_expr(items)
    except ParseError:
        return {"expr": show(items), "base": None, "index": show(items)}
    out = {"expr": strip_parens(fmt(ast))}
    v = const_eval(ast, consts)
    if v is not None:
        out["addr"] = v + 65536 if v < 0 else v
        return out
    # base + index: sum the constant top-level terms of a +/- chain
    terms = []

    def flatten(a, sign):
        if a[0] == "bin" and a[1] in "+-":
            flatten(a[2], sign)
            flatten(a[3], sign if a[1] == "+" else -sign)
        else:
            terms.append((sign, a))
    flatten(ast, 1)
    base, rest = 0, []
    for sign, a in terms:
        v = const_eval(a, consts)
        if v is None:
            rest.append(("-" if sign < 0 else "+") + strip_parens(fmt(a)))
        else:
            base += sign * v
    out["base"] = base if len(rest) < len(terms) else None
    out["index"] = "".join(rest).lstrip("+")
    return out


# --------------------------------------------------------------------------
# Statements
# --------------------------------------------------------------------------

def split_top(items, sep=","):
    """Split at separators outside parentheses."""
    parts, cur, depth = [], [], 0
    for it in items:
        if it == ("p", "(") or (it[0] == "tok" and it[1] in PAREN_TOKENS):
            depth += 1
        elif it == ("p", ")"):
            depth -= 1
        if it == ("p", sep) and depth == 0:
            parts.append(cur)
            cur = []
        else:
            cur.append(it)
    parts.append(cur)
    return parts


def classify(stmt):
    """One statement (no IF prefix) -> node dict."""
    k0, v0 = stmt[0]
    node = {"kind": "OTHER", "items": stmt}
    if k0 == "id" or (k0, v0) == ("tok", "LET"):
        body = stmt[1:] if k0 == "tok" else stmt
        node["kind"] = "LET"
        if len(body) > 1 and body[1] == ("tok", "="):
            node["var"] = varkey(body[0][1])
            node["rhs"] = body[2:]
        return node
    if k0 != "tok":
        return node
    nums = [int(v) for k, v in stmt[1:] if k == "num" and v.isdigit()]
    if v0 in ("GOTO", "GOSUB"):
        node.update(kind=v0, targets=nums[:1])
    elif v0 == "ON":
        k = next(i for i, it in enumerate(stmt) if it in (("tok", "GOTO"), ("tok", "GOSUB")))
        node.update(kind="ON" + stmt[k][1], expr=stmt[1:k],
                    targets=[int(v) for kk, v in stmt[k + 1:] if kk == "num"])
    elif v0 == "ONERR":
        node.update(kind="ONERR", targets=nums[:1])
    elif v0 in ("RETURN", "POP", "END", "STOP", "NEXT", "REM", "DATA", "PRINT",
                "RUN", "NEW", "INPUT", "GET", "READ", "DIM", "RESUME"):
        node["kind"] = v0
        if v0 == "RUN":
            node["targets"] = nums[:1]
        if v0 == "NEXT":
            node["vars"] = [varkey(v) for k, v in stmt[1:] if k == "id"]
    elif v0 == "FOR":
        node.update(kind="FOR", var=varkey(stmt[1][1]))
    elif v0 == "CALL":
        node.update(kind="CALL", addr_items=stmt[1:])
    elif v0 == "POKE":
        parts = split_top(stmt[1:])
        node.update(kind="POKE", addr_items=parts[0],
                    value_items=parts[1] if len(parts) > 1 else [])
    else:
        node["kind"] = v0
    return node


def line_nodes(items):
    """All nodes of one program line, IF ... THEN flattened so that an IF
    node's false exit is 'next line' and its true exit is 'next node'."""
    stmts, cur = [], []
    for it in items:
        if it == ("p", ":"):
            stmts.append(cur)
            cur = []
        else:
            cur.append(it)
    stmts.append(cur)
    nodes = []
    for stmt in stmts:
        while stmt and stmt[0] == ("tok", "IF"):
            k = next(i for i, it in enumerate(stmt)
                     if it in (("tok", "THEN"), ("tok", "GOTO")))
            nodes.append({"kind": "IF", "items": stmt[:k], "cond": stmt[1:k]})
            stmt = stmt[k + 1:] if stmt[k] == ("tok", "THEN") else stmt[k:]
            if stmt and stmt[0][0] == "num":
                stmt = [("tok", "GOTO")] + stmt
        if stmt:
            nodes.append(classify(stmt))
    return nodes or [{"kind": "EMPTY", "items": []}]


def find_peeks(items):
    """Address item-lists of every PEEK( ... ) in a statement."""
    out = []
    for i, it in enumerate(items):
        if it == ("tok", "PEEK") and i + 1 < len(items) and items[i + 1] == ("p", "("):
            depth, j = 0, i + 1
            while j < len(items):
                if items[j] == ("p", "(") or (items[j][0] == "tok" and items[j][1] in PAREN_TOKENS):
                    depth += 1
                elif items[j] == ("p", ")"):
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            out.append(items[i + 2:j])
    return out


def dos_command(node, ctrl_d_vars):
    """If a PRINT node hands a line to DOS, describe it."""
    items = node["items"][1:]
    start = None
    for i, (k, v) in enumerate(items):
        if k == "str" and b"\x04" in v:
            start = i
            break
        if k == "id" and varkey(v) in ctrl_d_vars:
            start = i
            break
        if (k, v) == ("tok", "CHR$") and show(items[i:i + 4]) == "CHR$ (4)":
            start = i
            break
    if start is None:
        return None
    pieces, dyn, rest = [], [], items[start:]
    if rest[0][0] == "id":            # D$ holding Ctrl-D
        pieces, rest = ["\x04"], rest[1:]
    elif rest[0] == ("tok", "CHR$"):  # literal CHR$(4)
        pieces, rest = ["\x04"], rest[4:]
    for k, v in rest:
        if k == "str":
            if dyn:
                pieces.append("{%s}" % show(dyn))
                dyn = []
            pieces.append(v.decode("latin-1"))
        elif (k, v) in (("p", ";"), ("p", ",")):
            continue
        else:
            dyn.append((k, v))
    if dyn:
        pieces.append("{%s}" % show(dyn))
    full = "".join(pieces)
    cmd = full.split("\x04", 1)[1] if "\x04" in full else full
    verb = next((vb for vb in DOS_VERBS if cmd.upper().startswith(vb)), None)
    rest = cmd[len(verb):] if verb else cmd
    name, _, params = rest.partition(",")
    out = {"verb": verb or "?", "name": name.strip(), "raw": cmd,
           "dynamic": "{" in cmd,
           # DOS only honours Ctrl-D as the first character of an output
           # line; anything printed before it in the same PRINT defeats it.
           "leading": start == 0 and (items[0][0] != "str" or items[0][1].startswith(b"\x04"))}
    for m in re.finditer(r"([ASDVLRB])\s*(\$[0-9A-Fa-f]+|\d+)", "," + params if params else ""):
        val = m.group(2)
        out[m.group(1)] = int(val[1:], 16) if val.startswith("$") else int(val)
    return out


# --------------------------------------------------------------------------
# Per-file analysis
# --------------------------------------------------------------------------

def program(data):
    """(nodes, first node index of each line, first node of the line after
    each line) for one program image."""
    nodes, first_of_line, line_order = [], {}, []
    for num, body in read_lines(data):
        line_order.append(num)
        first_of_line[num] = len(nodes)
        for nd in line_nodes(lex(body)):
            nd["line"] = num
            nodes.append(nd)
    nxt_line_first = {}
    for a, b in zip(line_order, line_order[1:]):
        nxt_line_first[a] = first_of_line[b]
    return nodes, first_of_line, nxt_line_first


def analyze(name, data):
    lines = read_lines(data)
    nodes, first_of_line, nxt_line_first = program(data)

    # constants: scalars only ever assigned one integer literal
    assigned, volatile = defaultdict(list), set()
    for nd in nodes:
        if nd["kind"] == "LET" and "var" in nd:
            assigned[nd["var"]].append(nd["rhs"])
        elif nd["kind"] == "FOR":
            volatile.add(nd["var"])
        elif nd["kind"] in ("INPUT", "GET", "READ"):
            volatile.update(varkey(v) for k, v in nd["items"] if k == "id")
    consts = {}
    for _ in range(4):
        for var, rhss in assigned.items():
            if var in volatile:
                continue
            vals = set()
            for rhs in rhss:
                try:
                    vals.add(const_eval(parse_expr(rhs), consts))
                except ParseError:
                    vals.add(None)
            if len(vals) == 1 and None not in vals:
                consts[var] = vals.pop()
    ctrl_d_vars = {var for var, rhss in assigned.items()
                   if any(show(r) in ('"^D"', "CHR$ (4)") for r in rhss)}

    # edges
    undefined = []

    def target(n, src):
        if n in first_of_line:
            return first_of_line[n]
        undefined.append({"line": nodes[src]["line"], "target": n})
        return None

    edges = defaultdict(list)
    for i, nd in enumerate(nodes):
        seq = i + 1 if i + 1 < len(nodes) else None
        kind = nd["kind"]
        dos = dos_command(nd, ctrl_d_vars) if kind == "PRINT" else None
        if dos:
            nd["dos"] = dos
        if kind == "IF":
            edges[i] += [(seq, "true"), (nxt_line_first.get(nd["line"]), "false")]
        elif kind == "GOTO":
            edges[i] += [(target(t, i), "goto") for t in nd["targets"]]
        elif kind == "GOSUB":
            edges[i] += [(target(t, i), "call") for t in nd["targets"]] + [(seq, "ret")]
        elif kind == "ONGOTO":
            edges[i] += [(target(t, i), "goto") for t in nd["targets"]] + [(seq, "seq")]
        elif kind == "ONGOSUB":
            edges[i] += [(target(t, i), "call") for t in nd["targets"]] + [(seq, "ret")]
        elif kind == "ONERR":
            edges[i] += [(seq, "seq")] + [(target(t, i), "onerr") for t in nd["targets"]]
        elif kind in ("RETURN", "END", "STOP", "NEW"):
            pass
        elif kind == "RUN":
            edges[i].append((target(nd["targets"][0], i) if nd["targets"] else 0, "restart"))
        elif dos and dos["verb"] in ("RUN", "BRUN", "PR#", "INT", "FP") and dos["leading"]:
            pass  # control leaves this program
        else:
            edges[i].append((seq, "seq"))
            if kind == "NEXT":
                for j in range(i - 1, -1, -1):
                    if nodes[j]["kind"] == "FOR" and (not nd["vars"] or nodes[j]["var"] in nd["vars"]):
                        edges[i].append((j + 1, "loop"))
                        break
        edges[i] = [(d, k) for d, k in edges[i] if d is not None]

    # which GOSUB targets can reach a RETURN (fixpoint; POP not modelled)
    sub_entries = sorted({d for i in edges for d, k in edges[i] if k == "call"})
    returns = {}

    def body_of(entry):
        seen, todo = {entry}, deque([entry])
        while todo:
            i = todo.popleft()
            for d, k in edges[i]:
                if k == "call" or k == "onerr":
                    continue
                if k == "ret" and not any(returns.get(c) for c, ck in edges[i] if ck == "call"):
                    continue
                if d not in seen:
                    seen.add(d)
                    todo.append(d)
        return seen

    changed = True
    while changed:
        changed = False
        for e in sub_entries:
            r = any(nodes[i]["kind"] == "RETURN" for i in body_of(e))
            if r != returns.get(e, False):
                returns[e] = r
                changed = True

    def reach(roots, follow_calls=True):
        seen, todo = set(roots), deque(roots)
        while todo:
            i = todo.popleft()
            for d, k in edges[i]:
                if k == "call" and not follow_calls:
                    continue
                if k == "ret" and not any(returns.get(c) for c, ck in edges[i] if ck == "call"):
                    continue
                if d not in seen:
                    seen.add(d)
                    todo.append(d)
        return seen

    reachable = reach([0]) if nodes else set()
    main_flow = reach([0], follow_calls=False) if nodes else set()

    def ref(i):
        return nodes[i]["line"]

    # subroutines
    callers = defaultdict(list)
    for i in edges:
        for d, k in edges[i]:
            if k == "call":
                callers[d].append(ref(i))
    subs = []
    bodies = {e: body_of(e) for e in sub_entries}
    for e in sub_entries:
        body = bodies[e]
        entered_plain = sorted({ref(i) for i in edges for d, k in edges[i]
                                if d == e and k not in ("call",) and i not in body})
        subs.append({
            "entry": ref(e),
            "callers": sorted(callers[e]),
            "lines": sorted({ref(i) for i in body}),
            "returns_at": sorted({ref(i) for i in body if nodes[i]["kind"] == "RETURN"}),
            "leaves_program_at": sorted({ref(i) for i in body if nodes[i].get("dos", {}).get("verb") == "RUN"}),
            "has_pop": any(nodes[i]["kind"] == "POP" for i in body),
            "also_entered_without_gosub_from": entered_plain,
            "shares_lines_with": sorted({ref(o) for o in sub_entries if o != e
                                         and ref(o) not in {ref(i) for i in body if i == o}
                                         and bodies[o] & body and o not in body and e not in bodies[o]}),
            "nested_entry_inside": sorted({ref(o) for o in sub_entries if o != e and e in bodies[o]}),
            "gosubs": sorted({t for i in body if nodes[i]["kind"] in ("GOSUB", "ONGOSUB") for t in nodes[i]["targets"]}),
            "calls": sorted({addr_of(nodes[i]["addr_items"], consts).get("addr", -1)
                             for i in body if nodes[i]["kind"] == "CALL"}),
        })

    preds = defaultdict(list)
    for i in edges:
        for d, k in edges[i]:
            if k in ("seq", "goto", "true"):
                preds[d].append(i)

    # memory accesses, CALLs, DOS commands, dispatch tables, input sites
    mem, calls, dos_cmds, dispatch, inputs = [], [], [], [], []
    for i, nd in enumerate(nodes):
        live = i in reachable
        for addr_items in find_peeks(nd["items"]):
            a = addr_of(addr_items, consts)
            mem.append(dict(a, op="PEEK", line=nd["line"], reachable=live))
        if nd["kind"] == "POKE":
            a = addr_of(nd["addr_items"], consts)
            mem.append(dict(a, op="POKE", line=nd["line"], value=show(nd["value_items"]), reachable=live))
        if nd["kind"] == "CALL":
            a = addr_of(nd["addr_items"], consts)
            # POKEs that run straight into this CALL: walk predecessors
            # (fall-through, GOTO, THEN) until something other than a
            # plain statement is in the way
            pokes, seen, todo = [], {i}, [(i, 0)]
            while todo:
                j, depth = todo.pop()
                for p in preds[j]:
                    if p in seen or depth >= 12 or nodes[p]["kind"] in BARRIERS:
                        continue
                    seen.add(p)
                    if nodes[p]["kind"] == "POKE":
                        pa = addr_of(nodes[p]["addr_items"], consts)
                        pokes.append({"addr": pa.get("addr"), "addr_expr": pa["expr"],
                                      "value": show(nodes[p]["value_items"]),
                                      "line": nodes[p]["line"]})
                    todo.append((p, depth + 1))
            pokes.sort(key=lambda p: (p["line"], str(p["addr"])))
            calls.append(dict(a, line=nd["line"], reachable=live, pokes_before=pokes))
        if "dos" in nd:
            dos_cmds.append(dict(nd["dos"], line=nd["line"], reachable=live))
        if nd["kind"] in ("ONGOTO", "ONGOSUB"):
            dispatch.append({"line": nd["line"], "kind": nd["kind"], "expr": show(nd["expr"]),
                             "targets": nd["targets"], "reachable": live})
        if nd["kind"] in ("GET", "INPUT"):
            inputs.append({"line": nd["line"], "kind": nd["kind"], "text": show(nd["items"])})

    # vectors: both halves POKEd with constants, hi taken from the nearest lo
    const_pokes = defaultdict(list)
    for i, nd in enumerate(nodes):
        if nd["kind"] == "POKE":
            a = addr_of(nd["addr_items"], consts).get("addr")
            try:
                v = const_eval(parse_expr(nd["value_items"]), consts)
            except ParseError:
                v = None
            if a is not None and v is not None:
                const_pokes[a].append((i, v))
    vectors = []
    for (lo, hi), (vname, effect) in VECTORS.items():
        for i, v in const_pokes.get(lo, []):
            near = min(const_pokes.get(hi, []), key=lambda p: abs(p[0] - i), default=None)
            if near:
                vectors.append({"line": nodes[i]["line"], "vector": vname, "effect": effect,
                                "addr": v + 256 * near[1], "reachable": i in reachable})

    unreachable_lines = sorted({ref(i) for i in range(len(nodes)) if i not in reachable
                                and nodes[i]["kind"] not in ("REM", "DATA", "EMPTY")})
    partly = sorted({ln for ln in unreachable_lines
                     if any(i in reachable for i in range(len(nodes)) if nodes[i]["line"] == ln)})
    jumps = []
    for i in edges:
        for d, k in edges[i]:
            if k in ("goto", "call", "onerr", "restart"):
                jumps.append({"from": ref(i), "to": ref(d), "kind": k, "via": nodes[i]["kind"]})

    return {
        "name": name,
        "lines": len(lines),
        "statements": len(nodes),
        "listing": {num: detok(body) for num, body in lines},
        "constants": dict(sorted(consts.items())),
        "ctrl_d_vars": sorted(ctrl_d_vars),
        "dos": dos_cmds,
        "calls": calls,
        "vectors": vectors,
        "mem": mem,
        "dispatch": dispatch,
        "inputs": inputs,
        "subroutines": subs,
        "jumps": jumps,
        "undefined_targets": undefined,
        "unreachable_lines": unreachable_lines,
        "partly_unreachable_lines": partly,
        "return_in_main_flow": sorted({ref(i) for i in main_flow if nodes[i]["kind"] == "RETURN"}),
        "pop_lines": sorted({ref(i) for i in range(len(nodes)) if nodes[i]["kind"] == "POP"}),
        "kind_counts": dict(sorted(_count(nd["kind"] for nd in nodes).items())),
    }


def _count(it):
    out = defaultdict(int)
    for x in it:
        out[x] += 1
    return out


# --------------------------------------------------------------------------
# Whole-disk view
# --------------------------------------------------------------------------

# statements a POKE-then-CALL setup cannot be traced back through
BARRIERS = {"CALL", "GOSUB", "ONGOSUB", "ONGOTO", "RETURN", "IF", "FOR", "NEXT"}


def dos_to_file(name):
    return name.replace("/", "_").replace("#", "no")


def load_binaries():
    """{name: (load, length)} from the 4-byte DOS 3.3 binary headers."""
    out = {}
    for fn in sorted(os.listdir(EXTRACTED)):
        if fn.endswith(".bin") and not fn.endswith(".payload.bin"):
            with open(os.path.join(EXTRACTED, fn), "rb") as f:
                head = f.read(4)
            if len(head) == 4:
                out[fn[:-4]] = (u16(head, 0), u16(head, 2))
    return out


def build():
    files = {}
    for fn in sorted(os.listdir(EXTRACTED)):
        if fn.endswith(".bas"):
            with open(os.path.join(EXTRACTED, fn), "rb") as f:
                files[fn[:-4]] = analyze(fn[:-4], f.read())
    binaries = load_binaries()

    # where each binary actually gets loaded: header address unless a
    # BLOAD in some program overrides it with ,A
    loads = defaultdict(set)
    for fname, info in files.items():
        for d in info["dos"]:
            if d["verb"] in ("BLOAD", "BRUN"):
                # a computed name ("SHIP # {J}") loads whichever binary matches
                pat = re.sub(r"\\\{.*?\\\}", r"\\d+", re.escape(dos_to_file(d["name"])))
                for b in binaries:
                    if re.fullmatch(pat + r"(\.A\d+\.L\d+)?", b):
                        loads[b].add(d.get("A", binaries[b][0]))
    regions = []
    for b, (load, length) in binaries.items():
        for a in sorted(loads.get(b) or {load}):
            regions.append({"binary": b, "start": a, "end": a + length - 1,
                            "bloaded": b in loads})

    def owners(addr):
        # numbered families (PLANET # 1..20, SHIP # 0..4) collapse to one entry
        out = []
        for r in regions:
            if r["bloaded"] and r["start"] <= addr <= r["end"]:
                o = "%s+$%X" % (re.sub(r" no \d+$", " no N", r["binary"]), addr - r["start"])
                if o not in out:
                    out.append(o)
        return out

    return {"files": files, "binaries": {b: {"load": l, "length": n} for b, (l, n) in binaries.items()},
            "regions": regions}, owners


# --------------------------------------------------------------------------
# Markdown report
# --------------------------------------------------------------------------

def hx(a):
    return "$%04X" % a


def lines_str(nums, limit=14):
    nums = sorted(set(nums))
    s = ",".join(str(n) for n in nums[:limit])
    return s + (",… (%d)" % len(nums) if len(nums) > limit else "")


def report(model, owners):
    files = model["files"]
    out = []
    w = out.append
    w("# BASIC call map (machine-generated)\n")
    w("Generated by `tools/basic_callmap.py` from the tokenized programs in "
      "`extracted/*.bas`. Do not edit by hand; re-run the tool. This is "
      "structure only: every line here is a mechanical fact about the "
      "program text (what transfers control where, what reads and writes "
      "which address). It says nothing about what a routine *means*, and "
      "reachability is static (a branch counts as possible whenever the "
      "syntax allows it). Hand-written interpretation lives in "
      "`CALL_SITES.md`.\n")

    # ---- scene graph
    w("## 1. Scene graph: DOS `RUN` commands hidden behind Ctrl-D\n")
    w("| From | Line | Runs | Reachable | Note |")
    w("|---|---|---|---|---|")
    for fname, info in files.items():
        for d in info["dos"]:
            if d["verb"] == "RUN":
                note = []
                if not d["leading"]:
                    note.append("Ctrl-D not first in PRINT")
                tgt = dos_to_file(d["name"])
                if not d["dynamic"] and tgt not in files:
                    note.append("no such program extracted")
                w("| %s | %d | `%s` | %s | %s |" % (fname, d["line"], d["name"],
                  "yes" if d["reachable"] else "**no**", "; ".join(note)))
    w("")
    inbound = defaultdict(set)
    for fname, info in files.items():
        for d in info["dos"]:
            if d["verb"] == "RUN" and not d["dynamic"]:
                inbound[dos_to_file(d["name"])].add(fname)
    w("Programs no fixed-name `RUN` reaches: " + (", ".join(
        "`%s`" % f for f in files if f not in inbound) or "none") + ".\n")

    w("## 2. Other DOS commands (loads, saves, file I/O)\n")
    w("| From | Line | Command | Reachable |")
    w("|---|---|---|---|")
    for fname, info in files.items():
        for d in info["dos"]:
            if d["verb"] != "RUN" and not (d["verb"] == "INT" and d["line"] == 63999):
                w("| %s | %d | `%s` | %s |" % (fname, d["line"], d["raw"].strip(),
                  "yes" if d["reachable"] else "**no**"))
    w("")
    n_int = sum(1 for info in files.values() for d in info["dos"]
                if d["verb"] == "INT" and d["line"] == 63999)
    w("%d of %d programs also end with `63999 … PRINT ^D\"INT\"`, the target "
      "of their `ONERR GOTO 63999`.\n" % (n_int, len(files)))

    w("## 3. Where binaries sit in memory\n")
    w("Header address unless a `BLOAD …,A` above overrides it. "
      "A computed name such as `SHIP # {J}` counts as loading every "
      "binary it can match. \"no\" means no BLOAD in any program names "
      "the file; those are left out of the \"Inside\" columns below.\n")
    w("| Binary | Range | Length | BLOADed by a program |")
    w("|---|---|---|---|")
    for r in sorted(model["regions"], key=lambda r: (r["start"], r["binary"])):
        w("| %s | %s-%s | %d | %s |" % (r["binary"], hx(r["start"]), hx(r["end"]),
          r["end"] - r["start"] + 1, "yes" if r["bloaded"] else "no"))
    w("")

    # ---- CALL sites
    w("## 4. Machine-code CALL sites\n")
    by_addr = defaultdict(list)
    for fname, info in files.items():
        for c in info["calls"]:
            by_addr[c.get("addr", c["expr"])].append((fname, c))
    w("| Address | Inside | Called from (program:line) | POKEs that run straight into the CALL |")
    w("|---|---|---|---|")
    for addr in sorted(by_addr, key=lambda a: (isinstance(a, str), a)):
        sites = by_addr[addr]
        where = "; ".join("%s:%d%s" % (f, c["line"], "" if c["reachable"] else " (unreachable)")
                          for f, c in sites)
        pk = []
        for f, c in sites:
            if c["pokes_before"]:
                pk.append("%s:%d: " % (f, c["line"]) + ", ".join(
                    "%s←`%s`%s" % (p["addr"] if p["addr"] is not None else p["addr_expr"], p["value"],
                                   "" if p["line"] == c["line"] else " (line %d)" % p["line"])
                    for p in c["pokes_before"]))
        if isinstance(addr, int):
            w("| %d %s | %s | %s | %s |" % (addr, hx(addr), ", ".join(owners(addr)) or "—",
                                            where, "<br>".join(pk)))
        else:
            w("| `%s` | ? | %s | %s |" % (addr, where, "<br>".join(pk)))
    w("")

    vecs = [(f, v) for f, info in files.items() for v in info["vectors"]]
    if vecs:
        w("### Routines and tables installed through a vector\n")
        w("No CALL appears at these sites: the program POKEs a two-byte "
          "pointer and the firmware does the jumping from then on.\n")
        w("| Program:line | Vector | Points at | Inside | Effect |")
        w("|---|---|---|---|---|")
        for f, v in vecs:
            w("| %s:%d | %s | %d %s | %s | %s |" % (f, v["line"], v["vector"], v["addr"], hx(v["addr"]),
              ", ".join(owners(v["addr"])) or "—", v["effect"]))
        w("")

    # ---- memory table
    w("## 5. Shared memory: who PEEKs and POKEs each address\n")
    w("Fixed addresses first, then computed ones grouped by their constant "
      "base. `R` = PEEK, `W` = POKE; numbers are line numbers. Addresses "
      "touched by a single program and only read or only written are "
      "included too, since a one-sided access usually means the other "
      "side is machine code.\n")
    fixed = defaultdict(lambda: defaultdict(lambda: {"R": [], "W": []}))
    indexed = defaultdict(lambda: defaultdict(lambda: {"R": [], "W": [], "idx": set()}))
    for fname, info in files.items():
        for m in info["mem"]:
            rw = "R" if m["op"] == "PEEK" else "W"
            if "addr" in m:
                fixed[m["addr"]][fname][rw].append(m["line"])
            else:
                key = m["base"] if m["base"] is not None else m["expr"]
                indexed[key][fname][rw].append(m["line"])
                indexed[key][fname]["idx"].add(m["index"])
    w("| Address | Inside / known as | Readers | Writers |")
    w("|---|---|---|---|")
    for addr in sorted(fixed):
        rd = "; ".join("%s %s" % (f, lines_str(v["R"])) for f, v in fixed[addr].items() if v["R"])
        wr = "; ".join("%s %s" % (f, lines_str(v["W"])) for f, v in fixed[addr].items() if v["W"])
        what = KNOWN_ADDRS.get(addr) or ", ".join(owners(addr)) or "—"
        w("| %d %s | %s | %s | %s |" % (addr, hx(addr), what, rd or "—", wr or "—"))
    w("")
    w("### Computed addresses (base + index)\n")
    w("| Base | Inside | Index expressions | Readers | Writers |")
    w("|---|---|---|---|---|")
    for key in sorted(indexed, key=lambda a: (isinstance(a, str), a)):
        rd = "; ".join("%s %s" % (f, lines_str(v["R"])) for f, v in indexed[key].items() if v["R"])
        wr = "; ".join("%s %s" % (f, lines_str(v["W"])) for f, v in indexed[key].items() if v["W"])
        idx = sorted({i for v in indexed[key].values() for i in v["idx"]})
        base = "%d %s" % (key, hx(key)) if isinstance(key, int) else "`%s`" % key
        what = (", ".join(owners(key)) or "—") if isinstance(key, int) else "?"
        w("| %s | %s | %s | %s | %s |" % (base, what, ", ".join("`%s`" % i for i in idx[:6])
                                          + (" …" if len(idx) > 6 else ""), rd or "—", wr or "—"))
    w("")

    # ---- per-file control flow
    w("## 6. Per-program control flow\n")
    for fname, info in files.items():
        w("### %s  (%d lines, %d statements)\n" % (fname, info["lines"], info["statements"]))
        if info["constants"]:
            w("Constants: " + ", ".join("`%s`=%d" % kv for kv in info["constants"].items()) + "\n")
        if info["dispatch"]:
            w("Computed branches:\n")
            for d in info["dispatch"]:
                w("- line %d: `ON %s %s %s`%s" % (d["line"], d["expr"], d["kind"][2:],
                  ",".join(map(str, d["targets"])), "" if d["reachable"] else " (unreachable)"))
            w("")
        if info["subroutines"]:
            w("| GOSUB target | Called from | Body lines | RETURN at | Flags |")
            w("|---|---|---|---|---|")
            for s in info["subroutines"]:
                flags = []
                if not s["returns_at"]:
                    flags.append("**never reaches RETURN**")
                if s["leaves_program_at"]:
                    flags.append("can leave via DOS RUN at " + lines_str(s["leaves_program_at"]))
                if s["has_pop"]:
                    flags.append("uses POP")
                if s["also_entered_without_gosub_from"]:
                    flags.append("also entered by GOTO/fall-through from "
                                 + lines_str(s["also_entered_without_gosub_from"]))
                if s["nested_entry_inside"]:
                    flags.append("is a mid-body entry of " + lines_str(s["nested_entry_inside"]))
                if s["shares_lines_with"]:
                    flags.append("shares a tail with " + lines_str(s["shares_lines_with"]))
                if s["calls"]:
                    flags.append("CALLs " + ", ".join(hx(c) if c >= 0 else "?" for c in s["calls"]))
                w("| %d | %s | %s | %s | %s |" % (s["entry"], lines_str(s["callers"]),
                  lines_str(s["lines"], 10), lines_str(s["returns_at"]) or "—", "; ".join(flags)))
            w("")
        notes = []
        if info["undefined_targets"]:
            notes.append("Branches to line numbers that do not exist: " + ", ".join(
                "%d→%d" % (u["line"], u["target"]) for u in info["undefined_targets"]))
        if info["return_in_main_flow"]:
            notes.append("RETURN reachable without any GOSUB (static): lines "
                         + lines_str(info["return_in_main_flow"]))
        if info["pop_lines"]:
            notes.append("POP at line " + lines_str(info["pop_lines"]))
        full = [l for l in info["unreachable_lines"] if l not in info["partly_unreachable_lines"]]
        if full:
            notes.append("Lines no static path reaches: " + lines_str(full, 40))
        if info["partly_unreachable_lines"]:
            notes.append("Lines with an unreachable tail (statements after an "
                         "unconditional branch): " + lines_str(info["partly_unreachable_lines"], 40))
        for n in notes:
            w("- " + n)
        if notes:
            w("")
    return "\n".join(out) + "\n"


def main():
    model, owners = build()
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w") as f:
        json.dump(model, f, indent=1, default=lambda o: sorted(o) if isinstance(o, set) else str(o))
        f.write("\n")
    with open(OUT_MD, "w") as f:
        f.write(report(model, owners))
    files = model["files"]
    print("%d programs, %d lines, %d statements" % (
        len(files), sum(i["lines"] for i in files.values()),
        sum(i["statements"] for i in files.values())))
    print("%d DOS commands, %d CALL sites, %d PEEK/POKE sites" % (
        sum(len(i["dos"]) for i in files.values()),
        sum(len(i["calls"]) for i in files.values()),
        sum(len(i["mem"]) for i in files.values())))
    print("wrote %s\n      %s" % (os.path.relpath(OUT_JSON, ROOT), os.path.relpath(OUT_MD, ROOT)))


if __name__ == "__main__":
    sys.exit(main())
