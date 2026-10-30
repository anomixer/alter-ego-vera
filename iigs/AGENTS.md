# AGENTS.md — Alter Ego / Apple IIgs work log

This file is the working log and hand-off for the **Apple IIgs (silky-gs)** port. It supersedes the
archived `//e` notes in the repository root. Dates are Asia/Taipei.

## Status at 2026-10-30

- `iigs/emu/AlterEgoJml.2mg` boots in GSplus; verified: title, credits, sound test, pause menu, level 1,
  and the game → pause → EXIT GAME → title round trip.  Hashes are in the table under the 2026-10-30
  entry; rebuild recipes are in "Rebuilding `prg.bin` from the C sources".
- Sound test: **Tab** opens and closes it, row 23 reads `MUSIC ON  SFX00 BGM00`, the selected pair is
  pale yellow, **Left/Right** pick the field, **Up/Down** change the value, **Space** (or X) auditions
  it, **Z** stops the music, **Return** leaves and starts the game.
- Known gap: on the user's machine X/Z still need Caps Lock; the shim accepts every encoding tried and
  GSplus runs fine without Caps Lock, so that layer was not changed again — the sound test no longer
  depends on X/Z (see "Open issue" below for the pending diagnostic).
- Exchange-move sea stripes: **fixed and reproduced/verified** (see the 2026-10-30b entry below).
- Credits screen: rows tightened, the IIgs credit added, held 6 s — see the 2026-10-30c entry.
- 2.8 MHz: renders fit in one VBL (`renderVblTicks` = 1) and music is VBL-driven at 60 Hz — measured,
  not assumed; details in the same entry.

## 2026-10-30b — exchange-move sea stripes fixed; 2.8 MHz performance measured

### Bug — stray stripes in the sea during the A/B exchange move

- **Root cause**: the swap sets `player_flash_cnt=2` on every frame while the two egos move
  (`game_apop1.c`, `player_exchange==1`), and the NES flash wrote `pal_col($3F15..$3F17)`
  alternating `$21`/`$27`.  Those NES sprite-palette entries alias onto the IIgs SHR slots the
  background palettes also fill (`BG2` uses slots 0,7,8,9, `SP1` 0,3,7,9, `SP2` 0,13,14,3), so
  the flash recoloured the water.  The 50-frame `DONE_NOLUCK` flash did the same.
- **Reproduced twice, once through the real code path**:
  - unconditional `pal_col` replay: whole sea band orange-striped —
    `docs/screenshots/exchange_sea_before.png` (8,000 px of `255,170,68` replacing the blue rows);
  - the decisive run: keep the *original* flash code and force the game's own trigger
    (`i|=PAD_A; exchange=5;` every 64 frames in the play loop, so the swap / blocked-swap flash
    runs as it does for a player).  46 captured frames at 2.8 MHz → **23,696 orange px** in the
    sea band, up to **2,780 px in one frame** (`docs/screenshots/exchange_sea_old_path.png`).
    Same harness with the fixed flash → **0 orange px in all 46 frames**
    (`docs/screenshots/exchange_sea_fixed_path.png`, and `..._wave.png` mid wave-toggle).
- **Fix**: no palette writes and no palette-bit switching — the flash blinks the ego sprites
  (see "Follow-up: the flash must not repaint the ego either" below for the final form).
- The bug is intermittent because a `pal_col` change makes `DetectNESPalette` miss, so
  `LoadPaletteColors` walks the entries and the aliased slots leak into the background; when a
  known palette is applied the same writes are invisible.
- `level_params[level<<1]` holds the exchange count (`game_apop1.c:206`): levels 0/1/2 = 2,
  3 = 0, 4 = 3, 5 = 4, 8 = 8 …  So level 1 *does* have two exchanges and is a valid test
  level; the earlier "A does nothing on level 1" run was a synthetic key that GSplus never
  delivered to the shim, not an `exchange==0` level.  Driving the trigger from inside the game
  (`i|=PAD_A; exchange=5;`) always reproduces the flash.

### Follow-up: the flash must not repaint the ego either

- The first fix flashed by switching the OAM palette bits (`|1` ↔ `|2`).  On screen that paints
  the ego with the **next** sprite palette — measured colours for the ego sprite:
  palette 0 → head `255,255,255` + body `119,187,255` (white head, pale-blue clothes = correct),
  the flash's alternate palette → head `255,119,85` + body `221,187,255` (**red head, white
  body**) — exactly what the user reported during an exchange.
- "Sometimes" was a second bug: `player_flash_cnt` is re-armed every frame of the swap, so the
  last evaluated value stayed in `player_atr`, leaving the ego on the wrong palette after the
  move until it walked again (the code only rewrites `player_atr` on movement/idle).
  Side-by-side evidence: `docs/screenshots/ego_flash_palette_compare.png` (left = the flash's
  alternate palette, red head / white body; right = the correct white head / blue clothes).
- **Final fix**: the flash is now a *visibility blink* — `if(player_flash_cnt) player_flash_cnt--;`
  plus the ego draw condition `(!start_delay||(start_delay&8))&&(!player_flash_cnt||(frame_cnt&1))`.
  Both egos blink (they share the palette, as in the NES original), the palette bits never change,
  so the ego keeps white head / blue clothes for the whole move.  The 50-frame `DONE_NOLUCK`
  (drowning) flash does the same with the sprite-0 off-screen row (`0,255,0,0`).
- **Verified** with the same forced-exchange harness, 70 frames at 2.8 MHz: sea = 0 orange px;
  ego colours observed = white `255,255,255` only (plus frames where the ego is blinked off);
  `255,119,85` / `221,187,255` / `187,34,0` never appear.
