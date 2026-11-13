// rea decompile_all
// name: thunk_FUN_611c
// address: 0x6000
// body: available
// range: 0x6000-0x6002 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


undefined1 thunk_FUN_611c(undefined1 param_1)

{
  byte bVar1;
  char in_N;
  char in_V;
  char in_B;
  char in_D;
  char in_I;
  char in_Z;
  byte in_C;
  byte bStack0000;
  
  bStack0000 = in_N << 7 | 0x20U | in_V << 6 | in_B << 4 | in_D << 3 | in_I << 2 | in_Z << 1 | in_C;
  bVar1 = 0x62;
  do {
    (&DAT_6013)[bVar1] = *(undefined1 *)(ushort)(byte)(bVar1 + 0x5f);
    bVar1 = bVar1 - 1;
  } while (bVar1 != 0);
  FUN_6140();
  bVar1 = 0x62;
  do {
    *(undefined1 *)(ushort)(byte)(bVar1 + 0x5f) = (&DAT_6013)[bVar1];
    bVar1 = bVar1 - 1;
  } while (bVar1 != 0);
  return param_1;
}

