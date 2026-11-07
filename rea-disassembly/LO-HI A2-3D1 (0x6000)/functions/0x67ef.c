// rea decompile_all
// name: FUN_67ef
// address: 0x67ef
// body: available
// range: 0x67ef-0x6847 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


byte FUN_67ef(void)

{
  byte bVar1;
  byte bVar2;
  bool bVar3;
  
  bVar2 = 0;
  if ((char)(DAT_0061 + DAT_0065 + CARRY1(DAT_0060,DAT_0064)) < '\0') {
    if (!CARRY1(DAT_0061,DAT_0065)) goto LAB_6802;
  }
  else if (CARRY1(DAT_0061,DAT_0065)) {
LAB_6802:
    bVar2 = 0x40;
  }
  bVar1 = (DAT_0065 - DAT_0061) -
          (((DAT_0060 & (~DAT_0064 | DAT_0064 - DAT_0060) | DAT_0064 - DAT_0060 & ~DAT_0064) & 0x80)
          == 0);
  bVar3 = ((DAT_0065 & ~DAT_0061 & ~bVar1 | ~DAT_0065 & DAT_0061 & bVar1) & 0x80) != 0;
  if ((char)bVar1 < '\0') {
    if (!bVar3) goto LAB_6815;
  }
  else if (bVar3) {
LAB_6815:
    bVar2 = bVar2 | 0x20;
  }
  if ((char)(DAT_0063 + DAT_0065 + CARRY1(DAT_0062,DAT_0064)) < '\0') {
    if (!CARRY1(DAT_0063,DAT_0065)) goto LAB_682a;
  }
  else if (CARRY1(DAT_0063,DAT_0065)) {
LAB_682a:
    bVar2 = bVar2 | 0x10;
  }
  bVar1 = (DAT_0065 - DAT_0063) -
          (((DAT_0062 & (~DAT_0064 | DAT_0064 - DAT_0062) | DAT_0064 - DAT_0062 & ~DAT_0064) & 0x80)
          == 0);
  bVar3 = ((DAT_0065 & ~DAT_0063 & ~bVar1 | ~DAT_0065 & DAT_0063 & bVar1) & 0x80) != 0;
  if (-1 < (char)bVar1) {
    if (!bVar3) {
      DAT_0066 = bVar2;
      return bVar1;
    }
    if (bVar3) goto LAB_683f;
  }
  if (bVar3) {
    DAT_0066 = bVar2;
    return bVar1;
  }
LAB_683f:
  DAT_0066 = bVar2 | 8;
  return bVar2 | 8;
}