- Sprite-palette cheat sheet (colours measured on the ego sprite itself): the ego's own palette
  is the only one that renders white head `255,255,255` + pale-blue body `119,187,255` (the
  normal look, confirmed on the shipped build at level start); the other three sprite palettes
  give red head `255,119,85` + pale body `221,187,255`, magenta `255,0,255`/green `34,153,0`, and
  dark-teal `0,68,68`/grey `187,187,187`.  Flash by blinking, never by moving the ego onto
  another sprite palette.

### Performance at 2.8 MHz — measured, not assumed

- Two instruments, both left in the tree but disabled:
  - `RENDER_VBL_COUNT equ 1` (Config.s) draws `renderVblTicks` at the top-left (SHR $2000);
    its colour was `#$FFFF` (palette 15, never written ⇒ invisible) and is now `#$0303`.
  - `SHOW_DEBUG_VARS equ 1` (Config.s) draws fps/input/dirty/full counters (masks fixed, below).
- At `g_limit_speed = 2` the VBL digit reads **1** every frame ⇒ a full render fits inside one
  VBL interval (< 46,666 cycles), i.e. no frame overrun.
- The FamiTone2 update (`crt0_silky.s` NMI continuation: `jsr FamiToneUpdate`) is driven by the
  VBL once per NES frame, independent of the C game loop ⇒ music ticks at 60 Hz exactly while
  renders stay inside one VBL interval.
- The sea animation toggles every 16 game frames; measured 0.24–0.26 s at 2.8 MHz ⇒ ≈60–62 game
  frames/s.
- **Conclusion**: the port is not CPU-bound at 2.8 MHz.  GSplus on this VM caps at
  `Eff MHz: 2.55`, so the earlier "16 MHz" sessions were also ~2.55 MHz effective — the 16 vs
  2.8 comparison was meaningless.  A remaining stutter on other machines is an audio-path or
  host-speed question, not the renderer.

### Build-system trap — `src/game/` is dead for this game

Merlin32 resolves `put` paths relative to the **link file's directory**
(`src/games/alterego`), so the engine really reads `src/games/alterego/game/{Config.s,Hooks.s,...}`
and `src/games/alterego/{ppu,rom,core}/*.s`.  `stageEngineFiles` in `nromBuild.js` writes
`src/game/*`, which this build never sees (proved by putting a deliberate syntax error there:
the build still succeeded).  Behaviour changes must go into `src/games/alterego/game/Config.s`
and `src/games/alterego/{ppu,rom}/*.s`; the `src/game/*` and `src/ppu/*` copies are kept in sync
for source consistency only.

### Files touched

- `src/games/alterego/game_apop1.c` — flash fix (exchange + `DONE_NOLUCK`), comments explain the
  slot aliasing.
- `src/games/alterego/ppu/ppu.s` + `src/ppu/ppu.s` — `bne as_bitmap_clip` (145 bytes, over the
  127-byte limit once `SHOW_DEBUG_VARS` is on) replaced with `beq *+5` / `brl`.
- `src/games/alterego/ppu/ppu_frame.s` + `src/ppu/ppu_frame.s` — `_ShowDebugInfo` masks from
  palette-15 `$FFFF` to `$3333/$2222/$1111` (per-byte nibble masks leave digits striped).
- `src/rom/scaffold.s` + `src/games/alterego/rom/scaffold.s` — `RENDER_VBL_COUNT` digit colour
  `$FFFF` → `$0303`.
- `prg.bin` 32,768 B, SHA256 `C4CB044597B065F39E3435EF60869A6653ED388287B557B3087EFDB0C3AAD84D`
  (byte-reproducible);
  `AlterEgoGS` 313,213 B; `emu/AlterEgoJml.2mg` repacked
  (SHA256 `A3861EC1E71EECD272E086D25F5F3F0DFED84D38797ACD2491150343DB158C7C`, 10,485,824 B).
  The app/2mg are **not** byte-reproducible across rebuilds even with an identical `prg.bin`
  (the Merlin build embeds build-time data), so compare `prg.bin`, not the image hash.
  Verified booting at `Limit: 2.8Mhz` into level 1 (`docs/screenshots/level1_28mhz.png`).

## 2026-10-30c — credits screen: tighter rows, IIgs credit, 6 s hold

The credits screen is a compressed nametable, not a text block, so "just edit the lines" means
regenerating the array.  Everything below was measured or derived, not guessed.

### How `credits[]` works

- `credits_screen()` does `unrle_vram(credits,0x2000)` — the array is RLE VRAM that unpacks to
  **1024 bytes = 960 nametable bytes (32x30) + the 64-byte attribute table** (`$23C0..$23FF`), so one
  array carries both the glyphs and the colours.
- RLE format: `data[0]` is the tag (`$01`); a literal byte is stored as-is, and `tag,count` repeats
  the previous byte `count` **more** times.  The count is one byte, so a run longer than 256 must be
  emitted as several `tag,min(rest,255)` chunks — a naive encoder silently drops the tail and still
  looks plausible (the round-trip check in the generator catches it).
- Glyph codes (read out of the existing data): `A..P` = `$80..$8F`, `R..V` = `$6B..$6F`, `X` =
  `$7B`, `Y` = `$7C`, `Z` = `$7D`, `0..9` = `$F0..$F9`, space `$00`, `"` = `$FC`/`$FD`
  (opening/closing), and the copyright sign is the two cells `$7E,$7F`.
  Generator: `scripts/gen-credits.py`.
- Colour constraint: an NES attribute quadrant is 2 tiles tall and 2 wide, so rows 4k,4k+1 share one
  palette and 4k+2,4k+3 the next — two vertically adjacent single-height text rows **cannot** have
  different colours.  Leaving exactly **one** blank row between lines puts every line in its own
  quadrant, which is how the original screen alternated colours.  Measured palette ids: **3 = blue**,
  **1 = red with a yellow highlight**, **2 = deeper red/salmon without the highlight** (the original
  used 2 for `ALEX SHABANOV` — keep it).
