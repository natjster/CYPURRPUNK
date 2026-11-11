# 6. Multiplayer

[Back to the contents page](../SETUP_GUIDE.md)


The game starts on the **start menu** (PLAY / SETTINGS / QUIT, see §10). **PLAY** goes to
**CHOOSE YOUR CAT** (§11), then **NEXT** to **SOLO / MULTIPLAYER**. **SOLO** starts a game just
for you (no network, nobody can join). **MULTIPLAYER** shows **HOST** (with an optional city #)
and **JOIN** (with the host's address).

**Game mode online:** the **MODE** row on the landing page (CO-OP or TURF WAR, §8 "Game modes")
only counts for the computer that HOSTS. Everyone who joins plays the host's mode: the host sends
it to each computer as it connects, before the city number, so a late joiner gets it too. The
network game list shows **TURF WAR** after a game's name when it's one. (A joiner who wants to
pick a gang for a TURF WAR game sets their own MODE to TURF WAR first, so the gang rows show.)

### Play two cats on one PC
1. In Godot, open the **Debug** menu > **Customize Run Instances...**
2. Tick **Enable Multiple Instances**, set the count to **2**, click OK.
3. Press **F5**. Two game windows open (drag one aside; they start on top of each other).
4. Window 1: **PLAY** > pick a cat > **NEXT** > **MULTIPLAYER** > **HOST**. Window 2: the same
   but pick a **different cat** (both windows share your saved cats, and two windows playing the
   same cat would overwrite each other's cash + stash), leave the address as `127.0.0.1` and
   click **JOIN**.
5. Click into a window to control that cat. Esc opens the pause menu and frees the mouse, so you
   can switch windows.

Each cat gets its own fur colour (host is always ginger) and a name tag over its head.

**Your cat name:** you name your cat on the CHOOSE YOUR CAT screen (up to 12 characters; NEXT
won't let you go on without one). Everyone else sees it floating over your cat.
Either player can drive the car; the other sees it move. Only one cat fits in the car.

*Shortcut:* in the same Customize Run Instances dialog, you can give instance 1 the launch
argument `--host` and instance 2 `--join` to skip the menu (`--name=Whiskers` names the cat,
`--seed=42` picks the city; `--solo` starts a solo game).

### Play with other computers on the same Wi-Fi/network (up to 8 players)
1. Host clicks **PLAY > (cat) NEXT > MULTIPLAYER > HOST**. If Windows asks about the firewall,
   allow **Private networks** (the game uses UDP ports **7777** for playing and **7778** for
   finding games).
2. On the other PCs, click **PLAY > (cat) NEXT > MULTIPLAYER**. Under JOIN, **ON YOUR NETWORK**
   lists every game being hosted nearby, e.g. `WHISKERS  #4242  3/8` (host's cat, city number,
   players). Click it (or pick it with the d-pad + A). A full game says FULL and can't be picked.
3. Not listed (a picky router or firewall)? On the host PC run `ipconfig`, note the **IPv4
   Address** (e.g. `192.168.1.23`), type it into the JOIN box and click **JOIN**.

Up to 8 players in total: e.g. 8 computers, or 2 computers with 4 couch players each (§10).

### Play with a friend in another house (Invite Codes)
No router setup needed on most home internet:
1. The host clicks **HOST** as normal. If Windows asks about the firewall, click **Allow**. The
   game quietly asks the router to open UDP port 7777 (this is called UPnP) and a few seconds later
   shows `ONLINE READY! INVITE CODE: MEOW-499A-21B0`.
2. The host presses **Esc** (or START) and clicks **COPY CODE**, then sends the code to their
   friend by text or Discord. The button says `OPENING ROUTER PORT...` while the router is thinking.
   In split screen it's in player 1's small pause menu.
3. The friend goes to the HOST / JOIN screen, copies the code, clicks **PASTE CODE**, then **JOIN**.
   (Or: pick the box, type the code on the on-screen keyboard, or press Ctrl+V / its PASTE key.
   `MEOW-` and the dashes are optional, and normal IP addresses still work.)

The port closes again when the host leaves the game. The code is the host's internet address in
disguise, so only share it with people you trust, and expect it to change now and then (internet
providers change it). Don't try your own code from your own house: many routers can't do that.
Test it from a phone hotspot or a friend's house.

**If it says `ROUTER WOULD NOT OPEN UP` (the button says COPY LAN CODE):** that code only works on
your own network or VPN. Try these, easiest first:
1. Turn on **UPnP** in your router's settings page (often `192.168.1.1`; the sticker on the router
   has the address and login), then host again.
2. Install **Tailscale** (free) on both PCs and sign in to the same network. The host's code then
   works for the friend, with no router changes. This also solves **CGNAT**, where your internet
   provider shares one address between many homes and no router setting can help. (Mobile hotspots
   and some fibre and rural providers do this.)
3. On the router page, forward UDP port 7777 to the host PC by hand, look up your public address
   (search "what is my IP"), and send that to your friend.

Script side: all of this is in `scripts/net.gd` (`upnp_status`, `room_code`, `ip_to_code`,
`code_to_ip`). Test: `--test-room-code` (headless), `--host --fake_upnp=73.154.33.176` or
`--fake_upnp=off` (test runs never touch the real router), `--join --address=MEOW-7F00-0001`.

### Bigger games get more of everything (balance knobs)
The more players, the busier the city (counted on the host, players on every computer):

| What | Where (select the node in `main.tscn`, Inspector) | Default |
|---|---|---|
| Extra VAC-COPs for every player beyond the 2nd | **Roombas** > Extra Roombas Per Player | 2 (8 players = +12) |
| Heat rises faster per extra cat up top | **Heat** > Heat Per Extra Cat | 0.05 (+5% each) |
| Loot grows back faster per extra player | **Items** > Regrow Faster Per Player | 0.15 (8 players = about 2x) |

The script side: `Game.instance.player_count()` is how many players the game has right now.

### Network traffic (how often positions are sent)
Cats and the car send where they are **30 times a second**, VAC-COPs **20 times** (everyone's
copies glide smoothly in between). To change it: open `scenes/player.tscn` (or
`getaway_car.tscn`, `roomba.tscn`) > select **MultiplayerSynchronizer** > Inspector >
**Replication Interval** (seconds between updates: 0.033 = 30/sec, 0 = every frame).
Measured: a full 8-player game (2 computers x 4) = the host sends about **12 KB/s**; with 8
separate computers about 85 KB/s. Easy for any home network or Wi-Fi.
Second stress test (2026-10-29, after PvP): 8 players on 2 computers x 4, both gangs, heat 80,
both exits open, both main players shooting rivals, a payphone call, mass knockouts: same city,
manholes and gangs on both computers, 59-60 fps, the client received about 25 KB/s, no errors.
It found cats sent home at the same moment from two computers landing on the same spot (one got
shoved metres up into the air): each player now starts looking for a free spot at a different
place (`hub.gd free_spawn_position`).
Stress test (2026-10-29): 8 players on 4 computers (4 + 2 + 1 + 1, both gangs), heat held at 95
(about 38 VAC-COPs incl. 3 MEGA VAC-COPs), everyone up top: the host sent **about 89 KB/s** and
received 19 KB/s; each other computer received **about 29 KB/s**. All 4 game windows (on ONE PC)
held **60 fps**; the host's physics took about 3 ms a frame. Every computer had the same city and
saw all 8 cats with the right gang. A 9th computer was turned away ("That game is full").
Test: `--net_stats=600` prints KB/s sent / received; `--track=150` shows how smoothly other
players' cats move on screen.

### How it works
```
Net (autoload, scripts/net.gd)    <- host(), join(address), leave(); signals joined / join_failed / host_left
Main (Node3D)                     script: game.gd  <- starts games, spawns cats, catches up late joiners
├── Players (Node3D)               <- every cat lives here, named by PLAYER ID ("1" = host's first player)
├── PlayerSpawner (MultiplayerSpawner)   Spawn Path: ../Players, spawnable: player.tscn
├── LobbyCamera (Camera3D)         <- shows the city behind the start menu
└── PS1Overlay > Lobby (Control)   <- the start menu (§10)
```

- **Who controls what:** each computer moves only its own cat and sends the position to others.
  The car is simulated by whoever is driving it (by the host when it's empty). Everyone else's
  copy is frozen and just follows.
- **The host is the referee** for the car, item pickups/drops and fish deliveries, so two cats
  can't grab the same thing and nobody can give themselves cash.
- **If a player quits,** the host empties the car (if they were driving) and drops everything they
  carried where they stood. If the host quits, everyone returns to the start menu.
- **Finding a player's cat in code:** `Game.instance.cat_for(player_id)`, or `Game.instance.my_cat()`
  for your own (first) player, or `Game.instance.local_cats()` for every player on this computer.

### Player IDs (getting ready for split screen)
Split screen means one computer can have up to **4 players** (8 in a whole game). So the game
keeps two numbers apart (`scripts/player_id.gd`, class **PlayerId**):

| | What it means | Example |
|---|---|---|
| **Network ID** | which COMPUTER (Godot hands it out; host = 1) | `771171244` |
| **Player ID** | which PLAYER / CAT: network ID + seat on that computer | `771171244` (first player), `5066138540` (second player on that computer) |

- The **first** player on a computer has a player ID equal to the computer's network ID, so with
  one player per computer nothing looks different from before.
- **Everything per-player uses player IDs:** the cat nodes under Players, cash, HP, quests,
  inventories, stashes, who's driving. Each `request_...` sent to the host says which player it's
  for, and the host checks that player belongs to the computer that asked
  (`PlayerId.sender_owns(id)`), so nobody can move someone else's stuff.
- **Each couch player plays their own saved cat**, with its own cash and stash file (§8, "The stash
  & saved progress"). The couch is fixed for the whole game (no dropping in or out mid-game): a
  computer's players all come in together from the landing page, and leave together when player 1
  quits.
- **In code:** `PlayerId.make(network_id, seat)`, `PlayerId.peer_of(id)` (which computer),
  `PlayerId.slot_of(id)` (which seat, 0-3), `PlayerId.is_local(id)` (on this computer?),
  `PlayerId.first_local()`. A cat knows its own: `cat.player_id`, `cat.slot`.
  `Game.instance.add_local_player(seat, {"name", "look", "cat_id", "team"})` adds a couch player
  when the game starts (`remove_local_player(seat)` is only used by tests now).
- **Controllers:** couch players join with START on their own controller on the landing page,
  BEFORE the game (§10, "Couch co-op"), and each gets their own part of the screen (§13).
  Test them with DevCapture (these test players have no controller, so they stand still):
  `--add_local=1` (one more player joins in), `--as_local=1` (the test actions use that cat:
  `--grab`, `--goto_dropoff_after`, `--bait_roomba`...), `--remove_local=1` (they drop out).
- **Network log:** lines starting with `[Network]` appear in Godot's **Output** panel (joins/leaves).

### Smooth movement (interpolation)
Network updates arrive in bursts, especially over Wi-Fi. Instead of jumping to each update, other
players' cats and the car **glide** toward the latest position every frame.

- Knobs: select the Player (in `player.tscn`) or GetawayCar > Inspector > **Network Smoothing**.
  - **Network Smoothing**: higher = follows more tightly but shows more of the network's jerkiness;
    lower = silkier but trails slightly behind.
  - **Teleport / Snap Distance**: beyond this gap, jump instead of glide (e.g. after exiting a car).
- Measured with a simulated laggy connection (10 updates/sec): raw updates stood still on 126 of
  150 frames and jumped up to 52 cm at once; the cat on screen moved every frame, max 14 cm.

### Joining mid-game (another computer)
(A whole COMPUTER can still join a game in progress over the network, with the players it set
up on its landing page. Couch players can't drop in to a running game: §10.)
A player who joins late gets the city number first, then every **game system** (§16) sends what
it knows: who is driving the car, every item (on the street and in everyone's paws/bags), everyone's
quests, cash and HP, and the heat. Then their cat appears.

### Known limitations (planned for later)
1. **The host is trusted.** Fine for friends; a public game would need anti-cheat checks.
2. **One getaway car per gang** (4 seats each: a driver and 3 passengers), first come, first served.
3. **Your own cat's camera** moves at the physics rate (60/sec). On a 120 Hz+ monitor this can
   look slightly stuttery; Godot's built-in "physics interpolation" setting can fix that later.
