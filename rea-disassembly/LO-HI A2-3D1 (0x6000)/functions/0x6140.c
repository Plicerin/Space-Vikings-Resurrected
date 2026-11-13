// rea decompile_all
// name: FUN_6140
// address: 0x6140
// body: available
// range: 0x6140-0x6183 inclusive
// range: 0x61b7-0x633c inclusive
// range: 0x68ea-0x691d inclusive
// range: 0x6d44-0x6d8e inclusive
// non_contiguous: true
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_6140(void)

{
  byte bVar1;
  undefined1 uVar2;
  char cVar3;
  byte bVar4;
  char cVar5;
  
  cVar3 = '!';
  do {
    *(undefined1 *)(ushort)(byte)(cVar3 + 0x7b) = 0;
    cVar3 = cVar3 + -1;
  } while (cVar3 != '\0');
  DAT_009b = (char *)CONCAT11(0x73,DAT_009b._0_1_);
  DAT_007e = 0xfd;
  DAT_0086 = 0xfd;
  DAT_008e = 0xfd;
  DAT_007f = 0x7f;
  DAT_0087 = 0x7f;
  DAT_008f = 0x7f;
LAB_615e:
  DAT_00b1 = '\n';
LAB_6162:
  bVar4 = 0;
  cVar3 = *DAT_009b;
  if ((cVar3 < '\0') || (-1 < (char)(cVar3 + -0x12))) {
    if (DAT_007d != '\0') {
      *DAT_009d = 0x79;
    }
    return;
  }
  bVar1 = (&BYTE_6077)[(byte)(cVar3 << 1)];
  cVar5 = bVar1 == 0;
  _DAT_00a3 = CONCAT11(bVar1,(&switchD_6181::switchdataD_6076)[(byte)(cVar3 << 1)]);
  switch(cVar3) {
  case '\0':
    FUN_61a9();
    if (DAT_0066 == 0) {
      func_0x68a1(0x9f,0x60);
      if (DAT_007d < '\0') {
        *DAT_009d = 10;
        DAT_009d[1] = DAT_009f;
        DAT_009d[2] = DAT_00a0;
        bVar4 = 3;
        goto LAB_62b2;
      }
      DAT_00b3 = DAT_009f;
      DAT_00b4 = DAT_00a0;
      FUN_6d8f();
    }
    goto LAB_6162;
  case '\x01':
    goto switchD_6181_caseD_1;
  case '\x02':
    cVar3 = '\a';
    do {
      *(undefined1 *)(ushort)(byte)(cVar3 + 0x5f) = *(undefined1 *)(ushort)(byte)(cVar3 + 0x6f);
      cVar3 = cVar3 + -1;
      cVar5 = cVar3 == '\0';
    } while (!(bool)cVar5);
    FUN_618e();
    if (cVar5 != '\0') {
      if (DAT_0066 != 0) goto LAB_61d7;
      do {
        if (DAT_006e == 0) {
          DAT_009f = DAT_00a1;
          DAT_00a0 = DAT_00a2;
          goto LAB_6281;
        }
        if (DAT_007c != '\0') break;
        FUN_6979();
        DAT_00b1 = DAT_00b1 + -1;
      } while (DAT_00b1 != '\0');
    }
    goto LAB_615e;
  case '\x03':
    goto switchD_6181_caseD_3;
  case '\x04':
    DAT_007c = DAT_009b[1];
    goto LAB_62c3;
  case '\x05':
    do {
      bVar4 = bVar4 + 1;
      *(char *)(bVar4 + 0x8f) = DAT_009b[bVar4];
    } while (bVar4 != 9);
    FUN_654e();
    uVar2 = 10;
    break;
  case '\x06':
    do {
      bVar4 = bVar4 + 1;
      *(char *)(bVar4 + 0xb2) = DAT_009b[bVar4];
    } while (bVar4 != 4);
    func_0x6dd5();
    goto LAB_62e9;
  case '\a':
    cRAM62f6 = DAT_009b[1];
                    /* WARNING: Read-only address (RAM,0x62f6) is written */
    DAT_c054 = 0;
    goto LAB_62c3;
  case '\b':
    cVar3 = DAT_009b[1];
    if (cVar3 == '\0') {
      FUN_6cda = 0;
LAB_6d58:
      if (cRAM6ce0 != ' ') {
        cVar3 = ' ';
        goto LAB_6d64;
      }
    }
    else {
      if (cVar3 == '\x01') {
                    /* WARNING: Read-only address (RAM,0x62f6) is written */
                    /* WARNING: Read-only address (RAM,0x68ba) is written */
                    /* WARNING: Read-only address (RAM,0x68c0) is written */
                    /* WARNING: Read-only address (RAM,0x68dd) is written */
                    /* WARNING: Read-only address (RAM,0x68e3) is written */
                    /* WARNING: Read-only address (RAM,0x6da4) is written */
                    /* WARNING: Read-only address (RAM,0x6da9) is written */
                    /* WARNING: Read-only address (RAM,0x6db0) is written */
                    /* WARNING: Read-only address (RAM,0x6e95) is written */
                    /* WARNING: Read-only address (RAM,0x6f11) is written */
                    /* WARNING: Read-only address (RAM,0x6faa) is written */
                    /* WARNING: Read-only address (RAM,0x6ff7) is written */
                    /* WARNING: Read-only address (RAM,0x701b) is written */
                    /* WARNING: Read-only address (RAM,0x7023) is written */
                    /* WARNING: Read-only address (RAM,0x7056) is written */
                    /* WARNING: Read-only address (RAM,0x7063) is written */
                    /* WARNING: Read-only address (RAM,0x7080) is written */
                    /* WARNING: Read-only address (RAM,0x708b) is written */
                    /* WARNING: Read-only address (RAM,0x709e) is written */
                    /* WARNING: Read-only address (RAM,0x70d8) is written */
                    /* WARNING: Read-only address (RAM,0x70e5) is written */
                    /* WARNING: Read-only address (RAM,0x7102) is written */
                    /* WARNING: Read-only address (RAM,0x710d) is written */
                    /* WARNING: Read-only address (RAM,0x7120) is written */
        FUN_6cda = 0;
      }
      else {
        if (cVar3 == '\x02') {
          FUN_6cda = 0xff;
          goto LAB_6d58;
        }
        FUN_6cda = 0xff;
      }
      if (cRAM6ce0 != '@') {
        cVar3 = '@';
LAB_6d64:
        bVar4 = 0;
        do {
          *(char *)(bVar4 + 0x6ce0) = cVar3;
          bVar4 = bVar4 + 3;
          cVar3 = cVar3 + '\x01';
        } while (bVar4 != 0x60);
      }
    }
    FUN_6cda();
    goto LAB_62c3;
  case '\t':
    bVar4 = 0x2e;
    cVar3 = '\0';
    if (DAT_009b[1] != '\0') {
      cVar3 = ' ';
    }
    _DAT_00a3 = CONCAT11(bVar1,cVar3 + ' ');
    do {
      (&DAT_6b93)[bVar4] = (&DAT_6b93)[bVar4] & 0xf | DAT_00a3;
      bVar4 = bVar4 - 2;
    } while (-1 < (char)bVar4);
    FUN_6fea = DAT_00a3;
                    /* WARNING: Read-only address (RAM,0x7063) is written */
    cRAM6ff7 = DAT_00a3 + -4;
                    /* WARNING: Read-only address (RAM,0x6ff7) is written */
                    /* WARNING: Read-only address (RAM,0x709e) is written */
    cRAM701b = DAT_00a3 + ' ';
                    /* WARNING: Read-only address (RAM,0x701b) is written */
                    /* WARNING: Read-only address (RAM,0x70e5) is written */
    cRAM7023 = DAT_00a3 + '#';
    cRAM7063 = FUN_6fea;
    cRAM709e = cRAM6ff7;
    cRAM70e5 = cRAM701b;
    cRAM7120 = cRAM7023;
                    /* WARNING: Read-only address (RAM,0x7023) is written */
                    /* WARNING: Read-only address (RAM,0x7120) is written */
    goto LAB_62c3;
  case '\n':
    do {
      bVar4 = bVar4 + 1;
      *(char *)(bVar4 + 0xb2) = DAT_009b[bVar4];
    } while (bVar4 != 2);
    FUN_6d8f();
    goto LAB_6307;
  case '\v':
    goto switchD_6181_caseD_b;
  case '\f':
    if (DAT_009b[1] == '\0') {
      cRAM6da4 = (code)0x11;
    }
    else {
      cRAM6da4 = (code)0x51;
    }
                    /* WARNING: Read-only address (RAM,0x6da4) is written */
                    /* WARNING: Read-only address (RAM,0x6da9) is written */
                    /* WARNING: Read-only address (RAM,0x6db0) is written */
                    /* WARNING: Read-only address (RAM,0x6e95) is written */
                    /* WARNING: Read-only address (RAM,0x6f11) is written */
                    /* WARNING: Read-only address (RAM,0x6faa) is written */
                    /* WARNING: Read-only address (RAM,0x7056) is written */
                    /* WARNING: Read-only address (RAM,0x7080) is written */
                    /* WARNING: Read-only address (RAM,0x708b) is written */
                    /* WARNING: Read-only address (RAM,0x70d8) is written */
                    /* WARNING: Read-only address (RAM,0x7102) is written */
                    /* WARNING: Read-only address (RAM,0x710d) is written */
    cRAM6da9 = cRAM6da4;
    cRAM6db0 = cRAM6da4;
    cRAM6e95 = cRAM6da4;
    cRAM6f11 = cRAM6da4;
    cRAM6faa = cRAM6da4;
    FUN_6fe6 = cRAM6da4;
    cRAM7056 = cRAM6da4;
    cRAM7080 = cRAM6da4;
    cRAM708b = cRAM6da4;
    cRAM70d8 = cRAM6da4;
    cRAM7102 = cRAM6da4;
    cRAM710d = cRAM6da4;
    if (DAT_007d != '\0') {
      *DAT_009d = 0x79;
      DAT_007d = '\0';
    }
LAB_62c3:
    uVar2 = 2;
    break;
  case '\r':
    DAT_007d = -1;
    DAT_009d = *(undefined1 **)(DAT_009b + 1);
LAB_6307:
    uVar2 = 3;
    break;
  case '\x0e':
    cRAM68ba = ((byte)DAT_009b[1] >> 1) - 1;
                    /* WARNING: Read-only address (RAM,0x68ba) is written */
    cRAM68dd = ((byte)DAT_009b[2] >> 1) - 1;
                    /* WARNING: Read-only address (RAM,0x68dd) is written */
    cRAM68c0 = DAT_009b[3];
                    /* WARNING: Read-only address (RAM,0x68c0) is written */
    cRAM68e3 = DAT_009b[4];
                    /* WARNING: Read-only address (RAM,0x68e3) is written */
LAB_62e9:
    uVar2 = 5;
    break;
  case '\x0f':
    do {
      bVar4 = bVar4 + 1;
      (&DAT_600d)[bVar4] = DAT_009b[bVar4];
    } while (bVar4 != 6);
    uVar2 = 7;
    break;
  case '\x10':
    DAT_c053 = 0;
    DAT_c057 = 0;
    DAT_c050 = 0;
    DAT_c054 = 0;
  case '\x11':
    uVar2 = 1;
  }
  FUN_6184(uVar2);
  goto LAB_6162;
switchD_6181_caseD_b:
  DAT_009b = *(char **)(DAT_009b + 1);
  goto LAB_6162;
switchD_6181_caseD_3:
  cVar3 = '\a';
  do {
    *(undefined1 *)(ushort)(byte)(cVar3 + 0x67) = *(undefined1 *)(ushort)(byte)(cVar3 + 0x6f);
    cVar3 = cVar3 + -1;
  } while (cVar3 != '\0');
  FUN_61a9();
  if ((DAT_0066 & DAT_006e) == 0) {
    if (DAT_0066 != 0) goto LAB_61d7;
    if (DAT_006e != 0) goto LAB_61ca;
    func_0x68a1(0x9f,0x60);
    goto LAB_6288;
  }
  goto LAB_615e;
switchD_6181_caseD_1:
  FUN_61a9();
  FUN_618e();
  if (cVar5 != '\0') {
    if (DAT_0066 == 0) {
LAB_61c3:
      if (DAT_006e != 0) {
LAB_61ca:
        if (DAT_007c != '\0') goto LAB_615e;
        FUN_6979();
        DAT_00b1 = DAT_00b1 + -1;
        if (DAT_00b1 == '\0') goto LAB_615e;
        goto LAB_61c3;
      }
      func_0x68a1(0x9f,0x60);
LAB_6281:
      func_0x68a1(0xa1,0x68);
LAB_6288:
      if (DAT_007d == '\0') {
        DAT_00b3 = DAT_009f;
        DAT_00b4 = DAT_00a0;
        DAT_00b5 = DAT_00a1;
        DAT_00b6 = DAT_00a2;
        func_0x6dd5();
      }
      else {
        uVar2 = 6;
        bVar4 = 0;
        do {
          DAT_009d[bVar4] = uVar2;
          uVar2 = *(undefined1 *)(bVar4 + 0x9f);
          bVar4 = bVar4 + 1;
        } while (bVar4 != 5);
        bVar4 = 5;
LAB_62b2:
        if (CARRY1(bVar4,(byte)DAT_009d)) {
          DAT_009d._1_1_ = DAT_009d._1_1_ + '\x01';
        }
        DAT_009d = (undefined1 *)CONCAT11(DAT_009d._1_1_,bVar4 + (byte)DAT_009d);
      }
    }
    else {
LAB_61d7:
      if (DAT_007c == '\0') {
        do {
          FUN_695f();
          if (DAT_0066 == 0) goto LAB_61c3;
        } while (((DAT_0066 & DAT_006e) == 0) && (DAT_00b1 = DAT_00b1 + -1, DAT_00b1 != '\0'));
      }
    }
  }
  goto LAB_615e;
}