- A false start is worth remembering: compacting the block to ten consecutive rows (no blank rows at
  all) fits and looks tidy in a screenshot, but it forces the colours to group in pairs and leaves a
  big empty area at the bottom — rejected by the user.  Keep one blank row.

### Final layout (all rows at text column 3)

| row | palette | text |
|---|---|---|
| 7  | 3 blue | `ORIGINAL ZX SPECTRUM GAME` |
| 9  | 1 red  | `(c) 2011 DENIS GRATCHEV` |
| 11 | 3 blue | `NES CONVERSION BY` |
| 13 | 1 red  | `SHIRU` |
| 15 | 3 blue | `NES MUSIC BY` |
| 17 | 1 red  | `RICHARD "KULOR" ARMIJO` |
| 19 | 3 blue | `HACKED BY` |
| 21 | 2 red  | `ALEX SHABANOV` |
| 23 | 3 blue | `APPLE IIGS VERSION BY` |
| 25 | 2 red  | `ANOMIXER 2026` |

- The block keeps the original first row (7) and bottom row (25) and the original one-blank-row
  rhythm; the two 3-row gaps before `NES CONVERSION BY` / `NES MUSIC BY` are gone (those headers
  moved up by 2 and 4 rows), which frees exactly the space for the two IIgs lines under
  `ALEX SHABANOV`.  `scroll(0,8)` is unchanged.
- Holding time: `credits_screen()` used `j=150` frames (2.5 s).  `j` is **`unsigned char`**
  (`game_apop1.c:376`), so writing `j=360` silently wraps to 104 — use a local `unsigned int hold`
  instead.  Now 360 frames = **6 s**, measured on the repacked image (fully drawn 6.03 s; harness
  `tmp/bench/timcred5.ps1 <out> rel28.kegs`).  START still skips the screen.
- Automation trap: `tmp/bench/rep28.kegs` boots **`AEBench.2mg`**, `rel28.kegs` boots
  `emu/AlterEgoJml.2mg`.  A stale bench image silently invalidates timing checks — repack
  `AEBench.2mg` before capturing, or time the release image directly.
- Evidence: `docs/screenshots/credits_iigs_version.png` (captured at `Limit: 2.8Mhz`).

## 2026-10-30 — sound test: Tab toggles back, spacing, yellow sprite digits

### What was done

- **A second Tab now closes the sound test.**  The in-loop `PAD_START` break fell through to the
  game-start path; the loop now sets `back_to_title` on `PAD_SELECT` and the close path clears the
  readout (`oam_clear`), restores `MUSIC ON/OFF` and `START LEVEL` with `title_draw_menu()` /
  `title_draw_level()`, restarts the title music unless muted, and `goto title_menu_again` (a label
  added at the top of the title menu loop) so the menu resumes instead of fading out.
- **Row 23 layout** (columns): the `MUSIC ON` label keeps its normal column 10 (`MUSIC ON` spans
  10–17, `MUSIC OFF` 10–18), so `ON` is followed by **two blank columns** and `OFF` by **one** — the
  row can never read `OFFSFX`.  `SFX` sits at 20–22, `BGM` at 26–28, and each value is glued to its
  label (`SFX00`, `BGM00`) with one blank column between the two fields.
- **The counter digits are OAM sprites**, not background text, exactly as in the original NES build:
  tiles `$F0–$F9` (the sprite-table copy of the digit glyphs) at columns 23–24 and 29–30.  Background
  attributes are 16×16 blocks, so background digits could only be recoloured together with the
  neighbouring `X` and blank cells; sprites leave every other cell untouched.
  OAM y is **175**: row 23 starts at scanline 184, the title scrolls `y=8` (the background moves up a
  tile, sprites do not), and the sprite renderer puts the first sprite line at `y+1`.
