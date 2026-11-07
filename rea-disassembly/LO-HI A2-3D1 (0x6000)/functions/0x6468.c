// rea decompile_all
// name: FUN_6468
// address: 0x6468
// body: available
// range: 0x6468-0x6486 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Ghidra Listing reports a terminal call at 0x6475 to 0x64a5 FUN_64a5 (external=false, thunk=false, hasNoReturn=false); fallthrough is excluded by Ghidra's flow model. The reason for the terminal flow is not established by this observation.; Ghidra Listing reports a terminal call at 0x6484 to 0x64b6 FUN_64b6 (external=false, thunk=false, hasNoReturn=false); fallthrough is excluded by Ghidra's flow model. The reason for the terminal flow is not established by this observation.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


void FUN_6468(byte param_1,byte param_2)

{
  char cVar1;
  char cVar2;
  byte bVar3;
  byte bVar4;
  
  if ((char)param_1 < '\0') {
    FUN_6487();
    if (DAT_007b < '\0') {
      FUN_6495();
      FUN_64b6();
      return;
    }
    FUN_64b6();
    bVar4 = DAT_0078 | -DAT_0078;
    DAT_0078 = -DAT_0078;
    DAT_0079 = -((bVar4 & 0x80) == 0) - DAT_0079;
    return;
  }
  if (DAT_007b < '\0') {
    FUN_6495();
    FUN_64a5();
    return;
  }
  cVar2 = '\x0f';
  DAT_00a5 = param_2;
  do {
    bVar4 = DAT_00a5 - DAT_007a;
    for (cVar1 = (param_1 - DAT_007b) -
                 (((DAT_007a & (~DAT_00a5 | bVar4) | bVar4 & ~DAT_00a5) & 0x80) == 0); cVar1 < '\0';
        cVar1 = (cVar1 << 1 | bVar3) + DAT_007b + CARRY1(DAT_00a5,DAT_007a)) {
      bVar3 = DAT_0078 >> 7;
      DAT_0078 = DAT_0078 << 1;
      DAT_0079 = DAT_0079 << 1 | bVar3;
      bVar3 = bVar4 >> 7;
      DAT_00a5 = bVar4 * '\x02';
      cVar2 = cVar2 + -1;
      if (cVar2 == '\0') goto LAB_64ed;
      bVar4 = DAT_00a5 + DAT_007a;
    }
    bVar3 = DAT_0078 >> 7;
    DAT_0078 = DAT_0078 << 1 | 1;
    DAT_0079 = DAT_0079 << 1 | bVar3;
    DAT_00a5 = bVar4 << 1;
    param_1 = cVar1 << 1 | bVar4 >> 7;
    cVar2 = cVar2 + -1;
  } while (cVar2 != '\0');
LAB_64ed:
  bVar4 = DAT_0078 >> 7;
  DAT_0078 = DAT_0078 * '\x02';
  DAT_0079 = DAT_0079 << 1 | bVar4;
  if ((char)DAT_0079 < '\0') {
    DAT_0078 = DAT_0078 + -1;
    DAT_0079 = DAT_0079 - 1;
  }
  return;
}

