// rea decompile_all
// name: FUN_6dd5
// address: 0x6dd5
// body: available
// range: 0x6dd5-0x6e99 inclusive
// non_contiguous: false
// provider: Ghidra 12.1.2 (ghidra)
// analysis_profile: 83e5c16d3aaa61d374063fd1a841b978ef6075e80a63f218e23d631a14954cd2
// limitations: The session serves operations only after Ghidra reports default auto-analysis complete; incomplete analysis does not expose partial results.; The imported Program and temporary project are ephemeral and deleted on close. Annotation operations edit session database metadata; original executable bytes are never written.; Cancelling an active Ghidra request terminates its ephemeral database and discards session annotations. The selected target remains open; the next provider query imports the original artifact again.; Default-space addresses use lowercase 0x-prefixed hexadecimal; other address spaces use <percent-encoded-space>:0x<hex>.; Ghidra Listing reports a terminal call at 0x6e28 to 0x7044 FUN_7044 (external=false, thunk=false, hasNoReturn=false); fallthrough is excluded by Ghidra's flow model. The reason for the terminal flow is not established by this observation.; Headerless raw-binary analysis uses the caller-supplied architecture and entry address; file offset 0 is mapped at that address. Headers are not discovered from file bytes.; Little-endian generic Ghidra languages are used for x86, x86_64, arm, arm64, and NMOS 6502; m68k uses the big-endian 68000 default language, which decodes the 68040 superset. Big-endian ARM, Thumb-only, Cortex-M, 65C02, 65816, separate 68020/68030/CPU32/ColdFire variants, and other processor variants are unsupported in this increment.; Static analysis does not emulate reset vectors, memory-mapped I/O, or firmware boot sequences.; This session uses Ghidra 12.1.2. The bridge is verified against 12.1.4; other 12.1.x builds are accepted and the observed version is reported.; Pseudocode is Ghidra decompiler output, not original source and not text-equivalent to Hopper output.; External functions and functions without an analyzable body return null; other decompiler failures remain explicit.
// pseudocode: provider-specific; not original source