- **Selection colour**: the selected pair uses sprite palette 1, the other pair palette 2.
  `src/games/alterego/palettes/title.txt` sprite rows are now
  `SP1: $0F $01 $27 $38` (body `$38` = the logo's pale yellow, outline `$01` like the menu text) and
  `SP2: $0F $01 $11 $21` (identical entries to BG0, so the unselected digits match `MUSIC`/`SFX`
  exactly).  `SP0` (the `▶` cursor) and `SP3` are unchanged, and all BG rows are untouched — no other
  colour on the title screen changes.  `node build.js` regenerates `palettes.s`, `pal_defs.s` and
  `pal_transitions.s` from these files.
- `title_draw_sound_values()` is called once per frame in the sound-test loop (the NES original
  redraws its sprites every frame too), so the yellow follows Left/Right as well as value changes;
  the `oldpx`/`oldpy` bookkeeping is gone.

### Fix — the game's palette no longer stays on the title screen (the yellow digits turned red)

- **Symptom:** play a level, EXIT GAME back to the title, press Tab: the `SFX00`/`BGM00` digits came
  back in red/orange instead of yellow/light blue, and the menu text was a paler blue.
- **Cause:** the engine identifies a NES palette by the colours it holds (`PAL_*_MATCH`) and switches
  the slot layouts with it (`ApplyPaletteChange` → `DetectNESPalette` → `UpdatePalette`).
  `fade_screen_in(palTitleBG)` uploads its single 16-byte argument to **both** the background and the
  sprite palettes, so on the title the run-time sprite palettes are the four BG rows of `palTitleBG`
  (`$0F $01 $11 $21`, `$0F $16 $27 $38`, `$0F $06 $16 $26`, `$0F $11 $21 $31`).  `title.txt`'s SP
  rows were a copy of `palSprites`, so `PAL_TITLE_MATCH` could not match the title once another
  palette had been detected: `palCurrent` stayed on the level palette and the title was drawn through
  the level's slot layout (pale text, red digits).  At start-up it looked right only because
  `SetDefaultPalette` installs the title layout without detection.
- **Fix:** `palettes.h` gains `palTitleSPR[16]` holding the same four sprite rows as `title.txt`, and
  `fade_title_in()` (`game_apop1.c`) fades BG to `palTitleBG` and the sprite palettes to
  `palTitleSPR`; `credits_screen()` and `title_screen()` call it instead of `fade_screen_in()`.  The
  title's run-time sprite palettes now equal `title.txt`, so detection succeeds after a level and the
  digits keep palette 1 (yellow) / palette 2 (menu blue).
- **Do not "fix" this by making the SP rows equal the BG rows** (that was the first attempt): the
  palette generator rejects it (`title: the slot that BG3[3] is shown in is never loaded` — BG3[3]
  is `$31~$21`, shown in `$21`'s slot, and duplicating BG3 in SP3 makes the layout assign `$31` a
  slot no cell loads), and it would also give the `▶` cursor the BG0 colours instead of its grey
  `SP0: $0F $0C $10 $30`.  The separate sprite palette array is what keeps both.

### Fix — `_pad_poll` accepts X/Z however the keyboard reports them

- The shim already took both cases (`$58`/`$78`, `$5A`/`$7A`), plus the Ctrl-X/Z codes
  (`$18`/`$1A`) and the raw ADB keycodes (`$07`/`$06`), and both cases were verified through GSplus
  (`x x` / `z z` move the title cursor, `r2_*`, `t1_*` with 5 ms taps).  A user still reported that
  X/Z needed Caps Lock everywhere; that is the symptom of only the upper-case code being recognised,
  so the top bits a keyboard/ROM/emulator puts into `$C000` (case bit 5, strobe bit 7, some set
  bit 6) must not matter.
- `_pad_poll` now ends the key chain with `and #$1F` and compares `$18` (X) / `$1A` (Z), so any
  encoding whose low five bits are the letter works.  No other key collides: Tab `$09`, Return
  `$0D`/`$24`, Space `$20`, `P` `$50`/`$70`, the arrows `$08`/`$0A`/`$0B`/`$15` all keep distinct
  low five bits (the side effect is that `8` also reads as X's low bits and `:`/`;`+Shift as Z's).
  `neslib_silky.s` is assembled with `ca65 --cpu 65816` and the object is linked from
  `build/silky/tmp_verify/neslib_new.o` — **rebuild that object whenever the shim changes**, or the
  shipped PRG keeps the old one.
- Verified in the rebuilt image (`k3_*` in `iigs/tmp/variant_test/`): lower-case `x`, lower-case `z`
  and `8` (low-five-bit X) each move the title cursor one line, and the sound test after a level
  round trip still shows `SFX00` yellow / `BGM00` blue.

### Sound test: Space auditions the selection

- The user's keyboard still delivers X/Z only with Caps Lock on, so the sound test had no key that
  both works everywhere and plays.  **Space** is the NES A button (the same bit as Z), which made it
  "stop the BGM"; the shim now also exports `_pad_space` (a `BSS` byte set to 1 by `_pad_poll` only
  when the key being read is Space, reset to 0 at the start of every poll), so `game_apop1.c` can tell
  the two apart: **Z** keeps `music_stop()`, **Space** (like X) auditions `sfx_play(px,0)` /
  `music_play(musicData[py])`.  Left/Right select the field, Up/Down the value, Space plays, Tab
  closes — the sound test needs no X/Z.
- Watch the branch range: the new `lda #$00 / sta _pad_space` prologue pushed the `beq @no_key` after
  `lda $E0C010` past ±128, so it is now `bne @k0` + `jmp @no_key`.
- Verified (`sp_*` in `iigs/tmp/variant_test/`): Tab → sound test, Space ×2 (SFX00), Up Up → `SFX02`
  + Space, Right + Up → `BGM01` yellow + Space, Tab → title, Tab → sound test again.  The loop keeps
  redrawing throughout (`SFX02`/`BGM01` are on screen after the Space presses).  The generated
  `game_apop1.s` shows the branch: `and #$02 / bne play`, then `and #$01 / jeq skip`, then
  `lda _pad_space / jeq skip` — B (X) or Space+A plays while A alone (Z) stops.

### Open issue — X/Z still need Caps Lock on the user's machine (not reproducible here)

- Reported three times: on the user's machine `x`/`X` and `z`/`Z` do nothing until Caps Lock is
  pressed once, in every screen (title, in game, pause menu, sound test).  Not reproducible with this
  image in GSplus: `x x`/`z z` (lower case, no Caps Lock, 5 ms and 60 ms taps) move the title cursor,
  `_pad_poll` accepts `$58`/`$78`/`$18`/`$07` and `$5A`/`$7A`/`$1A`/`$06` **and** now matches the low
  five bits (`$18`/`$1A`), which covers any case/strobe/modifier bit pattern.  So the byte reaching
  `$C000` on that machine is not a variant of the ASCII/ADB code we know, or the emulator's keyboard
  layer swallows the letter keys — it is **not** the game logic as far as this port can tell.
- If it comes back, the next diagnostic is a throw-away build that draws `$C000 & $7F` as two hex
  digits on the title screen and compares a Caps Lock-off `x` with a Caps Lock-on `x`; that settles
  keyboard layer vs. game layer in one press.  The sound test no longer depends on X/Z (Space plays),
  which was the user's workaround.

### Verified (GSplus captures in `iigs/tmp/variant_test/`)

- `tabtoggle_*`: title → Tab → `MUSIC ON  SFX00 BGM00` → Tab → menu, cursor back on START GAME,
  title music resumed.
- `sel_*`: the `MUSIC OFF` variant reads `MUSIC OFF  SFX00` (one blank column, never `OFFSFX`);
  Right moves the yellow from `SFX00` to `BGM00`; Up changes the selected value to `03` while it
  stays yellow; Tab returns to the menu with `MUSIC OFF` preserved.
- `start_*`: Return in the sound test still starts level 1 (`HELLO WORLD`).
- `r2_*`: title → `x x` (lower-case x, no Caps Lock) moves the cursor START GAME → START LEVEL →
  MUSIC, `z z` moves it back; Tab → sound test → Right selects BGM; Return starts a level, pause →
  Down Down → Return (EXIT GAME) → title → Tab: `SFX00` yellow, `BGM00` light blue, and the title
  before/after the round trip has an identical colour histogram (`cmpimg.py`, 804 differing pixels =
  cursor/animated art only).  So both key cases reach `_pad_poll` and the title palette survives a
  level.
- Automation note: GSplus only sees the PC arrow keys when they are sent with
  `KEYEVENTF_EXTENDEDKEY` (`keybd_event(vk, scan, 1, 0)`); without the flag only Tab/Return reach
  the game.

### Current artifacts (updated)

| Item | Value |
|---|---|
| Image | `iigs/emu/AlterEgoJml.2mg`, 10,485,824 bytes |
| Image SHA-256 | `927B87B50054E86F6CAE99B975BD10D5274D886C503512874BAF6D2E1C1683C3` |
| App | `iigs/src/games/alterego/AlterEgoGS`, 313,125 bytes |
| App SHA-256 | `50C6AF9E3817FFBD56395CEDD724638A3F9511F339AC8AB9F116094D19E40A39` |
| PRG SHA-256 | `99B84E1F6787324993E67F49B26599616C0D9B484B50FD8DAC0A7F08E327D800` (`prg.bin`, 32,768 bytes) |

## 2026-10-29 — silky-gs v0.0.2 and animated sea

### What was done

- Fetched silky-gs tag **`v0.0.2` (`0c341d2`)** and merged its engine changes into `iigs/src`:
  `apu/apu.s`, `core/CoreImpl.s`, `core/Defs.s`, `core/Graphics.s`, `core/blitter/JoyProbes.s`,
  `misc/io.s`, `rom/rom_config.s`, `rom/rom_config_setup.s`, `rom/rom_exec.s`, `rom/rom_input.s`,
  `rom/rom_kbd_basic.s`, the new `rom/rom_kbd_macs.s`, and `runtime/head.txt` / `runtime/code.txt`.
- Preserved the port's own changes: `rom_exec.s` keeps `yieldFrame` and the `switchTask` `jmpl`
  bank fix; `core/Defs.s` keeps `YOffsetDyn=100` / `LayoutActiveDyn=102`; `scaffold.s` keeps its
  startup border diagnostics and `Fail` loop, plus the v0.0.2 `KBD_*` guards, `engineVideoOn` clear
  and APU render counter.
- `Main.s` now expands `rom_kbd_macs.s`; J13/ADB are disabled in `runtime/code.txt`, matching
  v0.0.2's BASIC-only default.  The config screen now opens with Shift-/ in the automated GSplus
  test and the engine suspends interrupts while it is open.
- Restored the sea animation without the 12 fps full-screen CHR toggle:
  - `chr.bin` page-0 tiles `$E0–$E3` contain the page-1 water art; `game_add_background` preserves
    the low two bits of `TILE_WATER`, and the every-16-frames pass rewrites only the water
    nametable cells with `vram_adr`/`vram_put`.
  - The water tiles deliberately stop before `$E4`: that tile is the HUD's `×` glyph (the stats
    meta-sprite and the `×5`/`×2` counters).  An earlier `$E1–$E4` layout overwrote it and made the
    top-left counters unreadable; moving the four wave variants to `$E0–$E3` fixed the HUD while
    keeping the sea animation.
  - The map scan uses a pointer (`mp = map; spr = *mp++`) because the generated 6502 indexing did
    not carry across a 256-byte page boundary.
