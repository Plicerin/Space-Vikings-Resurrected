// rea decompile_all
// name: FUN_68a1
// address: 0x68a1
// body: available
// range: 0x68a1-0x68e9 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


void FUN_68a1(byte param_1,byte param_2)

{
  undefined1 uVar1;
  
  DAT_007a = *(undefined1 *)(param_2 + 4);
  DAT_007b = *(undefined1 *)(param_2 + 5);
  DAT_00a7 = param_1;
  DAT_00a8 = param_2;
  FUN_6468(*(undefined1 *)(param_2 + 1),*(undefined1 *)(ushort)param_2);
  uVar1 = FUN_691e(DAT_0079,0x45);
  *(undefined1 *)(ushort)DAT_00a7 = uVar1;
  DAT_007a = *(undefined1 *)(DAT_00a8 + 4);
  DAT_007b = *(undefined1 *)(DAT_00a8 + 5);
  FUN_6468(*(undefined1 *)(DAT_00a8 + 3),*(undefined1 *)(ushort)(byte)(DAT_00a8 + 2));
  uVar1 = FUN_691e(DAT_0079,0x5e);
  *(undefined1 *)(DAT_00a7 + 1) = uVar1;
  return;
}

