// rea decompile_all
// name: FUN_9460
// address: 0x9460
// body: available
// range: 0x9460-0x946d inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: c7ddf7665d6cd670b1b645865fdbb955aaf9dab74461aa33a497ddf4e58c0e68
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

char FUN_9460(void)

{
  char cVar1;
  byte bVar2;
  byte bVar3;
  bool bVar4;
  
  bVar2 = 0;
  bVar4 = false;
  do {
    *(undefined1 *)(DAT_0004 + (ushort)bVar2) = *(undefined1 *)(_DAT_0000 + (ushort)bVar2);
    bVar3 = bVar2 + 1;
    cVar1 = (bVar2 - 0x27) + bVar4;
    bVar2 = bVar3;
    bVar4 = 0x27 < bVar3;
  } while (0x27 >= bVar3);
  return cVar1;
}

