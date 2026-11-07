// rea decompile_all
// name: FUN_6f03
// address: 0x6f03
// body: available
// range: 0x6f03-0x6f34 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


undefined1 FUN_6f03(char param_1,byte param_2)

{
  byte bVar1;
  undefined1 uVar2;
  byte bVar3;
  char cVar4;
  bool bVar5;
  bool bVar6;
  char cVar7;
  undefined1 unaff_retaddr;
  
code_r0x6f03:
  param_1 = param_1 + -1;
  if (param_1 == '\0') {
    return 0x30;
  }
  bVar6 = CARRY1(DAT_00b8,DAT_00ba);
  DAT_00b8 = DAT_00b8 + DAT_00ba;
  if (bVar6) {
    DAT_00b8 = DAT_00b8 - DAT_00b9;
    uVar2 = 0x30;
    goto LAB_6f32;
  }
  bVar1 = 0x70;
LAB_6f11:
  do {
    *(byte *)(DAT_0099 + (ushort)param_2) = bVar1 | *(byte *)(DAT_0099 + (ushort)param_2);
    param_2 = param_2 + 1;
    cVar4 = param_1 + -1;
    if (cVar4 == '\0') {
      return 1;
    }
    bVar1 = DAT_00b8 + DAT_00ba;
    if (CARRY1(DAT_00b8,DAT_00ba)) {
      DAT_00b8 = bVar1 - DAT_00b9;
      bVar6 = ((DAT_00b9 & (~bVar1 | DAT_00b8) | DAT_00b8 & ~bVar1) & 0x80) != 0;
      bVar3 = FUN_6fe6(1);
      if (!bVar6) goto LAB_6f66;
FUN_6f49:
      if ((char)(cVar4 + -1) == '\0') {
        return 6;
      }
      bVar1 = DAT_00b8 + DAT_00ba;
      if (CARRY1(DAT_00b8,DAT_00ba)) {
        DAT_00b8 = bVar1 - DAT_00b9;
        bVar1 = DAT_00b9 & (~bVar1 | DAT_00b8) | DAT_00b8 & ~bVar1;
        uVar2 = 6;
        cVar4 = cVar4 + -1;
        goto LAB_6f74;
      }
      if (bVar1 == 0) {
        return 7;
      }
      cVar4 = cVar4 + -2;
      if (cVar4 == '\0') {
        return 0x1e;
      }
      DAT_00b8 = bVar1 + DAT_00ba;
      if (!CARRY1(bVar1,DAT_00ba)) {
        bVar1 = 0x7e;
        goto LAB_6faa;
      }
      DAT_00b8 = DAT_00b8 - DAT_00b9;
      uVar2 = 0x1e;
LAB_6fd2:
      FUN_6fe6(uVar2);
      bVar1 = 0x60;
    }
    else {
      cVar4 = param_1 + -2;
      if (cVar4 == '\0') {
        return 7;
      }
      bVar3 = bVar1 + DAT_00ba;
      bVar6 = true;
      if (CARRY1(bVar1,DAT_00ba)) {
LAB_6f66:
        DAT_00b8 = (bVar3 - DAT_00b9) - !bVar6;
        bVar1 = DAT_00b9 & (~bVar3 | DAT_00b8) | DAT_00b8 & ~bVar3;
        uVar2 = 7;
LAB_6f74:
        cVar7 = (bVar1 & 0x80) != 0;
        bVar3 = FUN_6fe6(uVar2);
        if (!(bool)cVar7) goto LAB_6f79;
        cVar4 = cVar4 + -1;
        if (cVar4 == '\0') {
          return 0x18;
        }
        bVar6 = CARRY1(DAT_00b8,DAT_00ba);
        DAT_00b8 = DAT_00b8 + DAT_00ba;
        if (bVar6) {
          DAT_00b8 = DAT_00b8 - DAT_00b9;
          uVar2 = 0x18;
          goto LAB_6fd2;
        }
        bVar1 = 0x78;
      }
      else {
        cVar7 = '\0';
        if (bVar3 == 0) goto FUN_6f49;
LAB_6f79:
        cVar4 = cVar4 + -1;
        if (cVar4 == '\0') {
          return 0x1f;
        }
        DAT_00b8 = bVar3 + DAT_00ba + cVar7;
        if (CARRY1(bVar3,DAT_00ba)) {
          DAT_00b8 = DAT_00b8 - DAT_00b9;
          uVar2 = 0x1f;
          goto LAB_6fd2;
        }
        bVar1 = 0x7f;
      }
    }
LAB_6faa:
    *(byte *)(DAT_0099 + (ushort)param_2) = bVar1 | *(byte *)(DAT_0099 + (ushort)param_2);
    param_2 = param_2 + 1;
    if (cVar4 == '\x01') {
      return unaff_retaddr;
    }
    bVar1 = DAT_00b8 + DAT_00ba;
    if (CARRY1(DAT_00b8,DAT_00ba)) {
      DAT_00b8 = bVar1 - DAT_00b9;
      FUN_6fea();
      uVar2 = FUN_6e9a();
      return uVar2;
    }
    param_1 = cVar4 + -2;
    if (param_1 == '\0') {
      return 3;
    }
    bVar3 = bVar1 + DAT_00ba;
    if (!CARRY1(bVar1,DAT_00ba)) {
      param_1 = cVar4 + -3;
      if (param_1 == '\0') {
        return 0xf;
      }
      bVar1 = bVar3 + DAT_00ba;
      bVar6 = true;
      if (CARRY1(bVar3,DAT_00ba)) {
LAB_6ecd:
        DAT_00b8 = (bVar1 - DAT_00b9) - !bVar6;
        bVar1 = DAT_00b9 & (~bVar1 | DAT_00b8) | DAT_00b8 & ~bVar1;
        uVar2 = 0xf;
LAB_6edb:
        bVar6 = (bVar1 & 0x80) != 0;
        bVar1 = FUN_6fe6(uVar2);
        if (bVar6) goto code_r0x6f03;
      }
      else if (bVar1 == 0) goto FUN_6ead;
      param_1 = param_1 + -1;
      if (param_1 == '\0') {
        return 0x3f;
      }
      DAT_00b8 = bVar1 + DAT_00ba;
      if (CARRY1(bVar1,DAT_00ba)) {
        DAT_00b8 = DAT_00b8 - DAT_00b9;
        uVar2 = 0x3f;
LAB_6f32:
        FUN_6fe6(uVar2);
        bVar1 = 0x40;
      }
      else {
        bVar1 = 0x7f;
      }
      goto LAB_6f11;
    }
    DAT_00b8 = bVar3 - DAT_00b9;
    bVar5 = ((DAT_00b9 & (~bVar3 | DAT_00b8) | DAT_00b8 & ~bVar3) & 0x80) != 0;
    bVar1 = FUN_6fe6(3);
    bVar6 = false;
    if (!bVar5) goto LAB_6ecd;
FUN_6ead:
    if ((char)(param_1 + -1) == '\0') {
      return 0xc;
    }
    bVar1 = DAT_00b8 + DAT_00ba;
    if (CARRY1(DAT_00b8,DAT_00ba)) {
      DAT_00b8 = bVar1 - DAT_00b9;
      bVar1 = DAT_00b9 & (~bVar1 | DAT_00b8) | DAT_00b8 & ~bVar1;
      uVar2 = 0xc;
      param_1 = param_1 + -1;
      goto LAB_6edb;
    }
    if (bVar1 == 0) {
      return 3;
    }
    param_1 = param_1 + -2;
    if (param_1 == '\0') {
      return 0x3c;
    }
    DAT_00b8 = bVar1 + DAT_00ba;
    if (CARRY1(bVar1,DAT_00ba)) {
      DAT_00b8 = DAT_00b8 - DAT_00b9;
      uVar2 = 0x3c;
      goto LAB_6f32;
    }
    bVar1 = 0x7c;
  } while( true );
}

