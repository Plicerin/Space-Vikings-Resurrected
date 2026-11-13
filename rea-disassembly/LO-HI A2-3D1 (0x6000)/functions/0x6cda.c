// rea decompile_all
// name: FUN_6cda
// address: 0x6cda
// body: available
// range: 0x6cda-0x6d43 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


void FUN_6cda(void)

{
  byte bVar1;
  
  bVar1 = 0;
  do {
    *(undefined1 *)(bVar1 + 0x2000) = 0;
    *(undefined1 *)(bVar1 + 0x2100) = 0;
    *(undefined1 *)(bVar1 + 0x2200) = 0;
    *(undefined1 *)(bVar1 + 0x2300) = 0;
    *(undefined1 *)(bVar1 + 0x2400) = 0;
    *(undefined1 *)(bVar1 + 0x2500) = 0;
    *(undefined1 *)(bVar1 + 0x2600) = 0;
    *(undefined1 *)(bVar1 + 0x2700) = 0;
    *(undefined1 *)(bVar1 + 0x2800) = 0;
    *(undefined1 *)(bVar1 + 0x2900) = 0;
    *(undefined1 *)(bVar1 + 0x2a00) = 0;
    *(undefined1 *)(bVar1 + 0x2b00) = 0;
    *(undefined1 *)(bVar1 + 0x2c00) = 0;
    *(undefined1 *)(bVar1 + 0x2d00) = 0;
    *(undefined1 *)(bVar1 + 0x2e00) = 0;
    *(undefined1 *)(bVar1 + 0x2f00) = 0;
    *(undefined1 *)(bVar1 + 0x3000) = 0;
    *(undefined1 *)(bVar1 + 0x3100) = 0;
    *(undefined1 *)(bVar1 + 0x3200) = 0;
    *(undefined1 *)(bVar1 + 0x3300) = 0;
    *(undefined1 *)(bVar1 + 0x3400) = 0;
    *(undefined1 *)(bVar1 + 0x3500) = 0;
    *(undefined1 *)(bVar1 + 0x3600) = 0;
    *(undefined1 *)(bVar1 + 0x3700) = 0;
    *(undefined1 *)(bVar1 + 0x3800) = 0;
    *(undefined1 *)(bVar1 + 0x3900) = 0;
    *(undefined1 *)(bVar1 + 0x3a00) = 0;
    *(undefined1 *)(bVar1 + 0x3b00) = 0;
    *(undefined1 *)(bVar1 + 0x3c00) = 0;
    *(undefined1 *)(bVar1 + 0x3d00) = 0;
    *(undefined1 *)(bVar1 + 0x3e00) = 0;
    *(undefined1 *)(bVar1 + 0x3f00) = 0;
    bVar1 = bVar1 + 3;
  } while (bVar1 != 0);
  return;
}