/* WARNING: Removing unreachable block (RAM,0x7148) */
/* WARNING: Removing unreachable block (RAM,0x714f) */
/* WARNING: Removing unreachable block (RAM,0x7151) */
/* WARNING: Removing unreachable block (RAM,0x7156) */
/* WARNING: Removing unreachable block (RAM,0x7164) */
/* WARNING: Removing unreachable block (RAM,0x62c3) */
/* WARNING: Removing unreachable block (RAM,0x62c5) */
/* WARNING: Removing unreachable block (RAM,0x6162) */
/* WARNING: Removing unreachable block (RAM,0x6168) */
/* WARNING: Removing unreachable block (RAM,0x616c) */
/* WARNING: Removing unreachable block (RAM,0x6170) */
/* WARNING: Removing unreachable block (RAM,0x6174) */
/* WARNING: Removing unreachable block (RAM,0x6175) */
/* WARNING: Removing unreachable block (RAM,0x632a) */
/* WARNING: Removing unreachable block (RAM,0x6338) */
/* WARNING: Removing unreachable block (RAM,0x690f) */
/* WARNING: Removing unreachable block (RAM,0x6919) */
/* WARNING: Removing unreachable block (RAM,0x68ea) */
/* WARNING: Removing unreachable block (RAM,0x6319) */
/* WARNING: Removing unreachable block (RAM,0x718a) */
/* WARNING: Removing unreachable block (RAM,0x7193) */
/* WARNING: Removing unreachable block (RAM,0x718f) */
/* WARNING: Removing unreachable block (RAM,0x7195) */
/* WARNING: Removing unreachable block (RAM,0x71c0) */
/* WARNING: Removing unreachable block (RAM,0x71c8) */
/* WARNING: Removing unreachable block (RAM,0x630b) */
/* WARNING: Removing unreachable block (RAM,0x62fa) */
/* WARNING: Removing unreachable block (RAM,0x6304) */
/* WARNING: Removing unreachable block (RAM,0x6307) */
/* WARNING: Removing unreachable block (RAM,0x6d44) */
/* WARNING: Removing unreachable block (RAM,0x6d52) */
/* WARNING: Removing unreachable block (RAM,0x6d49) */
/* WARNING: Removing unreachable block (RAM,0x6d75) */
/* WARNING: Removing unreachable block (RAM,0x6d4d) */
/* WARNING: Removing unreachable block (RAM,0x6d56) */
/* WARNING: Removing unreachable block (RAM,0x6d58) */
/* WARNING: Removing unreachable block (RAM,0x6d62) */
/* WARNING: Removing unreachable block (RAM,0x6d50) */
/* WARNING: Removing unreachable block (RAM,0x6d7b) */
/* WARNING: Removing unreachable block (RAM,0x6d85) */
/* WARNING: Removing unreachable block (RAM,0x6d64) */
/* WARNING: Removing unreachable block (RAM,0x6d66) */
/* WARNING: Removing unreachable block (RAM,0x6d73) */
/* WARNING: Removing unreachable block (RAM,0x6d89) */
/* WARNING: Removing unreachable block (RAM,0x62ed) */
/* WARNING: Removing unreachable block (RAM,0x62dc) */
/* WARNING: Removing unreachable block (RAM,0x62e6) */
/* WARNING: Removing unreachable block (RAM,0x62e9) */
/* WARNING: Removing unreachable block (RAM,0x62cb) */
/* WARNING: Removing unreachable block (RAM,0x62d5) */
/* WARNING: Removing unreachable block (RAM,0x62be) */
/* WARNING: Removing unreachable block (RAM,0x6212) */
/* WARNING: Removing unreachable block (RAM,0x6214) */
/* WARNING: Removing unreachable block (RAM,0x621b) */
/* WARNING: Removing unreachable block (RAM,0x6224) */
/* WARNING: Removing unreachable block (RAM,0x6228) */
/* WARNING: Removing unreachable block (RAM,0x622c) */
/* WARNING: Removing unreachable block (RAM,0x6270) */
/* WARNING: Removing unreachable block (RAM,0x61ec) */
/* WARNING: Removing unreachable block (RAM,0x61ee) */
/* WARNING: Removing unreachable block (RAM,0x61f5) */
/* WARNING: Removing unreachable block (RAM,0x61fa) */
/* WARNING: Removing unreachable block (RAM,0x61fe) */
/* WARNING: Removing unreachable block (RAM,0x6202) */
/* WARNING: Removing unreachable block (RAM,0x6206) */
/* WARNING: Removing unreachable block (RAM,0x620d) */
/* WARNING: Removing unreachable block (RAM,0x6265) */
/* WARNING: Removing unreachable block (RAM,0x61b7) */
/* WARNING: Removing unreachable block (RAM,0x61bf) */
/* WARNING: Removing unreachable block (RAM,0x61d7) */
/* WARNING: Removing unreachable block (RAM,0x61db) */
/* WARNING: Removing unreachable block (RAM,0x61c3) */
/* WARNING: Removing unreachable block (RAM,0x61c7) */
/* WARNING: Removing unreachable block (RAM,0x6281) */
/* WARNING: Removing unreachable block (RAM,0x6288) */
/* WARNING: Removing unreachable block (RAM,0x62a2) */
/* WARNING: Removing unreachable block (RAM,0x62a6) */
/* WARNING: Removing unreachable block (RAM,0x62b0) */
/* WARNING: Removing unreachable block (RAM,0x628c) */
/* WARNING: Removing unreachable block (RAM,0x61ca) */
/* WARNING: Removing unreachable block (RAM,0x61ce) */
/* WARNING: Removing unreachable block (RAM,0x61d5) */
/* WARNING: Removing unreachable block (RAM,0x61e2) */
/* WARNING: Removing unreachable block (RAM,0x61e6) */
/* WARNING: Removing unreachable block (RAM,0x61ea) */
/* WARNING: Removing unreachable block (RAM,0x620f) */
/* WARNING: Removing unreachable block (RAM,0x622e) */
/* WARNING: Removing unreachable block (RAM,0x6238) */
/* WARNING: Removing unreachable block (RAM,0x6251) */
/* WARNING: Removing unreachable block (RAM,0x62b2) */
/* WARNING: Removing unreachable block (RAM,0x62b9) */
/* WARNING: Removing unreachable block (RAM,0x62bb) */
/* WARNING: Removing unreachable block (RAM,0x615e) */
/* WARNING: Removing unreachable block (RAM,0x6243) */
/* WARNING: Removing unreachable block (RAM,0x6235) */
/* WARNING: Recovered jumptable eliminated as dead code */
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_6dd5(byte param_1)

