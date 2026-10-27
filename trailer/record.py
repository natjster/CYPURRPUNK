"""Films the trailer's gameplay clips with Godot's Movie Maker.

Each SHOT below is one run of the game with DevCapture options (see scripts/dev_capture.gd,
"TRAILER CAMERA"). The game records itself at a steady 30 fps (slow PCs just take longer)
and the clip is saved to shots/trailer/clips/<name>.avi (video + game sound).

Run from the project folder:
    python trailer/record.py              (films every shot)
    python trailer/record.py city_orbit   (films only the shots named)
"""
import subprocess
import sys
from pathlib import Path

GODOT = r"C:\GoDot\Godot_v4.7.2-stable_win64_console.exe"
PROJECT = Path(__file__).resolve().parent.parent
CLIPS = PROJECT / "shots" / "trailer" / "clips"
SIZE = "1280x720"  # 16:9; the game picture is 240 game pixels tall, widened to fit
SEED = 1999  # every shot happens in the same city

# Our hero cat: the Rambo cat (pale cyan fur, pink mohawk, cigar, bandolier), the same in every shot.
HERO = "--wear=hat:mohawk,face:cigar,neck:bandolier,fur:#bfeff0"

# name: DevCapture options. Every shot is a solo/host game; --frames = clip length (30 = 1 s).
CINE = f"--host --deploy --no_hud {HERO}"  # a clean cinematic shot up in the city
HUB = f"--host --no_hud {HERO}"  # a clean shot down in the sewer hub (floor at y = -200)
PLAY = f"--host --deploy {HERO}"  # gameplay with the HUD, through the cat's own camera

SHOTS = {
    # --- THE CITY ---
    "city_orbit": f"{CINE} --pos=0,0,4 --cam_orbit=0,4,0,26,12,-30,20 --frames=210",
    "avenue_crane": f"{CINE} --pos=0,0,10 --yaw=0 --hold=move_forward --hold_delay=30 --hold_frames=240 "
                    "--cam_from=0.5,0.8,14 --cam_to=0,10,20 --look_from=0,1.5,0 --look_to=0,3,-60 --frames=240",
    "street_walk": f"{CINE} --pos=0,0,-20 --yaw=180 --hold=move_forward --hold_delay=5 --hold_frames=200 "
                   "--cam_follow --cam_from=1.5,1.2,-3.5 --cam_to=-1.5,0.8,-3 --frames=180",
    "zoomies": f"{CINE} --pos=0,0,-30 --yaw=180 --hold=move_forward,sprint --hold_delay=20 --hold_frames=200 "
               "--cam_follow --cam_from=0.8,0.5,5 --cam_to=-0.6,0.9,4 --frames=150",
    "meow_mart": f"{CINE} --pos=-6,0,-2 --cam_orbit=-12,2,-6,11,1.5,40,80 --frames=180",
    "grab_fish": f"{PLAY} --grab=fish --frames=90",
    "grab_koi": f"{PLAY} --grab=golden_koi --frames=120",
    # --- THE SEWER HUB ---
    "hub_reveal": f"{HUB} --cam_from=-4,-195.5,19 --cam_to=-1,-197.8,-2 --look_from=2,-198,-10 --look_to=8,-199.1,-16 --frames=240",
    "don_push": f"{HUB} --pos=-8,-200,14 --cam_from=8.6,-198.9,-11.5 --cam_to=8.2,-199.0,-14.1 --look_from=8,-199.1,-16 --look_to=8,-199.0,-16 --frames=180",
    "don_talk": f"--host {HERO} --talk --frames=150",
    "whiskers_push": f"{HUB} --pos=-8,-200,14 --cam_from=-6.5,-198.3,-11.2 --cam_to=-8.4,-198.6,-10.3 --look_from=-12,-199.1,-10 --look_to=-12,-199.0,-10 --frames=180",
    "shop": f"--host {HERO} --cash=1200 --talk=ComradeWhiskers --choose=0 --frames=150",
    "mittens": f"{HUB} --pos=-8,-200,14 --cam_orbit=10.3,-199.2,9,2.6,0.4,-120,-60 --frames=150",
    # --- THE VAC-COPS ---
    "roomba_chase": f"{CINE} --pos=0,0,-20 --yaw=0 --bait_roomba=6 --hold=move_back,sprint --hold_delay=25 --hold_frames=200 "
                    "--cam_follow --cam_from=1.2,0.4,4 --cam_to=-0.8,0.6,3 --look_from=0,0.4,-3 --look_to=0,0.5,-3 --frames=150",
    "gunfight": f"{PLAY} --give=tommy_gun --pos=0,0,-20 --yaw=0 --pitch=-8 --bait_roomba=aim --hold=shoot --hold_delay=15 --hold_frames=120 --frames=60",
    "gunfight_side": f"{CINE} --give=tommy_gun --pos=0,0,-20 --yaw=0 --pitch=-8 --bait_roomba=aim --hold=shoot --hold_delay=15 --hold_frames=120 "
                     "--cam_from=2.5,0.5,-19 --cam_to=2.2,0.7,-21 --look_from=-0.5,0.6,-22 --look_to=-0.5,0.4,-23 --frames=60",
    "boss_reveal": f"{CINE} --heat=100 --heat_hold=600 --roomba=boss --pos=0,0,-40 --yaw=0 --bait_roomba=8 "
                   "--cam_from=1.4,0.15,-39 --cam_to=0.9,0.25,-41 --look_from=0,0.6,-48 --look_to=0,1.4,-48 --frames=210",
    "boss_fight": f"{PLAY} --heat=100 --heat_hold=600 --roomba=boss --give=tommy_gun --pos=0,0,-40 --yaw=0 --pitch=-5 --bait_roomba=9 "
                  "--hold=shoot,move_back --hold_delay=20 --hold_frames=150 --frames=30",
    # --- WHEELS + GETTING OUT ---
    "car_drive": f"{PLAY} --pos=3,0,-6 --drive --hold=gas --hold_delay=30 --hold_frames=210 --frames=10",
    "car_cine": f"{CINE} --pos=3,0,-6 --drive --hold=gas --hold_delay=30 --hold_frames=210 "
                "--cam_follow --cam_from=4,1.5,-6 --cam_to=-3,2,7 --look_from=0,0.6,0 --look_to=0,0.6,0 --frames=240",
    "extract": f"{CINE} --grab=fish --heat=80 --near_exit=9 --hold=move_forward --hold_delay=20 --hold_frames=150 "
               "--cam_follow --cam_from=2.5,0.7,2.5 --cam_to=2,3.5,6 --frames=60",
    "extract_play": f"{PLAY} --grab=fish --goto_dropoff_after=10 --frames=150",
    # --- CO-OP + CATS ---
    "split4": f"--host --deploy {HERO} --join_pad=1,2,3 --hold_all --hold=move_forward --hold_delay=20 --hold_frames=180 --frames=10",
    "creator": f"--host {HERO} --menu=cat --frames=90",
}

