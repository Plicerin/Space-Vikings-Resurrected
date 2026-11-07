// rea decompile_all
// name: FUN_6e9a
// address: 0x6e9a
// body: available
// range: 0x6e9a-0x6eac inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


undefined1 FUN_6e9a(char param_1,byte param_2)

{
  byte bVar1;
  byte bVar2;
  undefined1 uVar3;
  char cVar4;
  char cVar5;
  bool bVar6;
  undefined1 unaff_retaddr;
  
  bVar1 = DAT_00b8;
  do {
    cVar4 = param_1 + -1;
    if (cVar4 == '\0') {
      return 3;
    }
    bVar2 = bVar1 + DAT_00ba;
    if (CARRY1(bVar1,DAT_00ba)) {
      DAT_00b8 = bVar2 - DAT_00b9;
      bVar6 = ((DAT_00b9 & (~bVar2 | DAT_00b8) | DAT_00b8 & ~bVar2) & 0x80) != 0;
      bVar1 = FUN_6fe6(3);
      if (!bVar6) goto LAB_6ecd;
FUN_6ead:
      if ((char)(cVar4 + -1) == '\0') {
        return 0xc;
      }
      bVar1 = DAT_00b8 + DAT_00ba;
      if (CARRY1(DAT_00b8,DAT_00ba)) {
        DAT_00b8 = bVar1 - DAT_00b9;
        bVar1 = DAT_00b9 & (~bVar1 | DAT_00b8) | DAT_00b8 & ~bVar1;
        uVar3 = 0xc;
        cVar4 = cVar4 + -1;
        goto LAB_6edb;
      }
      if (bVar1 == 0) {
        return 3;
      }
      cVar4 = cVar4 + -2;
      if (cVar4 == '\0') {
        return 0x3c;
      }
      DAT_00b8 = bVar1 + DAT_00ba;
      if (!CARRY1(bVar1,DAT_00ba)) {
        bVar1 = 0x7c;
        goto LAB_6f11;
      }
      DAT_00b8 = DAT_00b8 - DAT_00b9;
      uVar3 = 0x3c;
LAB_6f32:
      FUN_6fe6(uVar3);
      bVar1 = 0x40;
    }
    else {
      cVar4 = param_1 + -2;
      if (cVar4 == '\0') {
        return 0xf;
      }
      bVar1 = bVar2 + DAT_00ba;
      bVar6 = true;
      if (CARRY1(bVar2,DAT_00ba)) {
LAB_6ecd:
        DAT_00b8 = (bVar1 - DAT_00b9) - !bVar6;
        bVar1 = DAT_00b9 & (~bVar1 | DAT_00b8) | DAT_00b8 & ~bVar1;
        uVar3 = 0xf;
LAB_6edb:
        cVar5 = (bVar1 & 0x80) != 0;
        bVar1 = FUN_6fe6(uVar3);
        if (!(bool)cVar5) goto LAB_6ee0;
        cVar4 = cVar4 + -1;
        if (cVar4 == '\0') {
          return 0x30;
        }
        bVar6 = CARRY1(DAT_00b8,DAT_00ba);
        DAT_00b8 = DAT_00b8 + DAT_00ba;
        if (bVar6) {
          DAT_00b8 = DAT_00b8 - DAT_00b9;
          uVar3 = 0x30;
          goto LAB_6f32;
        }
        bVar1 = 0x70;
      }
      else {
        cVar5 = '\0';
        if (bVar1 == 0) goto FUN_6ead;
LAB_6ee0:
        cVar4 = cVar4 + -1;
        if (cVar4 == '\0') {
          return 0x3f;
        }
        DAT_00b8 = bVar1 + DAT_00ba + cVar5;
        if (CARRY1(bVar1,DAT_00ba)) {
          DAT_00b8 = DAT_00b8 - DAT_00b9;
          uVar3 = 0x3f;
          goto LAB_6f32;
        }
        bVar1 = 0x7f;
      }
    }
LAB_6f11:
    *(byte *)(DAT_0099 + (ushort)param_2) = bVar1 | *(byte *)(DAT_0099 + (ushort)param_2);
    param_2 = param_2 + 1;
    param_1 = cVar4 + -1;
    if (param_1 == '\0') {
      return 1;
    }
    bVar1 = DAT_00b8 + DAT_00ba;
    if (CARRY1(DAT_00b8,DAT_00ba)) {
      DAT_00b8 = bVar1 - DAT_00b9;
      bVar6 = ((DAT_00b9 & (~bVar1 | DAT_00b8) | DAT_00b8 & ~bVar1) & 0x80) != 0;
      bVar2 = FUN_6fe6(1);
      if (!bVar6) goto LAB_6f66;
FUN_6f49:
      if ((char)(param_1 + -1) == '\0') {
        return 6;
      }
      bVar1 = DAT_00b8 + DAT_00ba;
      if (CARRY1(DAT_00b8,DAT_00ba)) {
        DAT_00b8 = bVar1 - DAT_00b9;
        bVar1 = DAT_00b9 & (~bVar1 | DAT_00b8) | DAT_00b8 & ~bVar1;
        uVar3 = 6;
        param_1 = param_1 + -1;
        goto LAB_6f74;
      }
      if (bVar1 == 0) {
        return 7;
      }
      param_1 = param_1 + -2;
      if (param_1 == '\0') {
        return 0x1e;
      }
      DAT_00b8 = bVar1 + DAT_00ba;
      if (!CARRY1(bVar1,DAT_00ba)) {
        bVar1 = 0x7e;
        goto LAB_6faa;
      }
      DAT_00b8 = DAT_00b8 - DAT_00b9;
      uVar3 = 0x1e;
LAB_6fd2:
      FUN_6fe6(uVar3);
      bVar1 = 0x60;
    }
    else {
      param_1 = cVar4 + -2;
      if (param_1 == '\0') {
        return 7;
      }
      bVar2 = bVar1 + DAT_00ba;
      bVar6 = true;
      if (CARRY1(bVar1,DAT_00ba)) {
LAB_6f66:
        DAT_00b8 = (bVar2 - DAT_00b9) - !bVar6;
        bVar1 = DAT_00b9 & (~bVar2 | DAT_00b8) | DAT_00b8 & ~bVar2;
        uVar3 = 7;
LAB_6f74:
        cVar4 = (bVar1 & 0x80) != 0;
        bVar2 = FUN_6fe6(uVar3);
        if (!(bool)cVar4) goto LAB_6f79;
        param_1 = param_1 + -1;
        if (param_1 == '\0') {
          return 0x18;
        }
        bVar6 = CARRY1(DAT_00b8,DAT_00ba);
        DAT_00b8 = DAT_00b8 + DAT_00ba;
        if (bVar6) {
          DAT_00b8 = DAT_00b8 - DAT_00b9;
          uVar3 = 0x18;
          goto LAB_6fd2;
        }
        bVar1 = 0x78;
      }
      else {
        cVar4 = '\0';
        if (bVar2 == 0) goto FUN_6f49;
LAB_6f79:
        param_1 = param_1 + -1;
        if (param_1 == '\0') {
          return 0x1f;
        }
        DAT_00b8 = bVar2 + DAT_00ba + cVar4;
        if (CARRY1(bVar2,DAT_00ba)) {
          DAT_00b8 = DAT_00b8 - DAT_00b9;
          uVar3 = 0x1f;
          goto LAB_6fd2;
        }
        bVar1 = 0x7f;
      }
    }
LAB_6faa:
    *(byte *)(DAT_0099 + (ushort)param_2) = bVar1 | *(byte *)(DAT_0099 + (ushort)param_2);
    param_2 = param_2 + 1;
    param_1 = param_1 + -1;
    if (param_1 == '\0') {
      return unaff_retaddr;
    }
    bVar1 = DAT_00b8 + DAT_00ba;
    if (CARRY1(DAT_00b8,DAT_00ba)) {
      DAT_00b8 = bVar1 - DAT_00b9;
      FUN_6fea();
      uVar3 = FUN_6e9a();
      return uVar3;
    }
  } while( true );
}

