// rea decompile_all
// name: FUN_635c
// address: 0x635c
// body: available
// range: 0x635c-0x6467 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


byte FUN_635c(void)

{
  byte bVar1;
  byte bVar2;
  byte bVar3;
  byte bVar4;
  byte bVar5;
  byte bVar6;
  byte bVar7;
  byte bVar8;
  bool bVar9;
  
  bVar1 = DAT_0079 ^ DAT_007b;
  if (-1 < (char)DAT_0079) {
    DAT_0078 = DAT_0078 ^ 0xff;
    DAT_0079 = DAT_0079 ^ 0xff;
    if ((char)DAT_0079 < '\0') goto LAB_637b;
  }
  if (DAT_0078 == 0) {
    DAT_0079 = DAT_0079 - 1;
  }
  DAT_0078 = DAT_0078 - 1;
LAB_637b:
  if ((char)DAT_007b < '\0') {
    DAT_007b = -(((DAT_007a | -DAT_007a) & 0x80) == 0) - DAT_007b;
    DAT_007a = -DAT_007a;
  }
  bVar2 = DAT_007b;
  if ((DAT_0078 & 1) != 0) {
    bVar2 = 0;
  }
  bVar8 = bVar2 >> 1;
  bVar7 = DAT_0078 >> 2;
  if (!(bool)(DAT_0078 >> 1 & 1)) {
    bVar8 = bVar8 + DAT_007b;
  }
  bVar3 = bVar8 >> 1;
  if (!(bool)(bVar7 & 1)) {
    bVar3 = bVar3 + DAT_007b;
  }
  bVar4 = bVar3 >> 1;
  if (!(bool)((bVar7 & 2) >> 1)) {
    bVar4 = bVar4 + DAT_007b;
  }
  bVar5 = bVar4 >> 1;
  if (!(bool)((bVar7 & 4) >> 2)) {
    bVar5 = bVar5 + DAT_007b;
  }
  bVar6 = bVar5 >> 1;
  if (!(bool)((bVar7 & 8) >> 3)) {
    bVar6 = bVar6 + DAT_007b;
  }
  bVar6 = bVar6 >> 1;
  DAT_00a5 = 0;
  if (!(bool)((bVar7 & 0x10) >> 4)) {
    DAT_00a5 = DAT_007a;
    bVar6 = bVar6 + DAT_007b;
  }
  bVar7 = bVar6 >> 1;
  DAT_00a5 = DAT_00a5 >> 1 | bVar6 << 7;
  bVar9 = (bool)(DAT_0078 >> 7);
  DAT_0078 = (byte)((byte)((byte)((byte)((bVar2 & 1) << 6 | bVar8 << 7) >> 1 | bVar3 << 7) >> 1 |
                          bVar4 << 7) >> 1 | bVar5 << 7) >> 2;
  if (!bVar9) {
    bVar9 = CARRY1(DAT_00a5,DAT_007a);
    DAT_00a5 = DAT_00a5 + DAT_007a;
    bVar7 = bVar7 + DAT_007b + bVar9;
  }
  bVar2 = bVar7 >> 1;
  DAT_00a5 = DAT_00a5 >> 1 | bVar7 << 7;
  if (!(bool)(DAT_0079 & 1)) {
    bVar9 = CARRY1(DAT_00a5,DAT_007a);
    DAT_00a5 = DAT_00a5 + DAT_007a;
    bVar2 = bVar2 + DAT_007b + bVar9;
  }
  bVar8 = bVar2 >> 1;
  DAT_00a5 = DAT_00a5 >> 1 | bVar2 << 7;
  if (!(bool)(DAT_0079 >> 1 & 1)) {
    bVar9 = CARRY1(DAT_00a5,DAT_007a);
    DAT_00a5 = DAT_00a5 + DAT_007a;
    bVar8 = bVar8 + DAT_007b + bVar9;
  }
  bVar2 = bVar8 >> 1;
  DAT_00a5 = DAT_00a5 >> 1 | bVar8 << 7;
  if (!(bool)(DAT_0079 >> 2 & 1)) {
    bVar9 = CARRY1(DAT_00a5,DAT_007a);
    DAT_00a5 = DAT_00a5 + DAT_007a;
    bVar2 = bVar2 + DAT_007b + bVar9;
  }
  bVar8 = bVar2 >> 1;
  DAT_00a5 = DAT_00a5 >> 1 | bVar2 << 7;
  if (!(bool)(DAT_0079 >> 3 & 1)) {
    bVar9 = CARRY1(DAT_00a5,DAT_007a);
    DAT_00a5 = DAT_00a5 + DAT_007a;
    bVar8 = bVar8 + DAT_007b + bVar9;
  }
  bVar2 = bVar8 >> 1;
  DAT_00a5 = DAT_00a5 >> 1 | bVar8 << 7;
  if (!(bool)(DAT_0079 >> 4 & 1)) {
    bVar9 = CARRY1(DAT_00a5,DAT_007a);
    DAT_00a5 = DAT_00a5 + DAT_007a;
    bVar2 = bVar2 + DAT_007b + bVar9;
  }
  bVar8 = bVar2 >> 1;
  DAT_00a5 = DAT_00a5 >> 1 | bVar2 << 7;
  bVar2 = DAT_0079 >> 6;
  if (!(bool)(DAT_0079 >> 5 & 1)) {
    bVar9 = CARRY1(DAT_00a5,DAT_007a);
    DAT_00a5 = DAT_00a5 + DAT_007a;
    bVar8 = bVar8 + DAT_007b + bVar9;
  }
  bVar7 = bVar8 >> 1;
  DAT_00a5 = DAT_00a5 >> 1 | bVar8 << 7;
  DAT_0079 = DAT_0079 >> 7;
  if (!(bool)(bVar2 & 1)) {
    bVar9 = CARRY1(DAT_00a5,DAT_007a);
    DAT_00a5 = DAT_00a5 + DAT_007a;
    bVar7 = bVar7 + DAT_007b + bVar9;
  }
  DAT_00a5 = DAT_00a5 >> 1 | bVar7 << 7;
  if ((char)bVar1 < '\0') {
    DAT_00a5 = -DAT_00a5;
    DAT_00a6 = bVar7 >> 1;
  }
  return DAT_00a5;
}

