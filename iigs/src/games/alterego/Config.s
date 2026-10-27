; Alter Ego -- engine configuration (title-screen PoC)
;
; The game is NROM with a fixed 8 KB CHR-ROM and vertical mirroring.  The NES
; code is the original HEAD C build, placed at $8000-$FFFF of the ROMBase bank;
; the support/shim code occupies $0800-$7FFF of the same bank.

HAS_CHR_RAM equ 0
HAS_BACKED_WRAM equ 0

; Read OAM directly from the NES RAM copy at $0200 (the C runtime's OAM_BUF).
DIRECT_OAM_READ equ $200
OAM_START_INDEX equ 0
OAM_END_INDEX equ 64

; Keep the full-screen renderer for the PoC: the title changes its nametable
; and palette during fades, and the dirty renderer is an optimization we can
; add after the basic pipeline is proven.
ENABLE_DIRTY_RENDERING equ 0

SPR_PIXEL_SHIFT equ 1
NO_VERTICAL_CLIP equ 0
NO_INTERRUPTS equ 0
NO_CONFIG equ 0
JOYSTICK_SUPPORT equ 0
CACHE_DMC_SAMPLES equ 0

CONFIG_DEFAULT_AUDIO equ APU_60HZ
CONFIG_VIDEO_MENU equ 0
CONFIG_VIDEO_FASTBLIT equ 0
CONFIG_VIDEO_STATUSBAR equ 0
CONFIG_INPUT_2P equ 0
CONFIG_GAME_MENU equ 0

SHOW_DEBUG_VARS equ 0
RENDER_VBL_COUNT equ 0
NO_TILE_EXCLUDE equ 1

; Show the first 200 NES scanlines (the IIgs SHR screen height) from the top of
; the NES screen.  The C game draws the title into the top part of its 240-line
; nametable.
y_offset_rows equ 0
y_height_rows equ 25

y_offset equ 0
y_height equ {y_height_rows*8}
min_nes_y equ y_offset
max_nes_y equ 249

x_offset equ 16

; Keep this many NES scanlines at the top fixed (level name / status) while the
; playfield below them scrolls up.
HUD_FIXED_LINES equ 32