{
  short sVar1;
  byte bVar2;
  byte bVar3;
  char cVar4;
  
  DAT_00b3 = DAT_00b3 + 0x46;
  DAT_00b5 = DAT_00b5 + 0x46;
  DAT_00b4 = (DAT_00b4 ^ 0xff) + 0x60;
  DAT_00b6 = (DAT_00b6 ^ 0xff) + 0x60;
  DAT_00b9 = DAT_00b5 - DAT_00b3;
  if (((DAT_00b3 & (~DAT_00b5 | DAT_00b9) | DAT_00b9 & ~DAT_00b5) & 0x80) == 0) {
    DAT_00b9 = (DAT_00b9 ^ 0xff) + 1;
    DAT_00ba = DAT_00b4 - DAT_00b6;
    bVar2 = DAT_00b6 & (~DAT_00b4 | DAT_00ba) | DAT_00ba & ~DAT_00b4;
    DAT_00b3 = DAT_00b5;
    DAT_00b4 = DAT_00b6;
  }
  else {
    DAT_00ba = DAT_00b6 - DAT_00b4;
    bVar2 = DAT_00b4 & (~DAT_00b6 | DAT_00ba) | DAT_00ba & ~DAT_00b6;
  }
  if ((bVar2 & 0x80) == 0) {
    DAT_00ba = (DAT_00ba ^ 0xff) + 1;
    bVar2 = DAT_00ba - DAT_00b9;
    if (((DAT_00b9 & (~DAT_00ba | bVar2) | bVar2 & ~DAT_00ba) & 0x80) != 0) {
      func_0x7044(bVar2);
      return;
    }
    FUN_6fea = 0xe9;
    FUN_6fea = 3;
  }
  else {
    if (((DAT_00b9 & (~DAT_00ba | DAT_00ba - DAT_00b9) | DAT_00ba - DAT_00b9 & ~DAT_00ba) & 0x80) !=
        0) {
      DAT_00b8 = DAT_00ba >> 1;
      DAT_00b7 = FUN_6db5();
      cVar4 = DAT_00ba + 1;
LAB_70d4:
      bVar2 = DAT_00b7;
      if ((char)DAT_00b7 < '\0') goto LAB_710a;
code_r0x70d8:
      *(byte *)(DAT_0099 + (ushort)param_1) = bVar2 | *(byte *)(DAT_0099 + (ushort)param_1);
      bVar2 = param_1;
      sVar1 = DAT_0099;
      do {
        cVar4 = cVar4 + -1;
        if (cVar4 == '\0') {
          DAT_0099 = sVar1;
          return;
        }
        DAT_0099._1_1_ = (byte)((ushort)sVar1 >> 8);
        bVar3 = DAT_0099._1_1_ + 4;
        param_1 = bVar2;
        if (0x3f < bVar3) {
          if (bVar3 == 0x43) goto LAB_712e;
          do {
            param_1 = bVar2 + 0x80;
            bVar3 = (DAT_0099._1_1_ - 0x1b) -
                    (((~bVar2 & 0x80) == 0 && (param_1 & 0x80) == 0) &&
                    (param_1 & ~bVar2 & 0x80) == 0);
            bVar2 = param_1;
            if ((bVar3 & ~DAT_0099._1_1_ & 0x80) != 0) goto LAB_70e8;
LAB_712e:
          } while ((char)(bVar2 + 0x80) < '\0');
          param_1 = bVar2 + 0xa8;
          bVar3 = (DAT_0099._1_1_ - 0x1f) - ((param_1 & ~bVar2 & 0x80) == 0);
          bVar2 = ~DAT_0099._1_1_;
          DAT_0099 = sVar1;
          if ((bVar3 & bVar2 & 0x80) == 0) goto LAB_713d;
        }
LAB_70e8:
        DAT_0099 = CONCAT11(bVar3,(char)sVar1);
        bVar3 = DAT_00b8 - DAT_00b9;
        bVar2 = ~DAT_00b8;
        DAT_00b8 = bVar3;
        if (((DAT_00b9 & (bVar2 | bVar3) | bVar3 & bVar2) & 0x80) != 0) goto LAB_70d4;
        DAT_00b8 = bVar3 + DAT_00ba;
        if ((char)DAT_00b7 < '\0') {
          param_1 = param_1 + 1;
          DAT_00b7 = 6;
        }
        else {
          DAT_00b7 = DAT_00b7 << 2 | DAT_00b7 >> 7;
          if ((char)DAT_00b7 < '\0') {
            if (DAT_00b7 != 0x80) goto LAB_713d;
            param_1 = param_1 + 1;
            DAT_00b7 = 3;
          }
        }
        *(byte *)(DAT_0099 + (ushort)param_1) = DAT_00b7 | *(byte *)(DAT_0099 + (ushort)param_1);
        bVar2 = param_1;
        sVar1 = DAT_0099;
      } while( true );
    }
    FUN_6fea = 0x90;
    FUN_6fea = 0x29;
  }
  DAT_00b8 = (byte)-DAT_00b9 >> 1 | 0x80;
  DAT_00b7 = FUN_6db5();
  bVar2 = DAT_00b7 & 0x7f;
  cVar4 = bVar2 == 0x18;
  if (-1 < (char)(bVar2 - 0x18)) {
    if (!(bool)cVar4) {
      cVar4 = bVar2 == 0x40;
      if ((char)(bVar2 - 0x40) < '\0') {
LAB_6e73:
        bVar2 = FUN_6f03();
        if (cVar4 == '\0') goto code_r0x6e95;
      }
      else if (!(bool)cVar4) {
        bVar2 = FUN_6fd5(DAT_00b9 + 1);
        if (cVar4 == '\0') goto code_r0x6e95;
        goto LAB_6e73;
      }
      bVar2 = FUN_6f35();
      if (cVar4 == '\0') goto code_r0x6e95;
    }
    bVar2 = FUN_6f9c();
    if (cVar4 == '\0') goto code_r0x6e95;
  }
  cVar4 = bVar2 == 6;
  if ((char)(bVar2 - 6) < '\0') {
LAB_6e8d:
    bVar2 = FUN_6e9a();
    if (cVar4 == '\0') goto code_r0x6e95;
  }
  else if (!(bool)cVar4) {
    bVar2 = FUN_6ead();
    if (cVar4 == '\0') goto code_r0x6e95;
    goto LAB_6e8d;
  }
  bVar2 = FUN_6f49();
code_r0x6e95:
  *(byte *)(DAT_0099 + (ushort)param_1) = bVar2 | *(byte *)(DAT_0099 + (ushort)param_1);
  return;
LAB_713d:
  DAT_00b7 = 0xc0;
LAB_710a:
  *(byte *)(DAT_0099 + (ushort)(byte)(param_1 + 1)) =
       *(byte *)(DAT_0099 + (ushort)(byte)(param_1 + 1)) | 1;
  bVar2 = 0xc0;
  goto code_r0x70d8;
}

