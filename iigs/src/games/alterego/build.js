#!/usr/bin/env node
'use strict';

/**
 * build.js -- Alter Ego title-screen PoC build script
 *
 * 1. Generate the palette management (palettes.s, pal_transitions.s, pal_defs.s)
 *    from palettes/.
 * 2. Convert the CHR-ROM held by PPU.s into the 64KB tiledata bank and assemble
 *    the game.  The NES code is the original HEAD C build at $8000-$FFFF,
 *    placed by rom.s; the support/shim code is below $8000 in the same bank.
 */

const path = require('path');
const { generatePalettes, PaletteError } = require('../../../scripts/generate-palette-transitions.js');
const { buildNromGame } = require('../../../scripts/lib/nromBuild.js');

const palettesDir = path.join(__dirname, 'palettes');
try {
  generatePalettes({
    transitionsFile: path.join(palettesDir, 'transitions.txt'),
    palettesDir,
    outDir: __dirname,
  });
} catch (e) {
  if (!(e instanceof PaletteError)) throw e;
  console.error(`Error: ${e.message}`);
  process.exit(1);
}

buildNromGame(__dirname, 'AlterEgo.s');
