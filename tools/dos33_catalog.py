#!/usr/bin/env python3
"""Catalog a DOS 3.3 .dsk image (140K, 35 tracks x 16 sectors x 256 bytes).

Layout:
  Track 17 ($11) is the catalog track.
  Sector 0 of track 17 is the VTOC.
  Catalog sectors form a linked list starting at the sector named by the VTOC.
  Each catalog sector holds up to 7 file entries of 35 bytes (offset $0B onwards).
"""
import sys, struct

SECTOR_SIZE = 256
TRACKS = 35
SECTORS_PER_TRACK = 16

FILE_TYPES = {
    0x00: 'T',  # Text
    0x01: 'I',  # Integer BASIC
    0x02: 'A',  # Applesoft BASIC
    0x04: 'B',  # Binary
    0x08: 'S',  # type S
    0x10: 'R',  # Relocatable
    0x20: 'AA', # type A (new)
    0x40: 'BB', # type B (new)
}

def sector_offset(track, sector):
    return (track * SECTORS_PER_TRACK + sector) * SECTOR_SIZE

def read_sector(data, track, sector):
    off = sector_offset(track, sector)
    return data[off:off + SECTOR_SIZE]

def parse_filename(raw):
    # DOS 3.3 stores filenames with the high bit set on every char.
    return ''.join(chr(b & 0x7F) for b in raw).rstrip()

def parse_vtoc(vtoc):
    return {
        'catalog_track': vtoc[0x01],
        'catalog_sector': vtoc[0x02],
        'dos_release': vtoc[0x03],
        'volume': vtoc[0x06],
        'tracks_per_disk': vtoc[0x34],
        'sectors_per_track': vtoc[0x35],
        'bytes_per_sector': struct.unpack('<H', vtoc[0x36:0x38])[0],
    }

def parse_catalog_entry(entry):
    track_sector_list_track = entry[0x00]
    if track_sector_list_track == 0x00:
        return None  # never used
    deleted = (track_sector_list_track == 0xFF)
    if deleted:
        # Original first track byte is moved to end ($20). Mark as deleted.
        track_sector_list_track = entry[0x20]
    track_sector_list_sector = entry[0x01]
    file_type_byte = entry[0x02]
    locked = bool(file_type_byte & 0x80)
    type_code = file_type_byte & 0x7F
    type_letter = FILE_TYPES.get(type_code, f'?{type_code:02X}')
    name = parse_filename(entry[0x03:0x21])
    sectors_used = struct.unpack('<H', entry[0x21:0x23])[0]
    return {
        'deleted': deleted,
        'locked': locked,
        'type': type_letter,
        'type_byte': file_type_byte,
        'name': name,
        'sectors_used': sectors_used,
        'tslist_track': track_sector_list_track,
        'tslist_sector': track_sector_list_sector,
    }

def walk_catalog(data, start_track, start_sector):
    entries = []
    t, s = start_track, start_sector
    visited = set()
    while (t, s) not in visited:
        visited.add((t, s))
        sec = read_sector(data, t, s)
        next_t, next_s = sec[0x01], sec[0x02]
        for i in range(7):
            off = 0x0B + i * 0x23
            ent = parse_catalog_entry(sec[off:off + 0x23])
            if ent is not None:
                entries.append(ent)
        if next_t == 0 and next_s == 0:
            break
        t, s = next_t, next_s
    return entries

def collect_tslist(data, track, sector):
    """Walk a track/sector list to collect every data sector address."""
    sectors = []
    visited = set()
    while (track, sector) != (0, 0) and (track, sector) not in visited:
        visited.add((track, sector))
        sec = read_sector(data, track, sector)
        next_t, next_s = sec[0x01], sec[0x02]
        # entries start at $0C, 2 bytes each (track, sector), up to 122 entries
        for i in range(122):
            off = 0x0C + i * 2
            ts_t, ts_s = sec[off], sec[off + 1]
            if ts_t == 0 and ts_s == 0:
                # could be a hole (sparse file) or end-of-list
                sectors.append(None)
            else:
                sectors.append((ts_t, ts_s))
        # trim trailing Nones
        while sectors and sectors[-1] is None:
            sectors.pop()
        track, sector = next_t, next_s
    return sectors

def file_bytes(data, entry):
    sectors = collect_tslist(data, entry['tslist_track'], entry['tslist_sector'])
    out = bytearray()
    for ts in sectors:
        if ts is None:
            out.extend(b'\x00' * SECTOR_SIZE)
        else:
            out.extend(read_sector(data, ts[0], ts[1]))
    return bytes(out)

def main(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert len(data) == TRACKS * SECTORS_PER_TRACK * SECTOR_SIZE, f"unexpected size {len(data)}"
    vtoc = parse_vtoc(read_sector(data, 17, 0))
    print("VTOC:")
    for k, v in vtoc.items():
        print(f"  {k:20s} {v}")
    print()
    entries = walk_catalog(data, vtoc['catalog_track'], vtoc['catalog_sector'])
    print(f"Catalog ({len(entries)} entries):")
    print(f"  {'Lk':<2}  {'Tp':<2}  {'Sec':>4}  {'TSList':<8}  Name")
    for e in entries:
        lk = 'L' if e['locked'] else ' '
        if e['deleted']:
            lk += 'X'
        else:
            lk += ' '
        print(f"  {lk:<2}  {e['type']:<2}  {e['sectors_used']:>4}  T{e['tslist_track']:02d}/S{e['tslist_sector']:02d}  {e['name']}")
    return data, vtoc, entries

if __name__ == '__main__':
    main(sys.argv[1])
