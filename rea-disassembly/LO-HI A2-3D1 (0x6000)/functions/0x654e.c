// rea decompile_all
// name: FUN_654e
// address: 0x654e
// body: available
// range: 0x654e-0x672a inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


void FUN_654e(char param_1)

{
  byte bVar1;
  char cVar2;
  char cVar3;
  
  DAT_0060 = FUN_64f8(DAT_0096);
  DAT_0061 = param_1;
  DAT_0062 = FUN_64f8(DAT_0097);
  DAT_0063 = param_1;
  DAT_0064 = FUN_64f8(DAT_0098);
  DAT_0065 = param_1;
  DAT_0066 = FUN_64fb(DAT_0096);
  DAT_0067 = param_1;
  DAT_0068 = FUN_64fb(DAT_0097);
  DAT_0069 = param_1;
  DAT_006a = FUN_64fb(DAT_0098);
  DAT_006b = param_1;
  FUN_633d(0x6c,0x6a,0x68);
  FUN_633d(0x6e,100,0x62);
  FUN_633d(0x70,0x6a,0x62);
  FUN_633d(0x72,100,0x68);
  FUN_633d(0x74,0x60,0x6e);
  FUN_633d(0x76,0x60,0x72);
  FUN_633d(0xb3,0x70,0x60);
  FUN_633d(0xb5,0x60,0x6c);
  DAT_007e = DAT_006c + DAT_0074;
  DAT_007f = DAT_006d + DAT_0075 + CARRY1(DAT_006c,DAT_0074);
  DAT_0080 = DAT_0076 - DAT_0070;
  DAT_0081 = (DAT_0077 - DAT_0071) -
             (((DAT_0070 & (~DAT_0076 | DAT_0080) | DAT_0080 & ~DAT_0076) & 0x80) == 0);
  FUN_633d(0x82,100,0x66);
  FUN_633d(0x84,0x62,0x66);
  FUN_633d(0x86,0x66,0x68);
  DAT_0088 = -DAT_0060;
  DAT_0089 = -(((DAT_0060 | DAT_0088) & 0x80) == 0) - DAT_0061;
  DAT_008a = DAT_00b3 - DAT_0072;
  DAT_008b = (DAT_00b4 - DAT_0073) -
             (((DAT_0072 & (~DAT_00b3 | DAT_008a) | DAT_008a & ~DAT_00b3) & 0x80) == 0);
  DAT_008c = DAT_006e + DAT_00b5;
  DAT_008d = DAT_006f + DAT_00b6 + CARRY1(DAT_006e,DAT_00b5);
  bVar1 = FUN_633d(0x8e,0x6a,0x66);
  if ((DAT_600f != '\x7f') || (bVar1 = DAT_600e, DAT_600e != 0xff)) {
    DAT_0079 = DAT_600f;
    DAT_007a = DAT_007e;
    DAT_007b = DAT_007f;
    DAT_0078 = bVar1;
    DAT_007e = FUN_635c();
    DAT_0078 = DAT_0084;
    DAT_0079 = DAT_0085;
    DAT_007a = DAT_600e;
    DAT_007b = DAT_600f;
    cVar2 = DAT_600f;
    DAT_0084 = FUN_635c();
    DAT_0078 = DAT_008a;
    DAT_0079 = DAT_008b;
    DAT_007a = DAT_600e;
    DAT_007b = DAT_600f;
    cVar3 = DAT_600f;
    DAT_0085 = cVar2;
    bVar1 = FUN_635c();
    DAT_008a = bVar1;
    DAT_008b = cVar3;
  }
  if ((DAT_6011 != '\x7f') || (bVar1 = DAT_6010, DAT_6010 != 0xff)) {
    DAT_0079 = DAT_6011;
    DAT_007a = DAT_0080;
    DAT_007b = DAT_0081;
    DAT_0078 = bVar1;
    DAT_0080 = FUN_635c();
    DAT_0078 = DAT_6010;
    DAT_0079 = DAT_6011;
    DAT_007a = DAT_0086;
    DAT_007b = DAT_0087;
    DAT_0086 = FUN_635c();
    DAT_0078 = DAT_6010;
    DAT_0079 = DAT_6011;
    DAT_007a = DAT_008c;
    DAT_007b = DAT_008d;
    bVar1 = FUN_635c();
    DAT_008c = bVar1;
  }
  if ((DAT_6013 != '\x7f') || (bVar1 = DAT_6012, DAT_6012 != 0xff)) {
    DAT_0079 = DAT_6013;
    DAT_007a = DAT_0082;
    DAT_007b = DAT_0083;
    DAT_0078 = bVar1;
    DAT_0082 = FUN_635c();
    DAT_0078 = DAT_6012;
    DAT_0079 = DAT_6013;
    DAT_007a = DAT_0088;
    DAT_007b = DAT_0089;
    DAT_0088 = FUN_635c();
    DAT_0078 = DAT_6012;
    DAT_0079 = DAT_6013;
    DAT_007a = DAT_008e;
    DAT_007b = DAT_008f;
    DAT_008e = FUN_635c();
  }
  return;
}

