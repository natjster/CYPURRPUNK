"""CYPURRPUNK SOUND LAB: an MCP server that lets Claude make voice lines and sound effects.

Claude Code starts it by itself (it's listed in .mcp.json). Free and local: the only thing that
uses the internet is the text-to-speech voice (Microsoft Edge's free voices via edge-tts).
Files land straight in sounds/sfx/ (or sounds/music/, sounds/ambience/), where the game's Sound
system finds them by name on the next start.

  generate_overclean_voice   an OVERCLEAN city-speaker announcement (chime + robot + PA echo)
  generate_cat_voice_blips   Animal Crossing style talking-cat syllables for an NPC
  generate_ps1_sfx           crunchy retro effects (bin clatter, cone bounce, scratch, chime...)
  list_sounds                what's already in the sounds folders

All the real work is in tools/cypurr_sound.py (which also runs from the command line).
Needs: pip install mcp numpy edge-tts ; ffmpeg.
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cypurr_sound as lab  # noqa: E402

try:  # mcp 2.x
    from mcp.server.mcpserver import MCPServer as _Server
except ImportError:  # mcp 1.x
    from mcp.server.fastmcp import FastMCP as _Server

server = _Server("cypurrpunk-sound-lab")


@server.tool()
def generate_overclean_voice(id: str, text: str, pitch_shift: float = -1.5, robot_strength: float = 0.45,
                             pa_reverb: float = 0.55, chime: bool = True, voice: str = lab.DEFAULT_VOICE,
                             folder: str = "sfx") -> str:
    """Make an OVERCLEAN announcement -> sounds/<folder>/<id>.wav (16-bit mono 22 kHz).
    text = what it says (calm, polite, passive-aggressive). pitch_shift = semitones (-12..12,
    negative = deeper). robot_strength 0..1 (ring modulator + metal comb). pa_reverb 0..1 (slap-back
    echo off the buildings + tail). chime = put the two-tone "ding-dong" in front.
    voice = any edge-tts voice name (default en-GB-SoniaNeural; e.g. en-US-MichelleNeural,
    en-US-ChristopherNeural). Name numbered takes like overclean_deploy_1, _2 to make the game
    pick one at random for Sound.play("overclean_deploy")."""
    return json.dumps(lab.overclean_voice(id, text, pitch_shift, robot_strength, pa_reverb, chime, voice, folder=folder))


@server.tool()
def generate_cat_voice_blips(id: str, base_pitch: float = 420.0, mood: str = "happy", count: int = 4,
                             seed: int = 1, folder: str = "sfx") -> str:
    """Make talking-cat syllables -> sounds/<folder>/meow_blip_<id>_1.wav .. _<count>.wav, played
    in the game with Sound.play("meow_blip_<id>") (a random one each time).
    base_pitch in Hz: tiny kitten ~650, normal cat ~420, Don Catleone ~150.
    mood: happy, grumpy, sly, nervous, bossy, sleepy, angry. seed = a different set of syllables."""
    return json.dumps(lab.cat_blips(id, base_pitch, mood, count, seed, folder=folder))


@server.tool()
def generate_cat_taunt(id: str, text: str = "Go lick yourself!", voice: str = "en-US-AnaNeural",
                       pitch_shift: float = 5.0, meow_pitch: float = 520.0, mood: str = "sly", seed: int = 3,
                       folder: str = "sfx") -> str:
    """Make a player cat's MEOW-button taunt -> sounds/<folder>/<id>.wav: a synthesised meow, then
    "text" said by a squeaky text-to-speech cat voice (pitch_shift semitones up), PS1-crunched.
    The game plays "cat_taunt" with each cat's own pitch (from its look)."""
    return json.dumps(lab.cat_taunt(id, text, voice, pitch_shift, meow_pitch=meow_pitch, mood=mood, seed=seed, folder=folder))


@server.tool()
def generate_ps1_sfx(id: str, preset_or_params: str, folder: str = "sfx") -> str:
    """Make a crunchy PS1 sound effect -> sounds/<folder>/<id>.wav.
    preset_or_params = a preset name: metal_bin_clatter, metal_clang, cone_bounce, plastic_tap,
    scratch, pa_chime, cardboard_thump, vacuum -- or JSON: {"preset": "cone_bounce", "pitch": 1.3, "bounces": 5, "seed": 2,
    "bits": 8, "hold": 2} (pitch = higher/lower, bits = crunch 8..16, hold = 1..4 lower sample
    rate; preset knobs: rattles, bounces, strokes) or a custom recipe:
    {"duration": 1.0, "hits": [{"time": 0, "gain": 1, "seconds": 0.5,
      "modes": [[freq_hz, decay_seconds, amplitude], ...],
      "noise": {"gain": 0.5, "decay": 0.02, "low": 1000, "high": 6000}}]}"""
    params = json.loads(preset_or_params) if preset_or_params.strip().startswith("{") else preset_or_params.strip()
    return json.dumps(lab.ps1_sfx(id, params, folder))


@server.tool()
def list_sounds() -> str:
    """List every sound file the game has, by folder (sfx / ambience / music)."""
    lines = []
    for folder in ("sfx", "ambience", "music"):
        path = os.path.join(lab.SOUNDS_DIR, folder)
        files = sorted(f for f in os.listdir(path) if f.endswith((".wav", ".ogg", ".mp3"))) if os.path.isdir(path) else []
        lines.append("%s/ (%d): %s" % (folder, len(files), ", ".join(files)))
    return "\n".join(lines)


if __name__ == "__main__":
    server.run()
