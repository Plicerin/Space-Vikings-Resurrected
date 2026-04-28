Disassembling C:\Users\vrock\Documents\Space Vikings Resurrected\extracted\MEM TRANSFER A.bin (256 bytes) starting at $9400
============================================================
$9400: 00        BRK
$9401: 60        RTS
$9402: 70 00     BVS $9404
$9404: A2 00     LDX #$00
$9406: 8E 32 95  STX $9532
$9409: 18        CLC
$940A: AE 32 95  LDX $9532
$940D: E0 80     CPX #$80
$940F: F0 60     BEQ $9471
$9411: BD EC 8B  LDA $8BEC,X
$9414: 85 00     STA $00
$9416: BD 7C 8D  LDA $8D7C,X
$9419: 85 04     STA $04
$941B: EE 32 95  INC $9532
$941E: AE 32 95  LDX $9532
$9421: BD EC 8B  LDA $8BEC,X
$9424: 85 01     STA $01
$9426: BD 7C 8D  LDA $8D7C,X
$9429: 85 05     STA $05
$942B: 20 60 94  JSR $9460
$942E: EE 32 95  INC $9532
$9431: 4C 06 94  JMP $9406
$9434: A2 00     LDX #$00
$9436: 8E 32 95  STX $9532
$9439: 18        CLC
$943A: AE 32 95  LDX $9532
$943D: E0 80     CPX #$80
$943F: F0 30     BEQ $9471
$9441: BD 7C 8D  LDA $8D7C,X
$9444: 85 00     STA $00
$9446: BD EC 8B  LDA $8BEC,X
$9449: 85 04     STA $04
$944B: EE 32 95  INC $9532
$944E: AE 32 95  LDX $9532
$9451: BD 7C 8D  LDA $8D7C,X
$9454: 85 01     STA $01
$9456: BD EC 8B  LDA $8BEC,X
$9459: 85 05     STA $05
$945B: 20 60 94  JSR $9460
$945E: EE 32 95  INC $9532
$9461: 4C 36 94  JMP $9436
$9464: 18        CLC
$9465: A0 00     LDY #$00
$9467: B1 00     LDA ($00),Y
$9469: 91 04     STA ($04),Y
$946B: C8        INY
$946C: 98        TYA
$946D: 69 D8     ADC #$D8
$946F: 90 F6     BCC $9467
$9471: 60        RTS
$9472: 3C        .byte $3C
$9473: 00        BRK
$9474: 20 00 00  JSR $0000
$9477: 00        BRK
$9478: 00        BRK
$9479: 00        BRK
$947A: 00        BRK
$947B: 00        BRK
$947C: 00        BRK
$947D: 00        BRK
$947E: 00        BRK
$947F: 00        BRK
$9480: 00        BRK
$9481: 00        BRK
$9482: 00        BRK
$9483: 00        BRK
$9484: 00        BRK
$9485: 00        BRK
$9486: 00        BRK
$9487: 00        BRK
$9488: 00        BRK
$9489: 00        BRK
$948A: 00        BRK
$948B: 00        BRK
$948C: 00        BRK
$948D: 00        BRK
$948E: 00        BRK
$948F: 00        BRK
$9490: 00        BRK
$9491: 00        BRK
$9492: 00        BRK
$9493: 00        BRK
$9494: 00        BRK
$9495: 00        BRK
$9496: 00        BRK
$9497: 00        BRK
$9498: 00        BRK
$9499: 00        BRK
$949A: 00        BRK
$949B: 00        BRK
$949C: 00        BRK
$949D: 00        BRK
$949E: 00        BRK
$949F: 00        BRK
$94A0: 00        BRK
$94A1: 00        BRK
$94A2: 00        BRK
$94A3: 00        BRK
$94A4: 00        BRK
$94A5: 00        BRK
$94A6: 00        BRK
$94A7: 00        BRK
$94A8: 00        BRK
$94A9: 00        BRK
$94AA: 00        BRK
$94AB: 00        BRK
$94AC: 00        BRK
$94AD: 00        BRK
$94AE: 00        BRK
$94AF: 00        BRK
$94B0: 00        BRK
$94B1: 00        BRK
$94B2: 00        BRK
$94B3: 00        BRK
$94B4: 00        BRK
$94B5: 00        BRK
$94B6: 00        BRK
$94B7: 00        BRK
$94B8: 00        BRK
$94B9: 00        BRK
$94BA: 00        BRK
$94BB: 00        BRK
$94BC: 00        BRK
$94BD: 00        BRK
$94BE: 00        BRK
$94BF: 00        BRK
$94C0: 00        BRK
$94C1: 00        BRK
$94C2: 00        BRK
$94C3: 00        BRK
$94C4: 00        BRK
$94C5: 00        BRK
$94C6: 00        BRK
$94C7: 00        BRK
$94C8: 00        BRK
$94C9: 00        BRK
$94CA: 00        BRK
$94CB: 00        BRK
$94CC: 00        BRK
$94CD: 00        BRK
$94CE: 00        BRK
$94CF: 00        BRK
$94D0: 00        BRK
$94D1: 00        BRK
$94D2: 00        BRK
$94D3: 00        BRK
$94D4: 00        BRK
$94D5: 00        BRK
$94D6: 00        BRK
$94D7: 00        BRK
$94D8: 00        BRK
$94D9: 00        BRK
$94DA: 00        BRK
$94DB: 00        BRK
$94DC: 00        BRK
$94DD: 00        BRK
$94DE: 00        BRK
$94DF: 00        BRK
$94E0: 00        BRK
$94E1: 00        BRK
$94E2: 00        BRK
$94E3: 00        BRK
$94E4: 00        BRK
$94E5: 00        BRK
$94E6: 00        BRK
$94E7: 00        BRK
$94E8: 00        BRK
$94E9: 00        BRK
$94EA: 00        BRK
$94EB: 00        BRK
$94EC: 00        BRK
$94ED: 00        BRK
$94EE: 00        BRK
$94EF: 00        BRK
$94F0: 00        BRK
$94F1: 00        BRK
$94F2: 00        BRK
$94F3: 00        BRK
$94F4: 00        BRK
$94F5: 00        BRK
$94F6: 00        BRK
$94F7: 00        BRK
$94F8: 00        BRK
$94F9: 00        BRK
$94FA: 00        BRK
$94FB: 00        BRK
$94FC: 00        BRK
$94FD: 00        BRK
$94FE: 00        BRK
$94FF: 00        BRK
