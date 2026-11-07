// rea decompile_all
// name: entry
// address: 0x9300
// body: available
// range: 0x9300-0x93f1 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: fee97e4f086863062136a59317205392a920e4e7221c6b712a5f685f65a7fa45
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


byte entry(byte param_1,undefined1 param_2)

{
  char cVar1;
  byte bVar2;
  byte bVar3;
  byte bVar4;
  bool bVar5;
  byte bStack0000;
  
  bStack0000 = param_1;
  func_0xff58();
  DAT_0037 = uRAM01ff;
  DAT_0036 = 0x3c;
  DAT_c057 = 0x3c;
  DAT_c052 = 0x3c;
  DAT_c055 = 0x3c;
  DAT_03ce = DAT_00e6;
  if (DAT_00e6 != 0x40) {
    DAT_03ce = 0x20;
    DAT_c054 = 0x20;
  }
  DAT_03cd = 0;
  DAT_03cf = 0x7f;
  DAT_03cc = 0x68;
  DAT_004e = param_2;
  DAT_c050 = DAT_03ce;
  if (bStack0000 != 0x8d) {
    if (bStack0000 == 0x8c) {
      bVar4 = 0;
      DAT_002a = (byte *)((ushort)DAT_03ce << 8);
      do {
        bVar2 = DAT_03cd;
        if (DAT_03cd != 0xff) {
          bVar2 = bVar4;
        }
        do {
          DAT_002a[bVar4] = bVar2;
          bVar4 = bVar4 + 1;
        } while (bVar4 != 0);
        cVar1 = DAT_002a._1_1_ + '\x01';
        DAT_002a = (byte *)CONCAT11(cVar1,DAT_002a._0_1_);
      } while ((byte)(cVar1 - DAT_03ce) != ' ');
      bVar5 = false;
      DAT_0024 = 0;
      DAT_0025 = 0;
    }
    else {
      bVar4 = DAT_0025 >> 1 & 0xc;
      DAT_002a = (byte *)CONCAT11(DAT_0025 >> 1 & 3 | DAT_03ce,
                                  (bVar4 << 3 | bVar4 << 1 | DAT_0025 << 7) + DAT_0024);
      DAT_0026 = CONCAT11(((bStack0000 & 0x7f) >> 6 | 0x34) << 1 | (bStack0000 & 0x3f) >> 5,
                          bStack0000 << 3);
      bVar4 = 0;
      do {
        bVar2 = *(byte *)(DAT_0026 + (ushort)bVar4);
        bVar3 = DAT_03cd;
        if ((DAT_03cd != 0) && (DAT_03cd != 0xff)) {
          bVar3 = *DAT_002a;
        }
        DAT_004f = bVar4;
        *DAT_002a = bVar3;
        *DAT_002a = bVar2 ^ *DAT_002a;
        DAT_002a = (byte *)CONCAT11(DAT_002a._1_1_ + '\x04',DAT_002a._0_1_);
        bVar4 = DAT_004f + 1;
      } while (bVar4 != 8);
      DAT_0024 = DAT_0024 + 1;
      bVar5 = DAT_0021 <= DAT_0024;
      bStack0000 = bStack0000 & 0x7f;
    }
    if (!bVar5) {
      return bStack0000;
    }
  }
  DAT_0024 = DAT_0020;
  DAT_0025 = DAT_0025 + 1;
  if (DAT_0023 <= DAT_0025) {
    DAT_0025 = DAT_0022;
  }
  return bStack0000;
}

