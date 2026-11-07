// rea decompile_all
// name: entry
// address: 0x9023
// body: available
// range: 0x9023-0x90f1 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: e2ad6d0b98605409557bb76b135154c8b052fb1eb55bb76a896ed638c8d59746
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Ghidra Listing reports a terminal call at 0x90ef to 0x921e FUN_921e (external=false, thunk=false, hasNoReturn=false); fallthrough is excluded by Ghidra's flow model. The reason for the terminal flow is not established by this observation.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


void entry(void)

{
  if ((DAT_95fd < 0xaa) && (DAT_95fd < 0x5a)) {
    FUN_91c5();
    if ((DAT_95fd < 0x46) && ((FUN_91c5(), DAT_95fd < 0x32 && (FUN_91c5(), DAT_95fd < 0x1f)))) {
      FUN_91c5();
    }
  }
  else if ((((0xa9 < DAT_95fd) && (FUN_918c(), 0xbd < DAT_95fd)) && (FUN_918c(), 0xd1 < DAT_95fd))
          && (FUN_918c(), 0xe5 < DAT_95fd)) {
    FUN_918c();
  }
  if (DAT_95fe < 0x5a) {
    FUN_91d7();
    if (((DAT_95fe < 0x46) && (FUN_91d7(), DAT_95fe < 0x32)) && (FUN_91d7(), DAT_95fe < 0x1e)) {
      FUN_91d7();
    }
  }
  else if (((0xa9 < DAT_95fe) && (FUN_919e(), 0xbd < DAT_95fe)) &&
          ((FUN_919e(), 0xd1 < DAT_95fe && (FUN_919e(), 0xe5 < DAT_95fe)))) {
    FUN_919e();
  }
  FUN_90f2();
  FUN_912e();
  FUN_921e();
  return;
}