- Palette layouts for game 1–5, GAME OVER and WELL DONE were regenerated; gameplay now has a
  blue-clothed player, green wall plants and blue/cyan water (no red sea line).
- **START LEVEL now accepts 0**, the hidden Cow Level.  The original NES trigger was Select+Start,
  but this port uses Select (Tab) for the sound test, so 0 is selected with Left/Right on the
  START LEVEL row.  The initial/default value remains 1, and START GAME still forces level 1.
- **X/Z input hardened**: the port previously had separate upper/lowercase comparisons but the
  user still had to tap Caps Lock before each X/Z.  `_pad_poll` now accepts `X`/`x`, `Z`/`z`,
  Ctrl-X/Ctrl-Z (`$18`/`$1A`) and the raw ADB Z/X codes (`$06`/`$07`); Caps Lock is never required.
  `ca65 --cpu 65816` is required when reassembling `neslib_silky.s` because it contains `phk`/`plb`.

### Verified

- New build boots from `emu/AlterEgoJml.2mg`; the title has the correct ALTER EGO logo colours, and
  Return on START GAME starts level 1; Return on START LEVEL with `00` starts the Cow Level.
- Shift-/ opens the control panel; the v0.0.2 interrupt suspend/resume path is active.
- Water animation frames differ at the 16-frame cadence and repeat with the expected period.
- HUD counters verified after the CHR fix: `shot_hudfix_a.png` shows `×5` and `×2` beside the
  player/ego icons, and the sea still animates (`shot_hudfix_a/b/c.png` differ in the water rows).
- Cow Level verified from a level-0 build: `shot_cow0_2cow.png` shows the distinct **COW LEVEL**
  banner and map, while normal builds still begin at level 1 (`shot_finalcheck_a.png`).
- X/Z case/repeat check on the new build: repeated X without Caps Lock moved the cursor
  `START LEVEL 01` → `MUSIC ON` → `SOUND ON`; Caps Lock followed by two X presses also worked
  (`shot_caps_1x.png`, `shot_caps_3x.png`, `shot_caps_6capsxx.png`).  The sound-test pass produced
  `SFX 00 BGM 00`, `SFX 01 BGM 00`, `SFX 01 BGM 01`, and Return entered Level 1
  (`shot_keyfix_1sound.png` … `shot_keyfix_6game.png`).

