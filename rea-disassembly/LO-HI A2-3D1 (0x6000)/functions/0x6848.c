// rea decompile_all
// name: FUN_6848
// address: 0x6848
// body: available
// range: 0x6848-0x68a0 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


byte FUN_6848(void)

{
  byte bVar1;
  byte bVar2;
  bool bVar3;
  
  bVar2 = 0;
  if ((char)(DAT_0069 + DAT_006d + CARRY1(DAT_0068,DAT_006c)) < '\0') {
    if (!CARRY1(DAT_0069,DAT_006d)) goto LAB_685b;
  }
  else if (CARRY1(DAT_0069,DAT_006d)) {
LAB_685b:
    bVar2 = 0x40;
  }
  bVar1 = (DAT_006d - DAT_0069) -
          (((DAT_0068 & (~DAT_006c | DAT_006c - DAT_0068) | DAT_006c - DAT_0068 & ~DAT_006c) & 0x80)
          == 0);
  bVar3 = ((DAT_006d & ~DAT_0069 & ~bVar1 | ~DAT_006d & DAT_0069 & bVar1) & 0x80) != 0;
  if ((char)bVar1 < '\0') {
    if (!bVar3) goto LAB_686e;
  }
  else if (bVar3) {
LAB_686e:
    bVar2 = bVar2 | 0x20;
  }
  if ((char)(DAT_006b + DAT_006d + CARRY1(DAT_006a,DAT_006c)) < '\0') {
    if (!CARRY1(DAT_006b,DAT_006d)) goto LAB_6883;
  }
  else if (CARRY1(DAT_006b,DAT_006d)) {
LAB_6883:
    bVar2 = bVar2 | 0x10;
  }
  bVar1 = (DAT_006d - DAT_006b) -
          (((DAT_006a & (~DAT_006c | DAT_006c - DAT_006a) | DAT_006c - DAT_006a & ~DAT_006c) & 0x80)
          == 0);
  bVar3 = ((DAT_006d & ~DAT_006b & ~bVar1 | ~DAT_006d & DAT_006b & bVar1) & 0x80) != 0;
  if (-1 < (char)bVar1) {
    if (!bVar3) {
      DAT_006e = bVar2;
      return bVar1;
    }
    if (bVar3) goto LAB_6898;
  }
  if (bVar3) {
    DAT_006e = bVar2;
    return bVar1;
  }
LAB_6898:
  DAT_006e = bVar2 | 8;
  return bVar2 | 8;
}

