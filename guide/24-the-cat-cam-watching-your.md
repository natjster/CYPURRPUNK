# 24. The CAT-CAM: watching your crew after a knockout or an early extract

[Back to the contents page](../SETUP_GUIDE.md)


Got knocked out, or extracted early? You don't have to stare at a sewer wall while your friends
finish the raid. You can **watch them**, over their shoulder, live.

**How you start watching**
- **Knocked out up top:** once you wake up in the sewer, the screen switches to a teammate who is
  still up there by itself (after 1.5 seconds). Not when the DEEP CLEAN flattens everybody at once.
- **The CAT-CAM TV:** a chunky old TV with rabbit ears on a crate on the **east wall**, right across
  the water from the Mainframe (in both gangs' sewers). Walk up and press **E**:
  "[E] WATCH CREW UP TOP". If nobody is up top it says **NOBODY UP TOP RIGHT NOW**.
- **Already had your trip this district?** Just press **JUMP** (Space / pad A) anywhere in the sewer.
  The top line tells you: "THE SEWERS - WAIT FOR THE NEXT DISTRICT   [SPACE] WATCH CREW".

**While you watch** (the top of your screen says who, and which buttons do what):
| Button | What it does |
|---|---|
| **A / D** (or the left stick) | the previous / next cat up top (only shown when there are two or more) |
| **M** (pad **B**) = MEOW | **HECKLE over the walkie-talkie**: a radio squawk, your cat's voice, and a line like **"WHISKERS (RADIO): BEHIND YOU!"** types out over the watched cat's head, in the city, for everyone. **VAC-COPs within 18 m hear the radio and come to look**, so think before you heckle! (3 seconds between heckles.) |
| **E** or **JUMP** | back to your own cat in the sewer, any time (shop, litterbox, feed the Mainframe), then E at the TV or JUMP again to go back |

- You see **exactly what they see**: every cat now shares where its camera points, so online you look
  the same way your friend is looking. In a car (driving or riding along) you get the car's chase camera.
- The fog, rain, moon and city music switch to the city while you watch.
- Your cat stands still in the sewer while you watch (A / D won't walk it into the water).
- **Who you can watch:** in co-op, everyone up top. In TURF WAR, your own gang while any of them are up
  top; once your whole gang is home, you can watch the **rival** gang instead.
- Watching stops by itself when the last cat up top extracts or gets knocked out (if you were watching
  someone who left, it jumps to the next cat still up there), and when a SEWER BREACH siren starts.
- Split screen: each couch player watches on their own part of the screen.

**Tuning (Inspector)**
- **Main > Spectator** (`scripts/spectator.gd`): Knockout Spectate Delay (1.5 s), Knockout Spectate
  Timeout, Button Grace Seconds, Jump To Watch After Trip (untick it to keep JUMP as a plain jump),
  **Heckle Lines** (add your own!), Heckle Cooldown, Heckle Heard From (18 m), Heckle Color, Heckle
  Height / Car Height (how high the line floats), Heckle Hold Seconds, Heckle Letters Per Second, and
  the squawk sound (`sounds/sfx/radio_squawk.wav`, made with the Sound Lab) + its loudness.
- **Main > Hub** (and **GangHub**) **> CAT-CAM TV**: Catcam Spot (where you stand; the TV is built
  just east of it against the wall), Catcam Radius, Catcam Prompt, Catcam Glow (the screen colour).

**Testing** (Godot console exe from the project folder, `--path . -- ...`):
- TV, switch, heckle, back to the sewer: `--host --add_local=2 --spectate --heckle --spectate_switch
  --spectate_exit=20 --frames=30 --capture=shots/x.png` (prints "DevCapture spectate" / "heckle" lines).
- Knocked out, then auto-watch: `--host --add_local=1 --spectate_ko --frames=30 --capture=shots/x.png`
- Watching someone in the car: add `--spectate_car`.
- Online (camera look really arrives): host `--host --spectate --frames=100`, ~4 s later client
  `--join --deploy --yaw=90 --pitch=-10 --frames=400` (host prints "spectate look ... yaw=1.57 (sent 1.57)").
- Screenshot: windowed `--host --name=WHISKERS --add_local=1 --spectate --heckle --frames=150 --scale=3
  --capture=shots/spectate_cam.png`.