### Artifacts at 2026-10-29 (superseded by the table above)

| Item | Value |
|---|---|
| Image | `iigs/emu/AlterEgoJml.2mg` |
| Image size | 10,485,824 bytes |
| Image SHA-256 | `359D8C446C97FA827DE056092C47A2A17D3304DFC9841367340C01487F829A16` |
| App | `iigs/src/games/alterego/AlterEgoGS`, 312,895 bytes |
| App SHA-256 | `539383CD0D7ED2E7445DC185C65E1D623CBEA32105ACF06063DCD2B98E738DB7` |
| PRG input | `iigs/src/games/alterego/prg.bin`, exactly 32,768 bytes (E0 water, Cow menu, FamiTone build, X/Z aliases) |
| PRG SHA-256 | `007DD13EB35795A74C35617763D202B4430DA4D39AD7580BFE3542C2D2D656BB` |
| CHR SHA-256 | `7656616C52D4ACC34C745CAFB99B664CD49D4E4F4DBBCE7ED58ECA03EABCB1C0` |
| GSplus config | `iigs/emu/gsplus-alterego-jml.kegs` |

## 2026-10-27 — snapshot and branch `test/gs`

### What was done

- Created branch **`test/gs`** from `master` in `C:\dev\alter-ego-vera`.
- Copied the working `C:\dev\silky-gs` tree (the port actually used for the current image) into
  **`iigs/`** in this repository, preserving the silky-gs-relative paths so the build scripts still
  resolve:
  - `iigs/src/`, `iigs/scripts/`, `iigs/macros/`, `iigs/tests/`, `iigs/plans/`, `iigs/docs/`
  - the generated Merlin32 listing/map files (`*_Output.txt`, `*_Symbols.txt`) were **not** copied;
    they are regenerated by the build and are gitignored.
  - `iigs/emu/AlterEgoJml.2mg` and `iigs/emu/gsplus-alterego-jml.kegs` are the current review image
    and its GSplus config.
  - a few reference captures are in `iigs/docs/screenshots/`.
- Fixed the copied GSplus config so `s7d1` points at
  `C:\dev\alter-ego-vera\iigs\emu\AlterEgoJml.2mg` rather than the old `C:\dev\silky-gs` path.
- Updated `iigs/package.json` `config.cadius` to the Cadius in this environment
  (`C:\dev\cadius.exe`).

### Previous committed image (2026-10-27, superseded by the table above)

| Item | Value |
|---|---|
| Image | `iigs/emu/AlterEgoJml.2mg` |
| Size | 10,485,824 bytes |
| SHA-256 | `8A10009113D6A5FE87B350488B895E2E9ACF30368C56AE17BD800885F0F03E3D` |
| App | `iigs/src/games/alterego/AlterEgoGS`, 268,275 bytes |
| App SHA-256 | `57B7483BF9140F57E4391B66EDED7C516824CB0A4560FF0DFC94615790672606` |
| PRG input | `iigs/src/games/alterego/prg.bin`, exactly 32,768 bytes (audio-enabled FamiTone build) |
| SHA-256 (PRG) | `28328DB5D17093BC5A40A30007CE811A3EA2EE2D0683CF95BDF667E1F9956855` |
| GSplus config | `iigs/emu/gsplus-alterego-jml.kegs` |

Current screen evidence: `iigs/docs/screenshots/shot_final_aligned_game.png` (gameplay),
`shot_final_credits.png` (centred credits), `shot_final_title.png` (centred title with PRESS START)
and `shot_config_menu.png` (runtime options menu).

### Current visual/audio state

- Boots; Return at the title starts level 0.  Music and SFX are enabled and audible in GSplus
  (host loopback capture RMS 3532, peak 27610).
- Final layout: one continuous gameplay band, SHR lines 0–199 sourced from NES rows 16–215
  (`Config.s`: `y_offset equ 16`).  The HUD stats, outer frame and playfield share that band; there
  is no separate HUD source range and no blank strip below the frame (it ends flush on SHR line 199).
- The title/credits keep their own full-screen treatment with `YOffsetAbs = 31`, lifting the logo and
  text into the 200-line SHR area.  The title path calls `NES_SetScroll` with the latched
  `_ppuscroll_x/_ppuscroll_y` before `PPU_DrawScreenRange`, so the 16-frame nametable toggle that
  blinks **PRESS START** is preserved.
- Dirty-grid rendering is enabled (`ENABLE_DIRTY_RENDERING=1`, `GRID_COMPACT_SPRITES=1`).  Background
  cells are emitted by the grid; the compact sprite mapping keeps OAM screen coordinates (stats,
  player/enemies, pause menu) aligned with the NES 16–215 band.  The C fallback full renderer uses the
  same `YOffsetAbs = 16`.
- `HELLO WORLD` and the man/ego counters are in the fixed top band; the playfield does not scroll.
  Player/enemy sprites and the pause menu are visible, and the player moves with input.
- Pause entry dims the palette and draws RESUME/RESTART as sprites; resuming restores the palette,
  clears the menu OAM and redraws the stats.  Up/Down selects, Return confirms.
- Audio root cause found and fixed: FamiTone's `$7E30` APU trampolines were actually assembled at
  `$7E2D`, and FamiTone is 8-bit code.  The table is now padded to `$7E30` and `crt0` sets `sep #$20`
  before the FamiTone init calls.  This eliminated the `Emulated state corrupt` crash.

### Runtime options and hidden inputs (2026-10-27)

- `iigs/src/games/alterego/Config.s` now sets **`NO_CONFIG equ 0`**.  The stock
  Audio/Input/Drivers/Credits panels are present; `CONFIG_VIDEO_MENU=0`,
  `CONFIG_GAME_MENU=0`, `CONFIG_INPUT_2P=0` and `JOYSTICK_SUPPORT=0` remain off.