# "Dress your cat" montage: the same orbit round a cat in the hub, a different outfit each time.
OUTFITS = [
    "hat:fedora,face:shades,neck:bell_collar,fur:#3a3a44",
    "hat:neon_halo,face:cyber_visor,fur:#f4f0e8",
    "hat:mohawk_green,face:cigar,neck:bandana,fur:#e08a3c",
    "hat:beanie,face:shades,fur:#8a5a3c",
    "hat:headband,neck:bandolier,fur:#202024",
    "hat:mohawk,face:cigar,neck:bandolier,fur:#bfeff0",
]
for n, outfit in enumerate(OUTFITS):
    SHOTS[f"outfit{n}"] = (f"--host --no_hud --wear={outfit} --pos=-8,-200,8 --yaw=0 "
                           f"--cam_orbit=-8,-199.45,8,1.5,0.15,{145 + n * 8},{190 + n * 8} --cam_fov=45 --frames=90")


def record(name: str, options: str) -> None:
    CLIPS.mkdir(parents=True, exist_ok=True)
    movie = CLIPS / f"{name}.avi"
    command = [GODOT, "--path", str(PROJECT), "--write-movie", str(movie), "--fixed-fps", "30",
               "--", *options.split(), f"--capture=shots/trailer/clips/{name}_end.png", f"--window={SIZE}", "--scale=1",
               "--fresh_profile", f"--seed={SEED}", "--name=MOHAWK", "--setting=music_volume:0.0"]  # (trailer music goes on top)
    print(f"== {name}")
    # Movie Maker films at the project's window size (1280x960 = 4:3). A temporary override.cfg
    # makes it 16:9 for this run only; it is deleted straight after.
    override = PROJECT / "override.cfg"
    width, height = SIZE.split("x")
    override.write_text(f"[display]\nwindow/size/window_width_override={width}\nwindow/size/window_height_override={height}\n")
    try:
        result = subprocess.run(command, capture_output=True, text=True, errors="replace")
    finally:
        override.unlink()
    for line in result.stdout.splitlines():
        if line.startswith("DevCapture") or "ERROR" in line or "recording" in line:
            print("   " + line[:200])
    if result.returncode != 0 or not movie.exists():
        print(result.stderr[-2000:])


if __name__ == "__main__":
    wanted = sys.argv[1:] or list(SHOTS)
    for shot in wanted:
        record(shot, SHOTS[shot])
