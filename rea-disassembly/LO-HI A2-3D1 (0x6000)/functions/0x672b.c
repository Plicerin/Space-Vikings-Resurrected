// rea decompile_all
// name: FUN_672b
// address: 0x672b
// body: available
// range: 0x672b-0x67d3 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


void FUN_672b(undefined1 param_1)

{
  byte bVar1;
  
  DAT_00ab = *(byte *)(DAT_009b + 1) - DAT_0090;
  bVar1 = ~*(byte *)(DAT_009b + 1);
  DAT_00ac = (*(char *)(DAT_009b + 2) - DAT_0091) -
             (((DAT_0090 & (bVar1 | DAT_00ab) | DAT_00ab & bVar1) & 0x80) == 0);
  DAT_00ad = *(byte *)(DAT_009b + 3) - DAT_0092;
  bVar1 = ~*(byte *)(DAT_009b + 3);
  DAT_00ae = (*(char *)(DAT_009b + 4) - DAT_0093) -
             (((DAT_0092 & (bVar1 | DAT_00ad) | DAT_00ad & bVar1) & 0x80) == 0);
  DAT_00af = *(byte *)(DAT_009b + 5) - DAT_0094;
  bVar1 = ~*(byte *)(DAT_009b + 5);
  DAT_00b0 = (*(char *)(DAT_009b + 6) - DAT_0095) -
             (((DAT_0094 & (bVar1 | DAT_00af) | DAT_00af & bVar1) & 0x80) == 0);
  DAT_00b2 = param_1;
  FUN_633d(0xa7,0xab,0x7e);
  FUN_633d(0xa9,0xad,0x84);
  DAT_0078 = DAT_00af;
  DAT_0079 = DAT_00b0;
  DAT_007a = DAT_008a;
  DAT_007b = DAT_008b;
  FUN_635c();
  FUN_67d4();
  FUN_633d(0xa7,0xab,0x80);
  FUN_633d(0xa9,0xad,0x86);
  DAT_0078 = DAT_00af;
  DAT_0079 = DAT_00b0;
  DAT_007a = DAT_008c;
  DAT_007b = DAT_008d;
  FUN_635c();
  FUN_67d4();
  FUN_633d(0xa7,0xab,0x82);
  FUN_633d(0xa9,0xad,0x88);
  DAT_0078 = DAT_00af;
  DAT_0079 = DAT_00b0;
  DAT_007a = DAT_008e;
  DAT_007b = DAT_008f;
  FUN_635c();
  FUN_67d4();
  return;
}