- The menu is opened with **`?`**.  Before v0.0.2, `[System.Windows.Forms.SendKeys]::SendWait('?')`
  was the reliable automation path and synthetic Shift-`/` was not.  With the v0.0.2 input layer,
  explicit Shift down + `keybd_event` for `/` (VK 191 / scan 0x35) opens it consistently; use that
  for the current build.
- **Cow Level verified** by holding Tab and pressing Return at the title
  (`shot_cowlevel.png` locally; the level 0 layout is visibly different).
- **Sound Test** and the **B, Left, A, B, Left, A** level-skip sequence come from the
  original `src/game.c` title logic (`py=1` / `code_str`); they were **not captured**
  through GSplus because the host Command/Option injection was unreliable.  The README
  documents the logical keys and the GSplus swap caveat instead of claiming an
  emulator capture.
- Menu Return exits back to the game without changing the rendering layout; the
  gameplay capture after Return is unchanged.

### Rebuilding `prg.bin` from the C sources (2026-10-30 recipe)

`iigs/src/games/alterego/game_apop1.c` and `prg.bin` are the two files in this repository that are
*built elsewhere*: the C/PRG staging tree is `C:\dev\alter-ego\build\silky` (not in the repo), and
`palettes.h` (the 16-byte `palTitleBG` / `palTitleSPR` / `palSprites` / `palWellDone` arrays) lives
only in `build/silky/work`.  `game_apop1.c` is reference-only in the repo; it is compiled with `-I .`
from that work directory.

```powershell
# 1. the keyboard/palette/OAM shim (65816: phk/plb) -- rebuild its object every time it changes,
#    the linker does not notice the .s on its own
cd C:\dev\alter-ego\build\silky
& C:\dev\cc65\bin\ca65.exe --cpu 65816 neslib_silky.s -o tmp_verify\neslib_new.o

# 2. the game C -> 6502 -> 32,768-byte PRG
cd work
& C:\dev\cc65\bin\cc65.exe -Os -I . -I .. game_apop1.c
& C:\dev\cc65\bin\ca65.exe --cpu 6502 game_apop1.s -o game_fixed.o
& C:\dev\cc65\bin\ld65.exe -C ..\nes_silky.cfg -o prg_fixed.bin ..\crt0_silky.o `
    ..\tmp_verify\neslib_new.o game_fixed.o ..\audio_silky.o C:\dev\cc65\lib\nes.lib

# 3. put it where the Merlin build picks it up, then rebuild the app and repackage
Copy-Item prg_fixed.bin C:\dev\alter-ego-vera\iigs\src\games\alterego\prg.bin -Force
cd C:\dev\alter-ego-vera\iigs\src\games\alterego
node build.js
```

`prg.bin` must stay exactly 32,768 bytes; `ld65` prints one harmless `sp` deprecation assertion and
cc65 prints three pointer-signedness warnings from `game_apop1.c` on every build.  Keep
`build/silky/neslib_silky.s` and `iigs/src/games/alterego/neslib_silky.s` byte-identical (copy after
editing), and the same for `game_apop1.c`.

### Build (verified in the snapshot)

```powershell
cd C:\dev\alter-ego-vera\iigs\src\games\alterego
node build.js
```

The verified output is:

```
MAIN         23732 -> 22319 bytes
STKDP        6470 -> 65 bytes
ENGINE       31638 -> 26789 bytes
PPU1         61787 -> 58426 bytes
PPU2         61787 -> 58427 bytes
CHRDATA      65606 -> 62730 bytes
AEROM        65828 -> 31766 bytes
PPURAM       16454 -> 7753 bytes
AlterEgoGS: 333302 -> 268275 bytes
```

`package.json` `config.merlin32` is `C:\dev\Merlin32.exe`; `config.cadius` is `C:\dev\cadius.exe`.
`PROJECT_ROOT` is inferred from `scripts/lib/nromBuild.js`, so the build must run from inside the
`iigs/` tree.

### Repackage image

```powershell
cd C:\dev\alter-ego-vera\iigs
New-Item -ItemType Directory tmp\repackage -Force | Out-Null
Copy-Item src\games\alterego\AlterEgoGS 'tmp\repackage\AlterEgoGS.S16#B3DB03' -Force
& C:\dev\cadius.exe REPLACEFILE .\emu\AlterEgoJml.2mg /ALTEREGO 'tmp\repackage\AlterEgoGS.S16#B3DB03'
```

Cadius takes the ProDOS type from the `#B3DB03` suffix; staging the file as plain `AlterEgoGS.S16`
replaces the file as `UNK $0000` and the image will not launch correctly.  Use `REPLACEFILE` (not
`ADDFILE`) to replace the existing `/ALTEREGO/AlterEgoGS.S16`, and confirm with `CATALOG` that the
entry reads `S16 $DB03`.

### Run / screenshot

```powershell
Start-Process C:\dev\emu\GSplus\gsplus.exe `
  -ArgumentList '-cfg', (Resolve-Path C:\dev\alter-ego-vera\iigs\emu\gsplus-alterego-jml.kegs)
```

Wait about **24 seconds** at 16 MHz (or **2–3 minutes** with `g_limit_speed = 2`, the factory
2.8 MHz), focus the GSplus window, then send **Return once** at the title. Earlier Returns are lost.  For the options menu, focus the window and send `?` with
`SendKeys`; see the runtime-options section above. Screenshot with the GSplus `MainWindowHandle`
and `CopyFromScreen`; raise the window to topmost before capture if the DSH GUI overlaps it.

## Hard constraints found in this port

### `y_offset`, dirty grid and sprite alignment

The working configuration is:

- `iigs/src/games/alterego/Config.s`: `y_offset equ 16`, `GRID_COMPACT_SPRITES equ 1`
- `iigs/src/games/alterego/ppu/ppu_grid_quads.s` (the game-local copy actually built): the
  `gqInitTables` Y loop skips the `sbc #y_offset` when `GRID_COMPACT_SPRITES=1`
