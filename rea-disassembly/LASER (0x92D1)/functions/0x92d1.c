// rea decompile_all
// name: entry
// address: 0x92d1
// body: available
// range: 0x92d1-0x92e6 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 211e2b7e2cb229002694208d07df30d1bd6513bc086d244eb4e486a094bbc4c8
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


void entry(void)

{
  byte bVar1;
  byte bVar2;
  char cVar3;
  bool bVar4;
  
  cVar3 = '\x0e';
  do {
    bVar2 = 0;
    do {
      bVar4 = false;
      bVar1 = bVar2;
      do {
        DAT_c030 = (bVar1 - 1) - !bVar4;
        bVar4 = (DAT_c030 & ~bVar1 & 0x80) != 0;
        bVar1 = DAT_c030;
      } while (DAT_c030 != 0);
      bVar2 = bVar2 + 1;
    } while (bVar2 != 0x8c);
    cVar3 = cVar3 + -1;
  } while (cVar3 != '\0');
  return;
}

