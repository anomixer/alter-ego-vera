; The runtime's declarations (the build expands the list: src/runtime/head.txt)
; mput ../../runtime/head.txt
; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
            REL
            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs.s
            put    ../../Externals.s
            put    ../../core/Defs.s
            put    ../../ImportEngine.s
; AUTOINC:END

            put   Config.s
            put   pal_defs.s                  ; PAL_* constants from palettes/

            mx    %00

            phk
            plb

; Diagnostic: border green on entry to Main
            php
            sep   #$20
            pha
            lda   #$0C
            stal  $E0C034
            pla
            rep   #$20
            plp

; NROM: vertical mirroring at power on.
            tax                           ; X = memory manager user ID (passed in A by GS/OS)
            lda   #VERTICAL_MIRRORING     ; A = cartridge nametable mirroring at power on
            jsr   NES_StartUp

; Diagnostic marker: startup returned (SHR is initialized by now).
            pha
            lda   #$FF
            sta   $E12000
            sta   $E12001
            sta   $E12002
            sta   $E12003
            pla

; The C PRG's zero page is linked at $0020, so it has to run with D=$0000.
; The runtime's default DP_NES is in the STKDP bank and would make every
; zeropage access miss.
            lda   #0
            sta   DP_NES

; Select the title palette (also installed by InitPlayfield during NES_StartUp).
            jsr   SetDefaultPalette

; Run the C game's reset code from ROMBase+$FFFC.
            jsr   NES_ColdBoot

:start
            jsr   NES_EvtLoop

            cmp   #USER_SAYS_QUIT
            beq   quit

            cmp   #USER_SAYS_RESET
            bne   quit

            jsr   NES_WarmBoot
            bra   :start

quit
            jsr   NES_ShutDown

            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00

; Names of the save and preference files (used by misc/io.s)
SAVE_FILENAME strl '1/ae.sav'
PREF_FILENAME strl '1/ae.prefs'

; Engine callbacks (macros only)
            put   Hooks.s

; ===========================================================================
; Game code
; ===========================================================================
            mx    %00

; Called by NES_StartUp before the ROM's reset code runs.  The generated
; palette code needs its swizzle tables installed before the title is drawn.
InitPlayfield
            jmp   SetDefaultPalette

            mx    %00

; Palette management generated from palettes/
            put   pal_transitions.s
            put   palettes.s                ; swizzle tables (was the PALDATA segment)

; Runtime code (the build expands the list: src/runtime/code.txt)
            mput  ../../runtime/code.txt
; AUTOINC:BEGIN (do not edit -- managed by scripts/gen-includes.js)
            put    ../../misc/App.Msg.s
            put    ../../misc/io.s
            put    ../../apu/apu.s
            put    ../../rom/scaffold.s
            put    ../../rom/rom_color.s
            put    ../../rom/rom_helpers.s
            put    ../../rom/rom_input.s
            put    ../../rom/rom_kbd_basic.s
            put    ../../rom/rom_kbd_j13.s
            put    ../../rom/rom_kbd_adb.s
            put    ../../rom/rom_exec.s
            put    ../../rom/rom_config.s
            put    ../../rom/rom_config_setup.s
            put    ../../core/ControlBits.s
            put    ../../core/CoreImpl.s
            put    ../../core/Graphics.s
            put    ../../core/Math.s
            put    ../../core/Memory.s
; AUTOINC:END