- `Main.s` gameplay: `YOffsetAbs=16`, return C=0 so the grid draws; no `NES_SetScroll` and no
  `StartY=16`

Two traps, both seen in this port:

1. If the custom renderer returns C=0, `RenderScreen` calls `_SetScroll` again from the latched
   `_ppuscroll` *after* the custom code.  Setting `StartY=16` inside the custom renderer is therefore
   discarded; the source offset must be the configured `y_offset`, not the runtime start line.
2. The C side puts OAM in SHR screen coordinates.  With `y_offset=16`, the grid must not subtract 16
   again for sprites; without the compact flag the menu/stats and player sprites move or go negative
   and GSplus reports `Code: RED Emulated state corrupt`.  Keep `GRID_COMPACT_SPRITES=1` in the
   built copy and verify the game-local `ppu_grid_quads.s`, not just `src/ppu/`.

The 2.8 MHz target and the 16 MHz build use the same single gameplay band; the title/credits are the
only screens drawn with `YOffsetAbs=31`.

### Conditional blitter scrolling is unsafe

Adding a `cmp #HUD_FIXED_LINES` / conditional `add_y_offset` in
`iigs/src/core/blitter/BlitterLite.s` caused GSplus **`Emulated state corrupt`**, a black screen or a
System 6 reboot. Both macro-local and inline variants failed. The three `add_y_offset` sites are back
to unconditional. Do not retry the same per-line conditional in the blitter without a different
strategy.

### `POST_RENDER` direct SHR writes

A `POST_RENDER` hook that wrote a bottom border directly into `$E1/2000 + row*160` also led to a
corrupt boot (likely a bad/stale `ScreenY1`/address path during the title). That code was removed.
If a border/overlay is needed later, it must be gated on a valid game screen and verified in GSplus.

### Audio

The current image is built from the **audio-enabled FamiTone PRG** (`prg.bin`, SHA-256
`28328DB5…`). The earlier `Emulated state corrupt` crash was fixed by padding the APU trampoline
table to `$7E30` and keeping the FamiTone init in 8-bit mode (`sep #$20`). A host loopback capture
of GSplus gameplay measured RMS 3532 / peak 27610, so the current build is audible; do not replace
`prg.bin` with the old audio-off baseline.

### Emulator / packaging gotchas

- Launch GSplus with `-cfg <file>`, **not** `-kegs`.
- `cadius` uses `REPLACEFILE`; `LIST` is invalid (`CATALOG` is the listing command).
- Do not move/resize the GSplus window; capture the existing window rectangle.
- `prg.bin` must be exactly 32,768 bytes; `__ROM0_LAST__` is `00F6B3`.

## Repository boundaries

- `iigs/` is the self-contained silky-gs snapshot for this port. Edit
  `iigs/src/games/alterego/...` for game changes; engine edits go under `iigs/src/core`,
  `iigs/src/ppu`, `iigs/src/rom`.
- `iigs/src/game/` is build scratch created by `stageEngineFiles`; it is gitignored. Never edit the
  staged copies, edit the game's own `Config.s`/`Hooks.s`/`EngineExt.s`.
- Merlin32 listing/map files are regenerated; don't commit them.
- The original `//e` material in the repository root is archived; do not resume it unless the user
  explicitly reopens it.

## Push status

- Branch **`test/gs`** is the working branch, pushed to
  `https://github.com/anomixer/alter-ego-vera` (`origin`).
- History: `f47dc3e` centred-title docs → `b81c827` centred layout/audio PRG → `d3da372` runtime
  options menu → `4d98258` water animation and palette fixes → `81c4193` silky-gs v0.0.2 → `133888f`
  title-screen SFX/BGM test docs → `3f5aca4` both key cases and alternate X/Z codes → `723e82a`
  yellow sound-test selection, SFX gap, repackaged image → `c11ba88` restore `3f5aca4`.
- 2026-10-30 commit adds the title-palette fix (`palTitleSPR` + `fade_title_in`), the low-five-bit
  X/Z match, the `pad_space` byte so Space auditions the sound test, the regenerated palette tables
  and the repackaged `emu/AlterEgoJml.2mg` / `AlterEgoGS` / `prg.bin`.  See the artifacts table at the
  top of this file for the hashes.
- The existing VERA port at the repository root was not modified; `iigs/` is additive.
- Untracked files (`iigs/docs/screenshots/*`, `iigs/emu/AlterEgoOld.2mg`,
  `iigs/src/games/alterego/credits.h`) are investigation captures/generated headers and are not part
  of the deliverable — do not add them with `git add -A`.

## Next steps

1. The sound test is finished: Tab opens it, a second Tab closes it, Space auditions the selection,
   Left/Right pick the field, Up/Down change the value, Return starts the game.
2. The title palette is stable across a level round trip; keep `palettes/title.txt`'s SP rows and
   `palettes.h`'s `palTitleSPR` in sync — changing one alone re-breaks detection (symptom: the digits
   come back red/orange and the menu text goes pale after EXIT GAME).
3. Keep `prg.bin` a 32,768-byte, audio-enabled FamiTone build produced by the recipe above; never
   replace it with the historical audio-off baseline.
4. Open, not reproducible here: X/Z needing Caps Lock on the user's machine (see the section above);
   next action is the throw-away hex readout build if it is reopened.
5. Still uncaptured: GAME OVER / WELL DONE and levels 2–5 with the current palette layouts.

## Provenance

The engine files under `iigs/` come from Lucas Scharenbroich's silky-gs
(`https://github.com/lscharen/iigs-game-engine`, Apache-2.0). The upstream README is preserved at
`iigs/docs/SILKY-GS-UPSTREAM-README.md`; the NES/Alter Ego game material keeps its original project
licensing. This branch is a port snapshot, not a relicensing of upstream.
