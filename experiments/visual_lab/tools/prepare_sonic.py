"""Compatibility entry point for the shared local character preparation pipeline.

Run Blender with --background --python tools/prepare_sonic.py as before.
Use prepare_character.py -- --character tails to prepare the authorized Tails model.
"""
import runpy
import sys
from pathlib import Path

if '--' not in sys.argv:
    sys.argv.append('--')
sys.argv.extend(['--character', 'sonic'])
runpy.run_path(str(Path(__file__).with_name('prepare_character.py')), run_name='__main__')
