// rea decompile_all
// name: FUN_6979
// address: 0x6979
// body: available
// range: 0x6979-0x6b91 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Ghidra Listing reports a terminal call at 0x6a0a to 0x6848 FUN_6848 (external=false, thunk=false, hasNoReturn=false); fallthrough is excluded by Ghidra's flow model. The reason for the terminal flow is not established by this observation.; Ghidra Listing reports a terminal call at 0x6a8f to 0x6848 FUN_6848 (external=false, thunk=false, hasNoReturn=false); fallthrough is excluded by Ghidra's flow model. The reason for the terminal flow is not established by this observation.; Ghidra Listing reports a terminal call at 0x6b0a to 0x6848 FUN_6848 (external=false, thunk=false, hasNoReturn=false); fallthrough is excluded by Ghidra's flow model. The reason for the terminal flow is not established by this observation.; Ghidra Listing reports a terminal call at 0x6b8f to 0x6848 FUN_6848 (external=false, thunk=false, hasNoReturn=false); fallthrough is excluded by Ghidra's flow model. The reason for the terminal flow is not established by this observation.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


void FUN_6979(void)

{
  byte bVar1;
  byte bVar2;
  char cVar3;
  bool bVar4;
  
  if ((DAT_006e & 0xbf) == 0) {
    bVar2 = DAT_0064 - DAT_006c;
    bVar1 = DAT_0068 - DAT_0060;
    DAT_007a = bVar1 - bVar2;
    DAT_007b = (((DAT_0069 - DAT_0061) -
                (((DAT_0060 & (~DAT_0068 | bVar1) | bVar1 & ~DAT_0068) & 0x80) == 0)) -
               ((DAT_0065 - DAT_006d) -
               (((DAT_006c & (~DAT_0064 | bVar2) | bVar2 & ~DAT_0064) & 0x80) == 0))) -
               (((bVar2 & (~bVar1 | DAT_007a) | DAT_007a & ~bVar1) & 0x80) == 0);
    FUN_6468(DAT_006d + DAT_0069 + CARRY1(DAT_006c,DAT_0068),DAT_006c + DAT_0068);
    DAT_007a = DAT_0062 - DAT_006a;
    DAT_007b = (DAT_0063 - DAT_006b) -
               (((DAT_006a & (~DAT_0062 | DAT_007a) | DAT_007a & ~DAT_0062) & 0x80) == 0);
    DAT_00a7 = DAT_0078;
    DAT_00a8 = DAT_0079;
    bVar2 = FUN_635c();
    bVar4 = CARRY1(bVar2,DAT_006a);
    DAT_006a = bVar2 + DAT_006a;
    DAT_006b = DAT_0079 + DAT_006b + bVar4;
    DAT_007a = DAT_0064 - DAT_006c;
    DAT_007b = (DAT_0065 - DAT_006d) -
               (((DAT_006c & (~DAT_0064 | DAT_007a) | DAT_007a & ~DAT_0064) & 0x80) == 0);
    DAT_0078 = DAT_00a7;
    DAT_0079 = DAT_00a8;
    cVar3 = DAT_00a8;
    bVar2 = FUN_635c();
    bVar4 = CARRY1(bVar2,DAT_006c);
    DAT_006c = bVar2 + DAT_006c;
    DAT_006d = cVar3 + DAT_006d + bVar4;
    DAT_0069 = DAT_006d ^ 0xff;
    DAT_0068 = (DAT_006c ^ 0xff) + 1;
    if (DAT_0068 == '\0') {
      DAT_0069 = DAT_0069 + 1;
    }
    FUN_6848();
    return;
  }
  if ((DAT_006e & 0x9f) != 0) {
    if ((DAT_006e & 0x8f) != 0) {
      bVar2 = DAT_0064 - DAT_006c;
      bVar1 = DAT_0062 - DAT_006a;
      DAT_007a = bVar1 - bVar2;
      DAT_007b = (((DAT_0063 - DAT_006b) -
                  (((DAT_006a & (~DAT_0062 | bVar1) | bVar1 & ~DAT_0062) & 0x80) == 0)) -
                 ((DAT_0065 - DAT_006d) -
                 (((DAT_006c & (~DAT_0064 | bVar2) | bVar2 & ~DAT_0064) & 0x80) == 0))) -
                 (((bVar2 & (~bVar1 | DAT_007a) | DAT_007a & ~bVar1) & 0x80) == 0);
      bVar2 = DAT_006c - DAT_006a;
      FUN_6468((DAT_006d - DAT_006b) -
               (((DAT_006a & (~DAT_006c | bVar2) | bVar2 & ~DAT_006c) & 0x80) == 0),bVar2);
      DAT_007a = DAT_0060 - DAT_0068;
      DAT_007b = (DAT_0061 - DAT_0069) -
                 (((DAT_0068 & (~DAT_0060 | DAT_007a) | DAT_007a & ~DAT_0060) & 0x80) == 0);
      DAT_00a7 = DAT_0078;
      DAT_00a8 = DAT_0079;
      bVar2 = FUN_635c();
      bVar4 = CARRY1(bVar2,DAT_0068);
      DAT_0068 = bVar2 + DAT_0068;
      DAT_0069 = DAT_0079 + DAT_0069 + bVar4;
      DAT_007a = DAT_0064 - DAT_006c;
      DAT_007b = (DAT_0065 - DAT_006d) -
                 (((DAT_006c & (~DAT_0064 | DAT_007a) | DAT_007a & ~DAT_0064) & 0x80) == 0);
      DAT_0078 = DAT_00a7;
      DAT_0079 = DAT_00a8;
      cVar3 = DAT_00a8;
      bVar2 = FUN_635c();
      DAT_006a = bVar2 + DAT_006c;
      DAT_006b = cVar3 + DAT_006d + CARRY1(bVar2,DAT_006c);
      DAT_006c = DAT_006a;
      DAT_006d = DAT_006b;
      FUN_6848();
      return;
    }
    bVar2 = DAT_0064 - DAT_006c;
    bVar1 = DAT_006a - DAT_0062;
    DAT_007a = bVar1 - bVar2;
    DAT_007b = (((DAT_006b - DAT_0063) -
                (((DAT_0062 & (~DAT_006a | bVar1) | bVar1 & ~DAT_006a) & 0x80) == 0)) -
               ((DAT_0065 - DAT_006d) -
               (((DAT_006c & (~DAT_0064 | bVar2) | bVar2 & ~DAT_0064) & 0x80) == 0))) -
               (((bVar2 & (~bVar1 | DAT_007a) | DAT_007a & ~bVar1) & 0x80) == 0);
    FUN_6468(DAT_006d + DAT_006b + CARRY1(DAT_006c,DAT_006a),DAT_006c + DAT_006a);
    DAT_007a = DAT_0060 - DAT_0068;
    DAT_007b = (DAT_0061 - DAT_0069) -
               (((DAT_0068 & (~DAT_0060 | DAT_007a) | DAT_007a & ~DAT_0060) & 0x80) == 0);
    DAT_00a7 = DAT_0078;
    DAT_00a8 = DAT_0079;
    bVar2 = FUN_635c();
    bVar4 = CARRY1(bVar2,DAT_0068);
    DAT_0068 = bVar2 + DAT_0068;
    DAT_0069 = DAT_0079 + DAT_0069 + bVar4;
    DAT_007a = DAT_0064 - DAT_006c;
    DAT_007b = (DAT_0065 - DAT_006d) -
               (((DAT_006c & (~DAT_0064 | DAT_007a) | DAT_007a & ~DAT_0064) & 0x80) == 0);
    DAT_0078 = DAT_00a7;
    DAT_0079 = DAT_00a8;
    cVar3 = DAT_00a8;
    bVar2 = FUN_635c();
    bVar4 = CARRY1(bVar2,DAT_006c);
    DAT_006c = bVar2 + DAT_006c;
    DAT_006d = cVar3 + DAT_006d + bVar4;
    DAT_006b = DAT_006d ^ 0xff;
    DAT_006a = (DAT_006c ^ 0xff) + 1;
    if (DAT_006a == '\0') {
      DAT_006b = DAT_006b + 1;
    }
    FUN_6848();
    return;
  }
  bVar2 = DAT_0064 - DAT_006c;
  bVar1 = DAT_0060 - DAT_0068;
  DAT_007a = bVar1 - bVar2;
  DAT_007b = (((DAT_0061 - DAT_0069) -
              (((DAT_0068 & (~DAT_0060 | bVar1) | bVar1 & ~DAT_0060) & 0x80) == 0)) -
             ((DAT_0065 - DAT_006d) -
             (((DAT_006c & (~DAT_0064 | bVar2) | bVar2 & ~DAT_0064) & 0x80) == 0))) -
             (((bVar2 & (~bVar1 | DAT_007a) | DAT_007a & ~bVar1) & 0x80) == 0);
  bVar2 = DAT_006c - DAT_0068;
  FUN_6468((DAT_006d - DAT_0069) -
           (((DAT_0068 & (~DAT_006c | bVar2) | bVar2 & ~DAT_006c) & 0x80) == 0),bVar2);
  DAT_007a = DAT_0064 - DAT_006c;
  DAT_007b = (DAT_0065 - DAT_006d) -
             (((DAT_006c & (~DAT_0064 | DAT_007a) | DAT_007a & ~DAT_0064) & 0x80) == 0);
  DAT_00a7 = DAT_0078;
  DAT_00a8 = DAT_0079;
  bVar2 = FUN_635c();
  DAT_0068 = bVar2 + DAT_006c;
  DAT_0069 = DAT_0079 + DAT_006d + CARRY1(bVar2,DAT_006c);
  DAT_007a = DAT_0062 - DAT_006a;
  DAT_007b = (DAT_0063 - DAT_006b) -
             (((DAT_006a & (~DAT_0062 | DAT_007a) | DAT_007a & ~DAT_0062) & 0x80) == 0);
  DAT_0078 = DAT_00a7;
  DAT_0079 = DAT_00a8;
  cVar3 = DAT_00a8;
  DAT_006c = DAT_0068;
  DAT_006d = DAT_0069;
  bVar2 = FUN_635c();
  bVar4 = CARRY1(bVar2,DAT_006a);
  DAT_006a = bVar2 + DAT_006a;
  DAT_006b = cVar3 + DAT_006b + bVar4;
  FUN_6848();
  return;
}

