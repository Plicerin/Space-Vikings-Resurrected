// rea decompile_all
// name: FUN_966a
// address: 0x966a
// body: available
// range: 0x966a-0x96a4 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: ead9056979033eced813fc223fcefb3f09c8f2a57b1c27ce3b53d43b7cc36e7c
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


void FUN_966a(void)

{
  bool bVar1;
  
  entry = 1;
                    /* WARNING: Read-only address (RAM,0x9773) is written */
  uRAM9773 = 0x51;
  bVar1 = DAT_953a != '\0';
  if (bVar1) {
    func_0x9754(0);
                    /* WARNING: Read-only address (RAM,0x9773) is written */
    uRAM9773 = 0x5a;
    func_0x9754(4);
  }
  else {
    func_0x9754(2);
                    /* WARNING: Read-only address (RAM,0x9773) is written */
    uRAM9773 = 0x5a;
    func_0x9754(6);
  }
  DAT_953a = !bVar1;
  return;
}

