"""Contact sheets: one picture per clip with a frame every half second (numbered in seconds),
to pick good in-points for trailer/edit.py.   python trailer/contact.py [clip names]
"""
import subprocess
import sys
from pathlib import Path

CLIPS = Path(__file__).resolve().parent.parent / "shots" / "trailer" / "clips"

names = sys.argv[1:] or sorted(p.stem for p in CLIPS.glob("*.avi"))
for name in names:
    out = CLIPS.parent / "contact" / f"{name}.png"
    out.parent.mkdir(exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(CLIPS / f"{name}.avi"), "-vf",
                    "fps=2,scale=320:-1,drawtext=fontfile='C\\:/Windows/Fonts/consolab.ttf':text='%{pts\\:hms}':"
                    "x=4:y=4:fontsize=18:fontcolor=yellow:box=1:boxcolor=black,tile=6x3",
                    "-frames:v", "1", str(out)])
    print(out)
