// rea decompile_all
// name: entry
// address: 0x9276
// body: available
// range: 0x9276-0x92bf inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 432c053a46a2021a0d19af5e0c84faf741edcbfbef55eb55089e00d7252d6b58
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


byte entry(void)

{
  byte bVar1;
  char cVar2;
  bool bVar3;
  byte bVar4;
  byte bVar5;
  
  bVar4 = 1;
  DAT_9273 = DAT_9273 + '\x01';
  cVar2 = DAT_9274;
  do {
    bVar1 = DAT_9271;
    bVar5 = DAT_9270 >> 7;
    DAT_9270 = DAT_9270 << 1 | bVar4;
    bVar4 = (char)DAT_9271 >> 7;
    DAT_9271 = DAT_9271 << 1 | bVar5;
    bVar3 = cVar2 == '\0';
    if (!bVar3) {
      cVar2 = cVar2 + -1;
      bVar3 = cVar2 == '\0';
    }
    if ((bVar3) && ((char)bVar1 < '\0')) {
      cVar2 = DAT_9274;
    }
    bVar4 = (((bVar4 & 1) << 5 ^ DAT_9271) & 0x3f) >> 5;
    bVar1 = DAT_9275;
    if ((DAT_9275 != 0) &&
       (((char)DAT_9275 < '\0' ||
        ((bVar1 = 0, DAT_9274 != '\0' && (DAT_9274 = DAT_9274 + -1, bVar1 = DAT_9275, DAT_9275 == 0)
         ))))) {
      DAT_9274 = DAT_9274 + '\x01';
      bVar1 = DAT_9275 & 0x7f;
    }
    DAT_9272 = DAT_9272 + -1;
  } while ((DAT_9272 != '\0') || (DAT_9273 = DAT_9273 + -1, DAT_9273 != '\0'));
  return bVar1;
}

