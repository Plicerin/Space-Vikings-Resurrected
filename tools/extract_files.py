#!/usr/bin/env python3
"""Extract files from the Space Vikings DSK and detokenize the Applesoft launcher."""
import os, sys, struct
sys.path.insert(0, os.path.dirname(__file__))
from dos33_catalog import (read_sector, parse_vtoc, walk_catalog, file_bytes,
                            SECTOR_SIZE)

# Applesoft BASIC tokens (0x80 - 0xEA)
TOKENS = {
    0x80:'END',0x81:'FOR',0x82:'NEXT',0x83:'DATA',0x84:'INPUT',0x85:'DEL',
    0x86:'DIM',0x87:'READ',0x88:'GR',0x89:'TEXT',0x8A:'PR#',0x8B:'IN#',
    0x8C:'CALL',0x8D:'PLOT',0x8E:'HLIN',0x8F:'VLIN',0x90:'HGR2',0x91:'HGR',
    0x92:'HCOLOR=',0x93:'HPLOT',0x94:'DRAW',0x95:'XDRAW',0x96:'HTAB',0x97:'HOME',
    0x98:'ROT=',0x99:'SCALE=',0x9A:'SHLOAD',0x9B:'TRACE',0x9C:'NOTRACE',
    0x9D:'NORMAL',0x9E:'INVERSE',0x9F:'FLASH',0xA0:'COLOR=',0xA1:'POP',
    0xA2:'VTAB',0xA3:'HIMEM:',0xA4:'LOMEM:',0xA5:'ONERR',0xA6:'RESUME',
    0xA7:'RECALL',0xA8:'STORE',0xA9:'SPEED=',0xAA:'LET',0xAB:'GOTO',
    0xAC:'RUN',0xAD:'IF',0xAE:'RESTORE',0xAF:'&',0xB0:'GOSUB',0xB1:'RETURN',
    0xB2:'REM',0xB3:'STOP',0xB4:'ON',0xB5:'WAIT',0xB6:'LOAD',0xB7:'SAVE',
    0xB8:'DEF',0xB9:'POKE',0xBA:'PRINT',0xBB:'CONT',0xBC:'LIST',0xBD:'CLEAR',
    0xBE:'GET',0xBF:'NEW',0xC0:'TAB(',0xC1:'TO',0xC2:'FN',0xC3:'SPC(',
    0xC4:'THEN',0xC5:'AT',0xC6:'NOT',0xC7:'STEP',0xC8:'+',0xC9:'-',
    0xCA:'*',0xCB:'/',0xCC:'^',0xCD:'AND',0xCE:'OR',0xCF:'>',0xD0:'=',
    0xD1:'<',0xD2:'SGN',0xD3:'INT',0xD4:'ABS',0xD5:'USR',0xD6:'FRE',
    0xD7:'SCRN(',0xD8:'PDL',0xD9:'POS',0xDA:'SQR',0xDB:'RND',0xDC:'LOG',
    0xDD:'EXP',0xDE:'COS',0xDF:'SIN',0xE0:'TAN',0xE1:'ATN',0xE2:'PEEK',
    0xE3:'LEN',0xE4:'STR$',0xE5:'VAL',0xE6:'ASC',0xE7:'CHR$',0xE8:'LEFT$',
    0xE9:'RIGHT$',0xEA:'MID$',
}

def detokenize_applesoft(data):
    # Applesoft DOS 3.3 file format: [length lo, length hi, program bytes...]
    # actually DOS 3.3 BASIC files: first 2 bytes = length of program in memory
    if len(data) < 2:
        return ''
    prog_len = struct.unpack('<H', data[0:2])[0]
    p = data[2:2+prog_len]
    out = []
    i = 0
    while i < len(p) - 1:
        next_addr = struct.unpack('<H', p[i:i+2])[0]
        if next_addr == 0:
            break
        line_num = struct.unpack('<H', p[i+2:i+4])[0]
        i += 4
        line = []
        while i < len(p) and p[i] != 0:
            b = p[i]
            if b >= 0x80:
                line.append(' ' + TOKENS.get(b, f'<{b:02X}>') + ' ')
            else:
                line.append(chr(b))
            i += 1
        i += 1  # skip terminating null
        out.append(f"{line_num} {''.join(line).strip()}")
    return '\n'.join(out)

def binary_header(data):
    # DOS 3.3 binary file: [load_addr lo, load_addr hi, length lo, length hi, ...payload]
    if len(data) < 4:
        return None, None
    load = struct.unpack('<H', data[0:2])[0]
    length = struct.unpack('<H', data[2:4])[0]
    return load, length

def main():
    dsk_path = "/home/claude/spacevikings/Space Vikings (4am crack)/Space Vikings (4am crack).dsk"
    out_dir = "/home/claude/spacevikings/extracted"
    os.makedirs(out_dir, exist_ok=True)
    with open(dsk_path, 'rb') as f:
        data = f.read()
    vtoc = parse_vtoc(read_sector(data, 17, 0))
    entries = walk_catalog(data, vtoc['catalog_track'], vtoc['catalog_sector'])

    print(f"{'Type':4} {'Load':>6} {'Length':>6} {'Sectors':>7}  Name")
    print("-" * 70)
    for e in entries:
        if e['deleted']:
            continue
        raw = file_bytes(data, e)
        # sanitize filename for filesystem
        safe = e['name'].replace('/', '_').replace('#', 'no').strip()
        if not safe:
            continue
        ext = {'A':'bas','B':'bin','T':'txt','I':'iba'}.get(e['type'], 'dat')
        with open(os.path.join(out_dir, f"{safe}.{ext}"), 'wb') as f:
            f.write(raw)
        if e['type'] == 'B':
            load, length = binary_header(raw)
            print(f"BIN  ${load:04X}  ${length:04X} {e['sectors_used']:>7}  {e['name']}")
            # also save payload-only
            with open(os.path.join(out_dir, f"{safe}.payload.bin"), 'wb') as f:
                f.write(raw[4:4+length])
        elif e['type'] == 'A':
            print(f"BAS         {len(raw):>5}  {e['sectors_used']:>7}  {e['name']}")
        elif e['type'] == 'T':
            print(f"TXT         {len(raw):>5}  {e['sectors_used']:>7}  {e['name']}")
        else:
            print(f"{e['type']:4}        {len(raw):>5}  {e['sectors_used']:>7}  {e['name']}")
    return entries, data

if __name__ == '__main__':
    main()
