extends "res://scripts/dev_tests/dev_test.gd"
## DEV TOOL — takes a screenshot of the running game, saves it, then quits.
## Does nothing during normal play (it only wakes up when given --capture).
##
## Run from a terminal in the project folder, e.g.:
##   C:\GoDot\Godot_v4.7.2-stable_win64_console.exe --path . -- --host --capture=shots/street.png --pos=0,0,6 --yaw=0 --pitch=-12
## Options (everything after the lone "--"):
##   --capture=PATH    where to save the PNG (relative to the project folder)
##   --solo / --host / --join   start a game (otherwise you get the start menu)
##   --tutorial        start a TUTORIAL run (scripts/tutorial.gd); prints "[Tutorial] Step X/9" lines
##   --tutorial_auto   (with --tutorial) play all 9 steps by itself, print what happened, then quit
##   --tutorial_shots  (with --tutorial_auto, not headless) also save shots/tutorial_step1_arrow.png,
##                     tutorial_step8_payphone.png, tutorial_step8_exit.png, tutorial_step9_sewer.png, tutorial_done.png
##   --wait=N          wait N frames after our cat appears before doing anything else
##   --teams=A,B,..    the gang of seat 0, 1, 2... (0 = Catleone Family, 1 = Burrow Gang: teams.gd).
##                     Implies --mode=turf (gangs only exist in TURF WAR).
##   --mode=coop|turf  the landing page's MODE (CO-OP is the default; only --host / local games use
##                     it: a --join client always gets the host's). Wins over --teams' TURF WAR.
##                     Prints a "DevCapture mode" line.
##   --add_local=N     split screen: N more players join in on this computer (slots 1..N,
##                     named COUCH 2, COUCH 3... with random looks; their cats stand still)
##   --as_local=S      (with --add_local) every action below (--pos, --give, --grab, --drive,
##                     --goto_dropoff_after, --bait_roomba, --talk...) uses the cat in slot S instead
##   --remove_local=S  (at the very end, before the snap) the player in slot S drops out
##   --join_pad=N      couch co-op: seat a player on fake controller N (1, 2, 3) right after our cat
##                     appears, as if they'd joined in the lobby (tests only: there's no drop-in
##                     mid-game, scripts/seats.gd). Repeat: --join_pad=1,2
##   --spare_start=D   a REAL START press on spare controller D mid-game (should do nothing; with
##                     --unplug first it takes over the unplugged seat)
##   --pad_device=N    which fake controller --pad and --pad_press use (default 0)
##   --net_stats=N     measure network data sent / received per second over N frames (before the snap)
##   --unplug=D        (after --join_pad) controller D is unplugged; add --replug to plug it back in
##                     after the --pad_press presses (prints each player's pause state)
##   --pad_press_delay=N  wait N frames before the --pad_press presses (e.g. for the network game list)
##   --pos=X,Y,Z       move the cat here first
##   --yaw=DEG         turn the camera left/right
##   --pitch=DEG       tilt the camera up/down
##   --drive           put the cat in the car (car view)
##   --ride_along=S,S  (with --drive --add_local) those couch slots get in as passengers
##   --ride_exit=S     (with --ride_along) then that passenger gets out again
##   --car_mouse=PX    (with --drive) move the mouse PX screen pixels to the right while driving
##   --car_test / --car_chase / --gunner_test / --car_juice  (with --drive) car health, boost, chasing, gunner seat
##                     (scripts/dev_tests/cars.gd has the details)
##                     (the car camera turns); prints the camera's look angle
##   --car_watch=N     print the car camera's look angle every N frames until the snap
##   --talk[=NAME]     walk up to an NPC (node name, e.g. LilMittens; default Don Catleone)
##                     and press E (talk box open). A payphone (--talk=Payphone0) opens no box:
##                     the boss's line types out over the phone ("DevCapture payphone" line)
##   --choose=N,M      (with --talk) click talk-box button N, then M... (0 = top button)
##   --click_choice=N  (with --talk) a REAL mouse click on button N (tests clicks reach the HUD)
##   --talk_again_after=N  N frames after --goto_dropoff_after, talk to that NPC again
##   --wear=A:B,...    (with or without --look) wear exact parts / colours, e.g.
##                     --wear=hat:mohawk,neck:bandolier,fur:#808080
##   --portrait[=NAME] close-up of an NPC's face, no HUD (default Don Catleone; "me" = our own cat; "bot" = the
##                     bot --roomba picks, e.g. --portrait=bot --roomba=boss); tweak with
##                     --portrait_dist / --portrait_height / --portrait_side (metres), --portrait_fov
##   --bait_roomba=D   (host) put the nearest Roomba D metres in front of our cat
##   --zap_roomba=N    hit the nearest Roomba N times (34 each), as if shot (host or client)
##   --eye_test        shoot the picked bot once in its glowing EYE and once in its side (real rays, no
##                     rolled crit): prints "DevCapture eye_test" lines (the eye one must be crit=true)
##   --roomba=boss     (with --bait_roomba / --zap_roomba / --eye_test) use the MEGA VAC-COP instead of the nearest
##                     (--roomba=drone / trapper: the nearest SQUIRT-DRONE / LINT-TRAPPER)
##   --stun_roomba=S   (host) stun the picked enemy for S seconds, like a YARN-ZOOKA hit
##   --quest=ID        take that quest right away, with no NPC (works with --deploy, unlike --talk)
##   --abandon_quest   (with --quest) then press the inventory's ABANDON twice (only works in the hub)
##   --kill_roombas=N  (host) destroy N regular Roombas, as if shot (3 = the MEGA VAC-COP is called in);
##                     add --kill_bosses to destroy bosses too
##   --down=S          (host, after --deploy) the cat in slot S (0 = ours; 1.. with --add_local) stands
##                     1.5 m in front of us and takes 100 damage: DOWNED (or knocked out if nobody could help).
##                     --bleed_out=SEC changes how long it waits. Then --hold=interact on slot 0 = give up.
##   --down_loot=A,B   (with --down) put this loot in the downed cat's bag first (to test robbing)
##   --feedback_test   (host, up top: use --pos) PLAYER FEEDBACK: hurt to 20 HP (red edges + low-HP pulse),
##                     two loot toasts, then hitmarker + kill confirm every 0.3 s (so the snap catches one);
##                     prints "DevCapture feedback" lines (shake offset, flash, toasts, hitmarker)
##   --swing_test[=S]  (with --give=neon_bat) one connecting bat swing (trail, sparks, hit-stop) + a red hurt
##                     number, snap S seconds later (default 0.09: mid-slash). "DevCapture swing" line
##   --combo_test[=GAP] (with --give=neon_bat [--bait_roomba=2] [--air_slam]) 3 real bat swings GAP s apart:
##                     forehand, backhand, SLAM + shockwave (only weapons that CAN slam, with the meter full:
##                     --slam_charged fills it). "DevCapture combo" lines
##   --spin_test       (with --give=frozen_tuna [--bait_roomba=2]) the tuna's right-click SPIN ATTACK. "DevCapture spin"
##   --melee_test=scratch[:N] / throw / throw2  N claw swipes, or throw the boomerang bat (throw2 = both bats,
##                     with --give=neon_bat,neon_bat)
##                     (--give=neon_bat). "DevCapture melee" lines
##   --shoot_rival=N   walk up to the nearest cat of the other gang and hit it N times with our gun
##                     (needs --give=pistol); prints its health after each hit (PvP, cat_health.gd)
##   --rival_volley=N  (with --shoot_rival) land N hits in one frame, like a scattergun's pellets
##   --blast_car       set our gun's blast off right beside the nearest car (prints how it flew)
##   --blast_probe     print how many things a blast at our feet finds (street tiles and walls count)
##   --revive=N        (with --down=S, S > 0) our cat presses E on it and holds the button N frames
##                     (a cat of the OTHER gang = we ROB it instead)
##                     (180 = the 3 s revive); prints health / downed state before and after
##   --deploy          ask Don to send us up top (cat moves from the hub to the city)
##   --deploy_again=N  N frames after the above, ask Don AGAIN (one trip per district: refused once
##                     you've been up); prints went_up / in_hub / heat
##   --give=A,B        (host) put items straight into our paws/backpack (e.g. --give=pistol,catnip)
##   --cat_lineup[=res://x.tscn,...] the cat model (+ other cat scenes) side by side, own camera, no HUD
##   --coat_lineup[=a,b]  one cat per COAT pattern (tabby, tiger, calico... or only those named) side by side
##                     (--lineup_yaw=DEG turns them, --lineup_dist=M, --lineup_fov)
##   --weapons_lineup[=a,b] a display rack of the weapons (own camera) + "DevCapture weapon" lines
##   --to_stash=hand:0,pack:0   walk to the stash lockers and put those items in the stash
##   --from_stash=N    (at the lockers) take stash slot N into the backpack
##   --fresh_profile   start this test's saved cash + stash from scratch (user://test_profiles/)
##   --cash=N          (host) set our cash, and every joining player's, to $N (to test the Black Markitten shop:
##                     --cash=500 --talk=ComradeWhiskers --shop_buy=pistol; see _menus._shop_test for all the --shop_ flags)
##   --grab=ITEM       walk to the nearest ITEM lying around (fish, or something dropped) and press E.
##                     Repeat with a comma list: --grab=catnip,catnip (fire/use with --hold=shoot)
##   --drop_after=N    drop what's in the paws (G) N frames after the --hold finishes
##   --equip=N         take backpack slot N into the paws (what clicking it in the inventory does)
##   --inventory       open the inventory screen (Tab) before the snap
##   --test-room-code  (headless, no --capture) room code checks, prints PASS / FAIL, then quits
##   --fake_upnp=IP    pretend the router answered with this address; =off = it said no (net.gd)
##   --address=X       with --join: join this room code or address
##   --press_key=KEY   press and release a real key, e.g. --press_key=Tab (inventory) or Escape
##                     (--give=catnip --press_key=1 = quick use slot 1; prints the quick slots)
##   --jump_test       jump + double jump (needs catdip); prints the height and the front flip's
##                     spin. --flip_snap=shots/x.png [--flip_frame=N] saves a picture mid-flip
##   --moves_test      CAT MOVES (scripts/dev_tests/moves.gd): full jump vs short hop, run jump vs
##                     POUNCE, WALL KICK, CLAMBER onto a crate, in a test yard high above the city
##   --hold=ACTION     hold a control for --hold_frames (default 60), e.g. move_forward,
##                     starting after --hold_delay frames (default 30)
##   --exit_after=N    get out of the car N frames after the --hold finishes
##   --goto_dropoff_after=N   jump onto the exit manhole after N more frames (in the car if driving;
##                     it's only open with --heat=80 or more)
##   --near_exit=D     stand D metres south of our gang's exit manhole, facing it
##   --exit_team=N     (with --near_exit / --goto_dropoff_after) use gang N's exit instead of ours
##   MEOW-MART (scripts/interiors/meow_mart_interior.gd; use with --deploy so the cat is up top):
##   --test_meow_mart[=D]   stand D (4) metres out in the street from Meow-Mart's doors, facing them
##                          (add --hold=move_forward to walk in)
##   --inside_meow_mart[=W] stand inside the store: W = foyer (default) / plate / aisle / tank / backroom
##                          / counter / door (just inside the front doors, about to walk out)
##   --shatter_tank[=F]     (host) after F (30) frames break the koi tank: alarm, heat, ambush
##   --mart_log[=N]         print a "DevCapture mart" line every N (60) frames
##   --mart_swat=N          walk up to N can stacks and press E on each
##   --mart_topple=A        run (a fake zoomies bump) into the end of aisle A (1 or 2)
##   --mart_plate           stand on the security scale, then step off (prints the door each time)
##   --mart_drag            [E] DRAG the basket onto the scale, let go (prints the door)
##   --mart_tank_hits=N     press E on the tank N times (SCRATCH THE GLASS)
##   --near_speaker=D  stand D metres out in the street from the city's nearest OVERCLEAN loudspeaker
##                     pole, facing it; --announce[=moment] then makes OVERCLEAN say a line
##                     (boss, seal, level2..4, ko, deploy; default boss) -> "DevCapture speaker" lines
##   --mouse_test      check mouse-look gets the mouse through the game screen (prints how far it turned)
##   --track=N       measure how smoothly other players' cats move over N frames
##   --net_interval=S  simulate a laggy connection: send our cat's position only every S seconds
##   --frames=N        frames to wait before the snap (default 90 = 1.5 s)
##   --hud_heat=R[,L]  keep the guns in our right (and left) paw at this HEAT (0..1; 1 = OVERHEATED) so the
##                     bottom-left gun box shows it, e.g. --give=pistol,red_dot --hud_heat=0.3,0.9
##   --goop=D          drop a LINT-TRAPPER glue puddle D metres in front of the cat (to look at it; with --pos/--yaw)
##   --hud_buffs=LIST  switch on buff / debuff badges (top-left): sticky (held at 60%), catnip, catdip
##                     -> prints a "DevCapture hud loadout" line (what the gun box and badges show)
##   --scale=N         size of the saved image: each game pixel = N pixels (default 4 = 960 tall)
##   --window=WxH      window size for this run, e.g. --window=1720x720 to test an ultrawide shape
##   --setting=NAME:VALUE  change a setting for this run (never saved), e.g. --setting=split_side_by_side:false
##   --saved_cats=A,B  pretend you have more saved cats called A, B (for the couch lobby's cat picking)
##   --menu=NAME       open a menu first: cat (CHOOSE YOUR CAT; MY CAT in a game), mode (SOLO / MULTIPLAYER),
##                     coop (LOCAL / ONLINE CO-OP), local / online (the landing page), play (host / join),
##                     settings or pause (--settings_tab=N picks the tab)
##   --look=N          wear a random cat look made from seed N (as if picked in MY CAT; never saved)
##   --heat=N          (host) set the HEAT to N (0-100; 100 = MEGA VAC-COP) at the start and
##                     keep it there for --heat_hold frames (default: until the snap)
##   --heat_ramp=S     (host) raise the heat steadily to 100 over S seconds (every level, bosses, the seal)
##   --breach_seconds=S (host) a SEWER BREACH lasts S seconds (a short one tests THE 1% MIRACLE)
##   --breach_warning=S (host) the siren before a SEWER BREACH lasts S seconds
##   --breach_wipe=N   (host) N frames in, every cat in a breached sewer takes a killing blow (WIPEOUT)
##   --breach_log=N    (either) every N frames print the breach's state ("DevCapture breach" lines)
##   --breach_knock=N  (host) N frames in, drop a bot beside every breach NPC (they get knocked flat)
##   MESS-MAKING (scripts/mess_manager.gd; every one prints "DevCapture mess" lines):
##   --mess=N          our cat knocks over the N nearest standing props (bins/cones/boxes/posters), through the
##                     real request to the host (host or client)
##   --ram_prop=KIND   (KIND = bin, cone or box) stand 4 m from the nearest standing one, facing it, and RUN at
##                     it (zoomies for a bin) with real input: tests the bump check
##                     (--ram_trace prints the gap and speed every 3 frames while running at it)
##   --scratch         stand in front of the nearest poster and press E (Interactable.try_use)
##   --shoot_prop      hit the nearest standing prop through the Hit framework, like a bolt
##   --ghost           VAC-COPs can't see our cat (it's hidden: for watching them tidy up)
##   --face_mess       then stand 4.5 m from the first mess, looking at it (screenshots)
##   --bait_mess=D     (host, after the above) put the nearest VAC-COP that tidies D metres from the first mess
##   --mess_log=N      every N frames print the props and what the bots are doing (until the snap)
##   STREET PROPS PACK (KIND = vending, hydrant, cart, neon_sign, dumpster; "DevCapture prop" lines):
##   --use_prop=KIND   stand by the nearest standing one, facing it, and press E (prints prompt + what happened:
##                     knocked, geyser, cart rest spot, lid, glow, street drops beside it)
##   --shoot_prop=KIND hit the nearest standing one of that KIND through the Hit framework (no KIND = any)
##   --geyser_jump     (after a hydrant burst) step our cat into the geyser: prints how high it flew
##   --geyser_bot      (host, after a hydrant burst) drop the nearest VAC-COP 1.5 m from it: prints its state
##   --from_below      (with --use_prop) stand 200 m straight under the prop (sewer depth): prompt must be empty
##   --cart_bowl       (host) before shoving the cart (--use_prop=cart), put a VAC-COP and a cone in its path
##   --prop_twice      (host, after --use_prop) tidy the prop and bust it again: no second payout
##   --instant_props   each street-pack kind knocked over the way a LATE JOINER sees it (no animation), then tidied
##   --look_prop=KIND  stand 3 m in front of the nearest standing one, looking at it (for screenshots)
##   --twist=NAME      DISTRICT TWIST for every district, the first included (scripts/district_twist.gd):
##                     blackout | bin_day | clearance | high_alert | none. Prints "DevCapture twist" lines
##                     (lamps, sight, props, Meow-Mart loot, bots, CRT intel), and after --kill_roombas how
##                     much SCRAP lies on the street. --twist_heat=F measures the heat rise over F physics
##                     frames (with --deploy). --twist_rolls = what 1000 districts would roll (no --twist needed).
##   --meow[=F]        F frames in (default 30), press MEOW (the taunt). With --bait_roomba=18 a bot out of
##                     sight should hear it and come (INVESTIGATE)
##   --spectate[=S]    (host, with --add_local=1) THE CAT-CAM (scripts/spectator.gd): the couch cat goes up
##                     top, cat S (default 0) walks to the sewer's CAT-CAM TV and presses E (real input),
##                     then prints "DevCapture spectate" lines (camera, who, HUD line). A VAC-COP is parked
##                     10 m from the watched cat. --spectate_ko instead sends BOTH up and knocks cat S out:
##                     it should start watching by itself once it's back in the sewer.
##   --heckle          (with --spectate) press MEOW while watching: "<NAME> (RADIO): ..." over the watched
##                     cat, and the bot should hear it. --spectate_switch presses RIGHT (switch cat).
##   --spectate_car    (with --spectate) the watched cat gets in the car: prints where the camera is.
##   --spectate_exit=F (with --spectate) F frames after that, press E: back to our own cat in the sewer.
##   --raid_report[=N] (host) end the district NOW with made-up numbers: the RAID REPORT goes up
##                     (N = that many cards; made-up quitters fill the gap). --raid_report_after=F waits
##                     F frames first (default 30). Every report prints "DevCapture report" lines
##                     (also real ones, e.g. after --heat=100).
##   --report_ready=A,B  once a report is up, wait --report_ready_delay frames (default 60), then
##                     press READY with REAL input, one by one: S = seat S's own button (E for seat 0
##                     on the keyboard, A on a pad), S:pad / S:key / S:stick (must do nothing),
##                     spare:D = A on unclaimed controller D (must do nothing), S:pause = Esc / START.
##                     Prints who is ready, and whether the report / pause menu are up.
##   --mainframe=N     (host) every gang's MAINFRAME charge is N (or =A,B per gang) and the district restarts on it
##   --mainframe_drain=N (host) THE SLOW DRAIN runs at N% a minute (600 = 10%/s, to watch cells run dry)
##   --mainframe_window[=N] walk to THE MAINFRAME, press E (its window), then FEED N times (--give=electronics first)
##   --rebind=A,S,KEY  (with --menu=settings) set key slot S (0/1) of control A to KEY, as if
##                     the player clicked the box and pressed it, e.g. --rebind=drop,0,Space
##                     (slot 2 = the PAD box: --rebind=jump,2,Pad_B  - use _ for spaces)
##   --pad=NAME,NAME   push controller sticks / triggers / buttons (fake but REAL controller events)
##                     for --hold_frames after --hold_delay, e.g. --pad=Right_Stick_Right or
##                     --pad=Left_Stick_Up,RT (names from Controls.PAD_BUTTONS / PAD_AXES, _ = space)
##   --pad_press=A,B   press + release controller buttons one by one (after --menu), printing
##                     which menu is open and which button is highlighted after each,
##                     e.g. --pad_press=Start,D-Pad_Down,A
##
## TRAILER CAMERA (film with Godot's Movie Maker: put --write-movie shots/clip.avi --fixed-fps 30
## BEFORE the lone "--"; the clip ends when the snap is taken, so --frames sets its length):
##   --no_hud          hide every player's HUD (clean shots)
##   --cam_from=X,Y,Z  a film camera starts here...       --cam_to=X,Y,Z    ...and glides to here
##   --look_from=X,Y,Z it looks at this point...          --look_to=X,Y,Z   ...turning to this one
##                     (no --look_* = it looks at our cat's head)
##   --cam_follow      the --cam_* points are offsets from our cat instead (a tracking shot)
##   --cam_orbit=CX,CY,CZ,RADIUS,HEIGHT,DEG_FROM,DEG_TO   circle round a point instead, looking at it
##   --cam_frames=N    how long the glide takes (default: --frames)   --cam_delay=N  wait first
##   --cam_fov=DEG     zoom (default 60)   --cam_ease=false  glide at an even speed (default eases in/out)
##   --hold_all        (with --join_pad) every player on this PC holds the --hold controls, and
##                     --deploy sends them all up top (split-screen shots)
## The shot list and the editing script live in trailer/ (record.py, edit.py).


## The test modules (scripts/dev_tests/): each is a child node sharing `_args` and the helpers in dev_test.gd.
var _lineups: Node
var _menus: Node
var _fights: Node
var _tutorial: Node
var _mess: Node
var _spectate_report: Node
var _meow_mart: Node
var _moves: Node
var _cars: Node


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	_args = args
	# --test-room-code: check room codes turn back into the right addresses, then quit.
	if args.has("test-room-code") and OS.is_debug_build():
		_test_room_code()
		return
	# Never runs in a release build (the exported .exe players get), only in Godot / debug builds.
	if not args.has("capture") or not OS.is_debug_build():
		queue_free()
		return
	# The test modules (scripts/dev_tests/*.gd): children, so they can await frames and see _args.
	_lineups = _add_module("res://scripts/dev_tests/lineups.gd")
	_menus = _add_module("res://scripts/dev_tests/menus.gd")
	_fights = _add_module("res://scripts/dev_tests/fights.gd")
	_tutorial = _add_module("res://scripts/dev_tests/tutorial.gd")
	_mess = _add_module("res://scripts/dev_tests/mess.gd")
	_spectate_report = _add_module("res://scripts/dev_tests/spectate_report.gd")
	_meow_mart = _add_module("res://scripts/dev_tests/meow_mart.gd")
	_moves = _add_module("res://scripts/dev_tests/moves.gd")
	_cars = _add_module("res://scripts/dev_tests/cars.gd")

	# --window=WxH   open the game window at that size (e.g. 1720x720 = ultrawide shape; never saved)
	if args.has("window"):
		var parts: PackedStringArray = args["window"].split("x")
		Settings.set_value("resolution", Vector2i(int(parts[0]), int(parts[1])))

	# --setting=split_side_by_side:false  (any variable in scripts/settings.gd; test runs never save)
	if args.has("setting"):
		var parts: PackedStringArray = args["setting"].split(":")
		Settings.set_value(parts[0], str_to_var(parts[1]))

	# --teams=1,0,1  the gang each seat plays for (scripts/teams.gd), as if picked on the landing page.
	if args.has("teams"):
		Teams.turf_war_pick = true  # (gangs only exist in TURF WAR)
		var gangs: PackedStringArray = args["teams"].split(",")
		for seat in mini(gangs.size(), Teams.picks.size()):
			Teams.picks[seat] = int(gangs[seat])
	if args.has("mode"):  # (after --teams, so "--teams=0,1 --mode=coop" = gangs picked, then CO-OP)
		Teams.turf_war_pick = args["mode"] == "turf"
	if args.has("twist"):  # --twist=blackout: every district gets that DISTRICT TWIST (district_twist.gd)
		DistrictTwist.forced_kind = DistrictTwist.kind_from_text(args["twist"])
		if DistrictTwist.forced_kind < 0:
			push_warning("DevCapture: unknown --twist=%s" % args["twist"])

	if args.has("saved_cats"):
		var look_rng := RandomNumberGenerator.new()
		for cat_name in args["saved_cats"].split(","):
			Settings.new_cat(false, cat_name, CatLook.random_look(look_rng))

	# Let the main scene finish loading.
	await get_tree().process_frame
	var scene: Node = Game.instance  # the game (main.tscn), inside scenes/game_screen.tscn

	# Wait (up to ~10 s) for OUR cat to exist — a joining game needs time to connect.
	# Without --host / --join no cat ever appears, and we just photograph the lobby.
	var player: CatPlayer = null
	if args.has("host") or args.has("join") or args.has("solo") or args.has("tutorial"):
		var give_up_at := Time.get_ticks_msec() + 10000  # seconds, not frames: fps varies a lot
		while Time.get_ticks_msec() < give_up_at:
			player = scene.get_node_or_null("Players/%d" % multiplayer.get_unique_id()) as CatPlayer
			if player != null:
				break
			await get_tree().process_frame
		if player != null and args.has("add_local"):
			# Split screen test: more players on this computer (scripts/player_id.gd, game.gd).
			var look_rng := RandomNumberGenerator.new()
			look_rng.seed = 7
			for slot in range(1, int(args["add_local"]) + 1):
				scene.add_local_player(slot, {"name": "COUCH %d" % (slot + 1), "look": CatLook.random_look(look_rng), "cat_id": ""})
			for i in 120:  # wait for the host to make their cats
				if scene.local_cats().size() > int(args["add_local"]):
					break
				await get_tree().process_frame
			print("DevCapture add_local: our cats = %s" % [scene.local_cats().map(func(c): return "%s (slot %d)" % [c.name, c.slot])])
			if args.has("as_local"):
				player = scene.cat_for(PlayerId.make(multiplayer.get_unique_id(), int(args["as_local"])))
		if player != null and args.has("join_pad"):
			# Couch co-op: seat a player on fake controller N, as if they'd joined in the lobby.
			# (Players can't drop in mid-game any more: Seats.test_seat_player is for tests only.)
			# (Only in co-op games: a test started with --solo is turned into a local co-op one.)
			Seats.coop = true
			Seats.game_started()
			for i in 20:
				await get_tree().process_frame
			for device in args["join_pad"].split(","):
				Seats.test_seat_player(int(device))
				for i in 3:
					await get_tree().process_frame
			for i in 60:  # wait for the host to make their cats
				if scene.local_cats().size() > args["join_pad"].split(",").size():
					break
				await get_tree().process_frame
			print("DevCapture join_pad: seats pads=%s taken=%s paused=%s cats=%s" % [Seats.pads, Seats.taken, PauseMenu.is_open,
				scene.local_cats().map(func(c): return "%s slot %d \"%s\" reads_input=%s" % [c.name, c.slot, c.player_name, c.reads_input()])])
			if args.has("as_local"):
				player = scene.cat_for(PlayerId.make(multiplayer.get_unique_id(), int(args["as_local"])))
		if player != null and args.has("spare_start"):
			# --spare_start=D: a REAL START press on spare controller D during a co-op game.
			# (No drop-in: nothing should happen unless someone's controller is unplugged.)
			Seats.coop = true
			Seats.game_started()
			for i in 20:
				await get_tree().process_frame
			var before: int = scene.local_cats().size()
			for pressed in [true, false]:
				var start := _pad_event("Start", pressed)
				start.device = int(args["spare_start"])
				Input.parse_input_event(start)
				for i in 3:
					await get_tree().process_frame
			for i in 60:
				await get_tree().process_frame
			print("DevCapture spare_start: cats before=%d after=%d pads=%s taken=%s paused=%s" % [before,
				scene.local_cats().size(), Seats.pads, Seats.taken, PauseMenu.is_open])

	# Diagnostics: switch PS1 effects off on the city's materials for this run only.
	#   --no_affine        perspective-correct textures
	#   --no_snap          no vertex wobble (snaps to a very fine grid)
	var city_node := scene.get_node_or_null("City") as CityGenerator
	if city_node != null:
		for material in [city_node.building_material, city_node.street_material, city_node.sidewalk_material]:
			var shader_material := material as ShaderMaterial
			if args.has("no_affine"):
				shader_material.set_shader_parameter("affine_mapping", false)
			if args.has("no_snap"):
				shader_material.set_shader_parameter("snap_resolution", Vector2(100000, 100000))

	if player != null:
		for i in int(args.get("wait", 0)):
			await get_tree().process_frame
		await _lineups._apply_look(args)  # dressed before anything else happens (trailer clips film it all)
		if args.has("tutorial_auto"):
			await _tutorial._tutorial_auto(player)
			return
		if args.has("twist") or args.has("twist_rolls"):
			_print_twist(scene, args)
		Events.player_extracted.connect(func(id: int, loot: int, bonus: int) -> void:
			print("DevCapture extracted: player %d loot $%d bonus $%d (twist %s) cash now $%d" % [id, loot, bonus,
				DistrictTwist.name_of(DistrictTwist.current_kind()), Wallet.instance.cash_of(id)]))
		if args.has("net_interval"):
			# Simulate a bad connection: only send our cat's position every N seconds.
			(player.get_node("MultiplayerSynchronizer") as MultiplayerSynchronizer).replication_interval = float(args["net_interval"])
		if args.has("rebellion_tier"):
			Upgrades.rebellion_override = int(args["rebellion_tier"])  # (test only: scripts/upgrades.gd)
		if args.has("cash") and multiplayer.is_server():
			Wallet.instance.set_cash(player.player_id, int(args["cash"]))
			multiplayer.peer_connected.connect(func(peer_id: int) -> void:
				await get_tree().create_timer(0.2).timeout  # after the joiner has the cash list
				Wallet.instance.set_cash(peer_id, int(args["cash"])))
		if args.has("grab_mouse"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # (--hold=shoot only fires with the mouse in the game)
		if args.has("breach_seconds"):
			Mainframe.instance.breach_seconds = float(args["breach_seconds"])
		if args.has("breach_warning"):
			Mainframe.instance.breach_warning_seconds = float(args["breach_warning"])
		if args.has("breach_log"):
			_fights._breach_log(int(args["breach_log"]))
		if args.has("breach_wipe"):
			_fights._breach_wipe(int(args["breach_wipe"]))
		if args.has("breach_knock"):
			_fights._breach_knock(int(args["breach_knock"]))
		# THE RAID REPORT (scripts/raid_report.gd): every report that goes up is printed here.
		Events.raid_report_shown.connect(_spectate_report._print_report)
		if args.has("raid_report") and multiplayer.is_server():
			_spectate_report._force_report(int(args["raid_report"]) if args["raid_report"] != "true" else 0, int(args.get("raid_report_after", 30)))
		if args.has("report_ready"):
			_spectate_report._report_ready(args["report_ready"].split(","), int(args.get("report_ready_delay", 60)))
		if args.has("mainframe") and multiplayer.is_server():
			# (host) --mainframe=N or =A,B: the gangs' charges are N (0/25/50/75/100; A = Catleone,
			# B = Burrow), and this district starts over on them (heat, overclock, 0% boss).
			var test_charges: PackedStringArray = args["mainframe"].split(",")
			for team in Mainframe.instance.charges.size():
				Mainframe.instance.charges[team] = float(test_charges[mini(team, test_charges.size() - 1)])
			Mainframe.instance.start_district()
			HeatMeter.instance.start_district()
			RoombaPatrol.instance.start_district()
			print("DevCapture mainframe: %s active=%s exits at %s heat=%.0f overclock=%s heat speed x%.1f boss at start=%s" % [Mainframe.instance.charges, Mainframe.instance.active_gangs(), [Mainframe.instance.exit_heat(0), Mainframe.instance.exit_heat(1)], HeatMeter.instance.heat, Mainframe.instance.overclock_active, Mainframe.instance.heat_multiplier(), Mainframe.instance.boss_at_start()])
		if args.has("mainframe_drain") and multiplayer.is_server():
			# (host) --mainframe_drain=N: THE SLOW DRAIN is N% a minute (try 600 = 10% a second).
			Mainframe.instance.drain_per_minute = float(args["mainframe_drain"])
		if args.has("quest"):
			QuestManager.instance.start_quest(player.player_id, args["quest"])
			if args.has("abandon_quest"):
				# --abandon_quest: press the inventory's ABANDON button twice (it asks "SURE?" first).
				for i in 10:
					await get_tree().physics_frame
				var screen := InventoryScreen.for_seat(0)
				screen._set_open(true)
				screen._use_abandon(false)
				await get_tree().physics_frame
				print("DevCapture abandon 1st press: quest='%s' info=\"%s\"" % [QuestManager.instance.current_quest(player.player_id), screen._info.text])
				screen._use_abandon(false)
				for i in 10:
					await get_tree().physics_frame
				print("DevCapture abandon 2nd press: quest='%s' info=\"%s\"" % [QuestManager.instance.current_quest(player.player_id), screen._info.text])
		if args.has("heat") and multiplayer.is_server():
			# (host) force the heat, e.g. --heat=100 brings out the MEGA VAC-COP.
			var hold := int(args.get("heat_hold", args.get("frames", 90)))
			var heat_meter := HeatMeter.instance
			var force_heat := func() -> void:
				for i in hold:
					heat_meter.heat = float(args["heat"])
					await get_tree().physics_frame
			force_heat.call()
		if args.has("give") and multiplayer.is_server():
			# (host) put items straight into our paws/backpack, e.g. --give=pistol,catnip
			for item_id in args["give"].split(","):
				ItemManager.instance._put_in_inventory(player.player_id, item_id, player.global_position)
		elif args.has("give"):
			# (client) ask the host's test tool to do it (only works if the host runs one too)
			_test_give.rpc_id(1, player.player_id, args["give"])
			for i in 20:
				await get_tree().process_frame
		if args.has("hud_heat") or args.has("hud_buffs"):
			_lineups._hud_preview(player, args)
		if args.has("to_stash") or args.has("from_stash"):
			# Walk to THE STASH lockers, then click slots the way the inventory screen does:
			#   --to_stash=hand:0,pack:0   (each moves that item into the stash; indexes shift as you go)
			#   --from_stash=0             (stash slot 0 into the backpack)
			var hub := UndergroundHub.of(player)
			player.teleport_to(hub.to_global(hub.stash_spot), 0.0)
			for i in 20:
				await get_tree().process_frame  # let the host see our new position first
			if args.has("to_stash"):
				for slot in args["to_stash"].split(","):
					var parts: PackedStringArray = slot.split(":")
					ItemManager.instance.request_to_stash.rpc_id(1, player.player_id, parts[0], int(parts[1]))
					for i in 10:
						await get_tree().process_frame
			if args.has("from_stash"):
				ItemManager.instance.request_from_stash.rpc_id(1, player.player_id, int(args["from_stash"]))
				for i in 10:
					await get_tree().process_frame
		# SEWER UPGRADES (scripts/upgrades.gd): print what this cat has, then buy / pick a ride.
		#   --buy_upgrade=bigger_pack,bigger_pack,thick_fur   (one buy each, like clicking the button)
		#   --select_vehicle=cyber_bike   (our gang's ride; needs the unlock)
		#   --workbench                   (walk to the TINKER WORKBENCH and press E: its screen opens)
		#     --workbench_tab=N           (then pick tab N: 0 boss, 1 shopkeeper, 2-6 rebellion tiers 1-5)
		#     --workbench_recruit=N       (then press RECRUIT N times: the lowest-numbered missing recruits)
		#     --workbench_pick=4,6        (then recruit the cats on these tabs, in this order)
		#     --workbench_buy=a,b         (then click those upgrades' cards)
		#   --rebellion_tier=N            (every sewer counts as having recruited N tiers: test only)
		#   --vehicles_lineup             (TURF WAR host: both gangs' cars parked in front of us, as a bike + a van)
		if args.has("buy_upgrade") or args.has("select_vehicle") or args.has("upgrade_log"):
			await _menus._upgrades_test(player, args)
		#   --reveal_test=N [--reveal_wait=F]  (our gang "recruits" cat N right away: the NEW RECRUIT camera shot
		#                                       plays; prints "DevCapture reveal" lines, snaps F frames in, default 60)
		if args.has("reveal_test"):
			await _menus._reveal_test(player, args)
		#   --hub_pos=X,Y,Z [--hub_yaw=DEG]  (stand at that spot INSIDE our sewer hub (hub-local metres), camera turned DEG)
		if args.has("hub_pos"):
			var hub := UndergroundHub.of(player)
			var p: PackedStringArray = str(args["hub_pos"]).split(",")
			player.teleport_to(hub.to_global(Vector3(float(p[0]), float(p[1]), float(p[2]))), 0.0)
			player.camera_pivot.rotation.y = deg_to_rad(float(args.get("hub_yaw", "0")))
			for i in 20:
				await get_tree().physics_frame
		if args.has("workbench"):
			var hub := UndergroundHub.of(player)
			player.teleport_to(hub.to_global(hub.workbench_spot + Vector3(-1.6, 0, 0)), 0.0)
			player.camera_pivot.rotation.y = -PI / 2  # face east, at the bench
			for i in 20:
				await get_tree().physics_frame
			print("DevCapture workbench: prompt=\"%s\" used=%s" % [Interactable.prompt_for(player), Interactable.try_use(player)])
			for i in 5:
				await get_tree().process_frame
			await _menus._workbench_test(player, args)
		#   --mainframe_window[=N]        (walk to THE MAINFRAME, press E: its window opens; then press FEED N times.
		#                                  Give electronics first: --give=electronics,electronics)
		if args.has("mainframe_window"):
			var hub := UndergroundHub.of(player)
			player.teleport_to(hub.to_global(hub.mainframe_spot + Vector3(0.8, 0, 0)), 0.0)
			player.camera_pivot.rotation.y = PI / 2  # face west, at the Mainframe
			for i in 20:
				await get_tree().physics_frame
			print("DevCapture mainframe_window: prompt=\"%s\" used=%s" % [Interactable.prompt_for(player), Interactable.try_use(player)])
			await _menus._mainframe_window_test(player, args)
		if args.has("vehicles_lineup"):
			await _lineups._vehicles_lineup(player)
		if args.has("weapons_lineup"):
			await _lineups._weapons_lineup(player)
		if args.has("cat_lineup") or args.has("coat_lineup"):
			await _lineups._cat_lineup(player)
		if args.has("deploy"):
			# Before --pos, so --pos can still pick an exact spot in the city.
			UndergroundHub.of(player).deploy(player)
			if args.has("hold_all"):  # split-screen trailer shots: the couch players go up too
				for cat in scene.local_cats():
					if cat != player:
						UndergroundHub.of(cat).deploy(cat)
			for i in 20:
				await get_tree().process_frame  # let the host see our new position first
		if args.has("heat_ramp") and multiplayer.is_server():
			# --heat_ramp=S (host): raise the heat steadily to 100 over S seconds, so one run sees every
			# heat level, the MEGA VAC-COPs and the seal (OVERCLEAN announces each: --sound_log).
			var ramp_seconds := maxf(1.0, float(args["heat_ramp"]))
			var ramp := func() -> void:
				var heat_meter := HeatMeter.instance
				var start := heat_meter.heat
				var t := 0.0
				while t < ramp_seconds:
					await get_tree().physics_frame
					t += get_physics_process_delta_time()
					heat_meter.heat = maxf(heat_meter.heat, lerpf(start, HeatMeter.MAX_HEAT, t / ramp_seconds))
			ramp.call()
		if args.has("pos"):
			var p: PackedFloat64Array = args["pos"].split_floats(",")
			player.global_position = Vector3(p[0], p[1], p[2])
		if args.has("near_exit"):
			# --near_exit=D: stand D metres south of the EXIT manhole, facing it (then
			# --hold=move_forward walks onto it; it only lets you down with --heat=80 or more).
			var exit_at := FishHeist.instance.exit_for(int(args.get("exit_team", player.team)))  # (our gang's, or --exit_team's)
			player.global_position = exit_at + Vector3(0, 0.5, float(args["near_exit"]))
			player.camera_pivot.rotation.y = 0.0
			print("DevCapture near_exit: exit manhole at %s" % exit_at)
		if args.has("near_speaker"):
			_near_speaker(player, args)
		if args.has("goop"):
			# --goop=D: a sticky puddle D metres ahead of the camera, on the ground (to judge how it looks).
			for i in 10:
				await get_tree().physics_frame
			var ahead := -player.camera_pivot.global_basis.z
			ahead.y = 0.0
			var spot := player.global_position + ahead.normalized() * float(args["goop"])
			spot.y = 0.0
			StickyPatch.make(scene, spot, 1.6, 999.0)
			print("DevCapture goop: puddle at %s" % spot)
		if args.has("test_meow_mart") or args.has("inside_meow_mart") or args.has("shatter_tank") or args.has("mart_log") \
				or args.has("mart_swat") or args.has("mart_topple") or args.has("mart_plate") or args.has("mart_drag") or args.has("mart_tank_hits"):
			await _meow_mart._meow_mart_test(player, args)
		if args.has("yaw"):
			player.camera_pivot.rotation.y = deg_to_rad(float(args["yaw"]))
		if args.has("pitch"):
			player.spring_arm.rotation.x = deg_to_rad(float(args["pitch"]))
		if args.has("no_hud"):
			for seat in 4:
				var hud := Hud.of(seat)
				if hud != null:
					hud.visible = false
		if args.has("car_light"):
			# --car_light[=E]: a test-only "showroom" lamp over every car, to judge the model at night.
			for car in Game.instance.cars():
				var lamp := OmniLight3D.new()
				lamp.light_energy = float(args["car_light"]) if args["car_light"] != "" else 3.0
				lamp.omni_range = 9.0
				car.add_child(lamp)
				lamp.position = Vector3(1.5, 3.0, 1.0)
		if args.has("cam_from") or args.has("cam_orbit"):
			_lineups._film_camera(player, args)  # runs alongside everything below (not awaited)
		if args.has("mouse_test"):
			# Move the mouse 100 real screen pixels to the right (as if the player did) and print
			# how far that is in game pixels (should be 100 x 240 / window height).
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			var yaw_before := player.camera_pivot.rotation.y
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(100, 0)  # real screen pixels, like a real mouse
			motion.position = Vector2(get_window().size) / 2.0
			Input.parse_input_event(motion)
			for i in 3:
				await get_tree().process_frame
			var moved := (yaw_before - player.camera_pivot.rotation.y) / (player.mouse_sensitivity * Settings.mouse_speed)
			print("DevCapture mouse: 100 screen px = %.2f game px (expected %.2f)" % [moved, 100.0 * 240.0 / get_window().size.y])
		if args.has("talk"):
			await _menus._talk(player, args)
		if args.has("announce"):
			await _announce(args)
		if args.has("portrait"):
			_lineups._portrait(player, args)
		if args.has("drive"):
			for i in 20:
				await get_tree().process_frame  # let the host see our new position first
			# Walk up to our gang's car first (each gang's car parks in its own corner).
			var my_car := _car_for(player)
			if my_car.global_position.distance_to(player.global_position) > 4.0:
				player.teleport_to(my_car.global_position + my_car.global_basis.x * -2.5, 0.0)
				for i in 20:
					await get_tree().process_frame
			my_car.request_enter.rpc_id(1, player.player_id)
			if args.has("ride_along"):
				# Split screen: these couch slots walk up to the car and press E too (passenger seats).
				var car := _car_for(player)
				for i in 20:
					await get_tree().process_frame  # the driver gets in first
				for ride_slot in args["ride_along"].split(","):
					var rider: CatPlayer = scene.cat_for(PlayerId.make(multiplayer.get_unique_id(), int(ride_slot)))
					if rider == null:
						continue
					rider.teleport_to(car.global_position + Vector3(2.5, 0.5, 0), 0.0)
					for i in 10:
						await get_tree().physics_frame
					car.interact(rider)
					for i in 10:
						await get_tree().process_frame
				print("DevCapture ride_along: driver=%d passengers=%s" % [car.driver_id, car.passenger_ids])
				if args.has("ride_exit"):
					# --ride_exit=S: that passenger hops out again.
					car.request_exit.rpc_id(1, PlayerId.make(multiplayer.get_unique_id(), int(args["ride_exit"])))
					for i in 20:
						await get_tree().process_frame
					print("DevCapture ride_exit: driver=%d passengers=%s" % [car.driver_id, car.passenger_ids])
			if args.has("car_mouse"):
				for i in 20:
					await get_tree().process_frame  # wait until we're behind the wheel
				var car := _car_for(player)
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				var motion := InputEventMouseMotion.new()
				motion.relative = Vector2(float(args["car_mouse"]), 0)
				motion.position = Vector2(get_window().size) / 2.0
				Input.parse_input_event(motion)
				for i in 3:
					await get_tree().process_frame
				print("DevCapture car_mouse: driver=%d look_yaw=%.2f look_pitch=%.2f" % [car.driver_id, car.look_yaw, car.look_pitch])
		if args.has("car_watch"):
			_watch_car_camera(_car_for(player), int(args["car_watch"]))
		if args.has("grab"):
			# For each item named: stand next to the nearest one and press E (send what E sends).
			var items := ItemManager.instance
			for item_id in args["grab"].split(","):
				var best := -1
				for id in items.world:
					if items.world[id].item == item_id and (best < 0 or player.global_position.distance_to(items.world[id].pos) < player.global_position.distance_to(items.world[best].pos)):
						best = id
				if best < 0:
					print("DevCapture: no '%s' lying anywhere" % item_id)
					continue
				player.global_position = items.world[best].pos + Vector3(0.5, 0, 0.5)
				for i in 20:
					await get_tree().process_frame  # let the host see our new position first
				Interactable.try_use(player)  # (what E does: the item is the best thing in reach)
				for i in 10:
					await get_tree().process_frame
		if args.has("equip"):
			# Click backpack slot N in the inventory screen (take it into the paws).
			ItemManager.instance.request_equip.rpc_id(1, player.player_id, int(args["equip"]))
			for i in 10:
				await get_tree().process_frame
		if args.has("put_away"):
			# Click paw N in the inventory screen (0 = right, 1 = left): put it in the backpack.
			ItemManager.instance.request_put_away.rpc_id(1, player.player_id, int(args["put_away"]))
			for i in 10:
				await get_tree().process_frame
		if args.has("drop_slot"):
			# Right-click a slot in the inventory screen, e.g. --drop_slot=pack:0 or bag:0 or hand:1
			var parts: PackedStringArray = args["drop_slot"].split(":")
			ItemManager.instance.request_drop_item.rpc_id(1, player.player_id, parts[0], int(parts[1]), ItemManager.instance.ground_in_front_of(player))
			for i in 10:
				await get_tree().process_frame
		if args.has("bait_roomba"):
			# --bait_roomba=4: 4 m in front of the cat.  --bait_roomba=aim: right under the crosshair
			# (where the camera's centre line meets the ground), stunned so it stays put a moment.
			for i in 20:
				await get_tree().process_frame  # let the camera settle (over-the-shoulder slide)
			var roomba: Roomba = await _pick_roomba(scene, player.global_position, args)
			if args.has("no_boss_sign") and roomba.has_node("BossSign"):
				roomba.get_node("BossSign").visible = false  # --no_boss_sign: no "MEGA VAC-COP" over it (thumbnails)
			if not multiplayer.is_server():
				# A client can't move the host's Roombas, so walk our cat up to one instead.
				player.teleport_to(roomba.global_position + Vector3(float(args["bait_roomba"]), 0, 0), 0.0)
			elif args["bait_roomba"] == "aim":
				var camera := player.camera
				var aim := -camera.global_basis.z
				var t := (camera.global_position.y - 0.15) / maxf(-aim.y, 0.01)
				roomba.global_position = camera.global_position + aim * t - Vector3(0, 0.05, 0)
				roomba.state = Roomba.State.STUNNED
				roomba._stun_left = 3.0
			else:
				var ahead := -player.camera_pivot.global_basis.z
				roomba.global_position = player.global_position + Vector3(ahead.x, 0, ahead.z).normalized() * float(args["bait_roomba"]) + Vector3(0, 0.1, 0)
			print("DevCapture bait: %s placed at %s" % [roomba.name, roomba.global_position.snapped(Vector3.ONE * 0.1)])
		if args.has("zap_roomba"):
			var roomba: Roomba = await _pick_roomba(scene, player.global_position, args)
			for i in int(args["zap_roomba"]):
				# Through the hit framework (hit.gd), like a real bolt: works on a client too.
				var hit := Hit.new()
				hit.shooter = player
				hit.damage = 34
				roomba.receive_hit(hit)
		if args.has("eye_test"):
			# --eye_test: two real physics rays at the picked bot (add --roomba=boss/drone/trapper):
			# one straight into its glowing Eye from 2.5 m in front, one into its side. Both go through
			# the hit framework with damage 40 and NO rolled crit (like a gun with Crit Chance 0), so
			# only the EYE WEAK SPOT can make one a crit. Prints a "DevCapture eye_test" line each.
			var roomba: Roomba = await _pick_roomba(scene, player.global_position, args)
			await get_tree().physics_frame
			var centre := roomba.eye_centre()
			var looking := -roomba.model.global_basis.z.normalized()
			var shots := {
				"eye": [centre + looking * 2.5, centre],
				"body": [roomba.global_position + roomba.model.global_basis.x.normalized() * 4.0 + Vector3.UP * 0.12 * roomba.model.scale.x,
					roomba.global_position + Vector3.UP * 0.12 * roomba.model.scale.x],
			}
			for kind in shots:
				var from: Vector3 = shots[kind][0]
				var to: Vector3 = shots[kind][1]
				var query := PhysicsRayQueryParameters3D.create(from, from + (to - from).normalized() * 8.0)
				query.exclude = [player.get_rid()]
				var ray := player.get_world_3d().direct_space_state.intersect_ray(query)
				var target := Hit.target_of(ray.get("collider")) if not ray.is_empty() else null
				if target != roomba:
					print("DevCapture eye_test %s: MISSED (hit %s)" % [kind, ray.get("collider")])
					continue
				var hit := Hit.new()
				hit.shooter = player
				hit.damage = 40
				hit.crit = false
				hit.direction = (to - from).normalized()
				hit.position = ray["position"]
				roomba.receive_hit(hit)
				print("DevCapture eye_test %s: bot=%s crit=%s damage=%d at=%s eye_flash=%s" % [kind, roomba.display_name,
					hit.crit, hit.damage, hit.position.snapped(Vector3.ONE * 0.01), roomba.eye_flashing()])
		if args.has("stun_roomba") and multiplayer.is_server():
			# --stun_roomba=S: (host) stun the picked enemy for S seconds, like a YARN-ZOOKA hit.
			var roomba: Roomba = await _pick_roomba(scene, player.global_position, args)
			roomba._on_stunned(float(args["stun_roomba"]))
		if args.has("kill_roombas") and multiplayer.is_server():
			# (host) destroy N regular Roombas as if shot to death (every 3 calls in the MEGA VAC-COP).
			for i in int(args["kill_roombas"]):
				for node in scene.get_node("Roombas").get_children():
					var victim := node as Roomba  # (any patrol unit: drones and Lint-Trappers count too)
					if victim != null and (not victim.is_boss or args.has("kill_bosses")) and not victim.is_queued_for_deletion():
						victim.take_hit.rpc_id(1, player.player_id, 500)  # (credited to us, like a real shot)
						break
				await get_tree().physics_frame
			if args.has("kill_bosses"):
				for i in 5:
					await get_tree().physics_frame
				print("DevCapture kill_bosses: ELECTRONICS on the street=%d SCRAP=%d" % [_count_world_items(Mainframe.FUEL_ID), _count_world_items("scrap")])
			if args.has("twist"):
				for i in 5:
					await get_tree().physics_frame
				print("DevCapture twist scrap: %d regular kills -> %d SCRAP on the street (twist %s)" % [int(args["kill_roombas"]),
					_count_world_items("scrap"), DistrictTwist.name_of(DistrictTwist.current_kind()) if DistrictTwist.current_kind() != 0 else "NONE"])
		if args.has("mess") or args.has("ram_prop") or args.has("scratch") or args.has("shoot_prop") or args.has("meow") or args.has("mess_log") or args.has("ghost") or args.has("use_prop") or args.has("look_prop") or args.has("instant_props"):
			await _mess._mess_tests(scene, player, args)
		if args.has("spectate") or args.has("spectate_ko"):
			await _spectate_report._spectate_tests(scene, args)
		if (args.has("down") and multiplayer.is_server()) or (args.has("revive") and not multiplayer.is_server()):
			await _fights._down_and_revive(scene, player, args)
		if args.has("shoot_rival"):
			await _fights._shoot_rival(scene, player, args)
		if args.has("blast_car"):
			await _fights._blast_car(scene, player)
		if args.has("blast_probe"):
			_fights._blast_probe(player)
		if args.has("feedback_test"):
			await _fights._feedback_test(player)
		if args.has("car_test"):
			await _cars._car_test(scene, player)
		if args.has("car_juice"):
			await _cars._car_juice_test(player)
		if args.has("car_chase"):
			await _cars._car_chase(scene, player)
		if args.has("gunner_test"):
			await _cars._gunner_test(scene, player)
		if args.has("swing_test"):
			await _fights._swing_test(player, args)
		if args.has("combo_test"):
			await _fights._combo_test(player, args)
		if args.has("melee_test"):
			await _fights._melee_test(player, args)
		if args.has("spin_test"):
			await _fights._spin_test(player, args)
		if args.has("moves_test"):
			await _moves._moves_test(player, args)
		if args.has("deploy_again"):
			# --deploy_again=N: N frames later ask Don to send us up AGAIN (one trip per district:
			# he should refuse once we've been up). Prints where we ended up.
			for i in int(args["deploy_again"]):
				await get_tree().physics_frame
			UndergroundHub.of(player).deploy(player)
			for i in 10:
				await get_tree().physics_frame
			print("DevCapture deploy_again: went_up=%s in_hub=%s heat=%.1f" % [FishHeist.instance.has_been_up(player.player_id),
				UndergroundHub.is_in_hub(player.global_position), HeatMeter.instance.heat])
		if args.has("hold"):
			# Pretend a key is held down, e.g. --hold=move_forward --hold_frames=60
			for i in int(args.get("hold_delay", "30")):
				await get_tree().process_frame
			# Several at once with a comma list, e.g. --hold=shoot,use_left (fire both pistols).
			# --hold_all = every player on this computer holds them (split-screen trailer shots).
			var slots: Array = [player.slot]
			if args.has("hold_all"):
				slots = scene.local_cats().map(func(c): return c.slot)
			for action in args["hold"].split(","):
				for slot in slots:
					Input.action_press(Seats.action(slot, action))  # the test player's own controls
			for i in int(args.get("hold_frames", "60")):
				await get_tree().process_frame
			if not args.has("keep_holding"):  # --keep_holding = still held when the snap is taken
				for action in args["hold"].split(","):
					for slot in slots:
						Input.action_release(Seats.action(slot, action))
		if args.has("pad"):
			# Push the controller like a player would, e.g. --pad=Right_Stick_Right --hold_frames=30
			for i in int(args.get("hold_delay", "30")):
				await get_tree().process_frame
			var yaw_before := player.camera_pivot.rotation.y
			var pos_before := player.global_position
			var all_before := {}
			for cat in scene.local_cats():
				all_before[cat] = cat.global_position
			var pads: PackedStringArray = args["pad"].replace("_", " ").split(",")
			if player.slot == 0:
				Seats.claim_for_p1(int(args.get("pad_device", "0")))  # (as if used in the start menu)
			for pad in pads:
				Input.parse_input_event(_pad_event(pad, true))
			for i in int(args.get("hold_frames", "60")):
				await get_tree().process_frame
			var car := _car_for(player)
			var held: Array = []
			for entry in Controls.ACTIONS:
				if Input.is_action_pressed(entry.action):
					held.append(entry.action)
			print("DevCapture pad held: %s" % [held])
			for cat in all_before:
				print("DevCapture pad moved: %s (slot %d) %.2f m" % [cat.name, cat.slot, cat.global_position.distance_to(all_before[cat])])
			print("DevCapture pad %s: using_pad=%s yaw turned %.2f rad, cat moved %.2f m, car throttle %.2f steer %.2f, speed %.1f, prompt key=%s" % [
				args["pad"], Controls.using_pad, player.camera_pivot.rotation.y - yaw_before,
				player.global_position.distance_to(pos_before), car.throttle, car.steer,
				car.linear_velocity.length(), Controls.key_text("interact")])
			if not args.has("keep_holding"):
				for pad in pads:
					Input.parse_input_event(_pad_event(pad, false))
		if args.has("drop_after"):
			# Wait, then drop what's in the paws (what G does).
			for i in int(args["drop_after"]):
				await get_tree().process_frame
			ItemManager.instance.drop_from(player)
		if args.has("jump_test"):
			# Jump, press jump again in mid-air, and report the highest point reached.
			# (Catdip in a QUICK USE slot from --give=catdip? Use it first, like pressing its key.)
			var quick := ItemManager.instance.quick_slots(player.player_id)
			for slot in 2:
				if player.air_jumps == 0 and not quick[slot].is_empty() and quick[slot][0] == "catdip":
					ItemManager.instance.request_quick_use.rpc_id(1, player.player_id, slot)
					for f in 20:
						await get_tree().physics_frame
			var ground_y := player.global_position.y
			var peak := ground_y
			var spin := 0.0  # how far the model turned nose-first (the double jump FRONT FLIP)
			for i in 100:
				if i == 0 or i == 18:
					Input.action_press(Seats.action(player.slot, "jump"))
				elif i == 2 or i == 20:
					Input.action_release(Seats.action(player.slot, "jump"))
				await get_tree().physics_frame
				peak = maxf(peak, player.global_position.y)
				spin = minf(spin, player.cat_model.rotation.x)
				if args.has("flip_snap") and i == int(args.get("flip_frame", "26")):
					# --flip_snap=shots/x.png [--flip_frame=N]: a picture mid-flip
					await RenderingServer.frame_post_draw
					get_tree().root.get_texture().get_image().save_png("res://" + args["flip_snap"])
			print("DevCapture jump: peak height %.2f m (air jumps active: %d) flip %d degrees" % [peak - ground_y, player.air_jumps, roundi(rad_to_deg(-spin))])
		if args.has("exit_after"):
			for i in int(args["exit_after"]):
				await get_tree().process_frame
			(_car_for(player)).request_exit.rpc_id(1, player.player_id)
		if args.has("goto_dropoff_after"):
			# Wait, then jump our cat into the fish drop-off.
			for i in int(args["goto_dropoff_after"]):
				await get_tree().process_frame
			var beam := FishHeist.instance.exit_for(int(args.get("exit_team", player.team))) + Vector3(0.5, 0, 0.5)  # (needs --heat=80: open)
			var car := _car_for(player)
			if car.has_occupant(player.player_id):
				car.global_position = beam + Vector3(0, 0.5, 0)  # driving: take the car there
			else:
				player.global_position = beam
		if args.has("talk_again_after"):
			# After extracting: walk back up to the same NPC and press E again.
			for i in int(args["talk_again_after"]):
				await get_tree().process_frame
			args.erase("choose")
			await _menus._talk(player, args)

	if player == null:
		await _lineups._apply_look(args)  # (no game: e.g. the start menu's cat preview)
	if args.has("inventory"):
		# --inventory = player 1's (same as pressing Tab); --inventory=0,1 = those split-screen seats'.
		var seats: Array = [0] if args["inventory"] == "true" else Array(args["inventory"].split(",")).map(func(v): return int(v))
		for seat in seats:
			var screen := InventoryScreen.for_seat(seat)
			var seat_cat := Game.instance.cat_for(PlayerId.make(multiplayer.get_unique_id(), seat)) if Game.instance != null else null
			if screen != null:
				screen._set_open(true, seat_cat)
		_menus._inventory_report.call_deferred(seats, int(args.get("frames", "90")))
	if args.has("press_key"):
		# --press_key=Tab: a REAL key press + release (goes through the game screen like a player's).
		for i in 10:
			await get_tree().physics_frame  # after --pos, let areas notice the cat (the car's DoorZone)
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.physical_keycode = OS.find_keycode_from_string(args["press_key"])
			key.keycode = key.physical_keycode
			key.pressed = pressed
			Input.parse_input_event(key)
			await get_tree().process_frame
		for i in 20:
			await get_tree().physics_frame  # (a quick-use key asks the host first)
		print("DevCapture press_key %s: inventory open=%s talk box open=%s paused=%s quick=%s speed_boost=%.1f air_jumps=%d" % [args["press_key"], InventoryScreen.for_seat(0).visible, NpcDialog.is_open_for(0), PauseMenu.is_open, ItemManager.instance.quick_slots(player.player_id), player.speed_boost, player.air_jumps])
	# --menu=play / settings / pause   open that menu before the snap
	# --settings_tab=N                  which settings tab to show (0 = DISPLAY)
	if args.has("menu") and scene is Game:
		match args["menu"]:
			"play": scene.main_menu.show_play_screen()
			"mode": scene.main_menu.show_mode_screen()
			"coop": scene.main_menu.show_coop_screen()
			"local": scene.main_menu.show_landing(false)
			"online": scene.main_menu.show_landing(true)
			"settings": scene.settings_menu.open()
			"pause": scene.pause_menu.open()
			"cat": scene.cat_creator.open(scene.pause_menu.enabled)
			"keyboard":
				# The address keyboard, tested with a REAL Ctrl+V and with the PASTE CODE button.
				scene.main_menu.show_play_screen()
				DisplayServer.clipboard_set(" meow-499a-21b0 ")
				scene.main_menu._on_paste_pressed()
				print("DevCapture paste button: '%s' -> %s" % [scene.main_menu.address_input.text, Net.code_to_ip(scene.main_menu.address_input.text)])
				scene.main_menu.address_input.text = ""
				DisplayServer.clipboard_set(" meow-499a-21b0! ")  # (the keyboard drops the !)
				scene.main_menu._address_keyboard.open()
				await get_tree().process_frame
				for pressed in [true, false]:
					var key := InputEventKey.new()
					key.keycode = KEY_V
					key.physical_keycode = KEY_V
					key.ctrl_pressed = true
					key.pressed = pressed
					Input.parse_input_event(key)
					await get_tree().process_frame
				print("DevCapture keyboard Ctrl+V: '%s'" % scene.main_menu.address_input.text)
		if args.has("settings_tab"):
			scene.settings_menu._show_tab(int(args["settings_tab"]))
		# --rebind=ACTION,SLOT,KEY   click a box on the KEYS tab and press KEY (e.g. jump,1,J)
		if args.has("rebind"):
			var parts: PackedStringArray = args["rebind"].split(",")
			scene.settings_menu._start_listening(parts[0], int(parts[1]))
			await get_tree().process_frame
			if parts[2].begins_with("Pad_"):
				Input.parse_input_event(_pad_event(parts[2].trim_prefix("Pad_").replace("_", " "), true))
			else:
				var press := InputEventKey.new()
				press.physical_keycode = OS.find_keycode_from_string(parts[2])
				press.keycode = press.physical_keycode
				press.pressed = true
				Input.parse_input_event(press)
			await get_tree().process_frame
			print("DevCapture rebind %s -> %s | hint: %s" % [parts[0], Controls.bindings[parts[0]], scene.settings_menu.hint_label.text])
			for entry in Controls.ACTIONS:
				print("DevCapture key %s = %s" % [entry.action, Controls.bindings[entry.action]])

	if args.has("unplug"):
		Seats._on_joy_connection_changed(int(args["unplug"]), false)
		for i in 5:
			await get_tree().process_frame
		print("DevCapture unplug %s: own_pause=%s big_pause=%s unplugged=%s" % [args["unplug"],
			range(PlayerId.MAX_LOCAL).map(func(s): return PlayerPause.is_open_for(s)), PauseMenu.is_open, Seats._unplugged])
	if args.has("pad_press"):
		# --pad_press=Start,D-Pad_Down,A : real controller presses, one every few frames.
		# "1:Start" = START on fake controller 1 (otherwise --pad_device, default 0).
		for i in int(args.get("pad_press_delay", "0")):  # --pad_press_delay=N: wait N frames first
			await get_tree().process_frame
		for pad in args["pad_press"].replace("_", " ").split(","):
			for pressed in [true, false]:
				var event := _pad_event(pad.get_slice(":", 1) if ":" in pad else pad, pressed)
				if ":" in pad:
					event.device = int(pad.get_slice(":", 0))
				Input.parse_input_event(event)
				for i in 4:
					await get_tree().process_frame
			await get_tree().process_frame  # (a join happens a moment later)
			var game_focus := GameScreen.instance.menu_viewport.gui_get_focus_owner()  # the menus' viewport
			var hud_focus := get_viewport().gui_get_focus_owner()
			print("DevCapture pad_press %s: paused=%s settings=%s inventory=%s talk=%s using_pad=%s focus=%s hud_focus=%s own_pause=%s lobby=%s" % [
				pad, PauseMenu.is_open, Game.instance.settings_menu.visible, InventoryScreen.for_seat(0).visible,
				NpcDialog.is_open_for(0), Controls.using_pad, _describe_focus(game_focus), _describe_focus(hud_focus),
				range(PlayerId.MAX_LOCAL).map(func(s): return PlayerPause.is_open_for(s)), Seats.lobby_text().replace("\n", " | ")])

	if args.has("remove_local") and Game.instance != null:
		Game.instance.remove_local_player(int(args["remove_local"]))
		print("DevCapture remove_local: slot %s dropped out" % args["remove_local"])

	if args.has("replug"):
		Seats._on_joy_connection_changed(int(args["unplug"]), true)
		for i in 5:
			await get_tree().process_frame
		print("DevCapture replug %s: own_pause=%s unplugged=%s" % [args["unplug"],
			range(PlayerId.MAX_LOCAL).map(func(s): return PlayerPause.is_open_for(s)), Seats._unplugged])

	for i in int(args.get("frames", "90")):
		await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# The scene may have been reloaded meanwhile (e.g. the host quit), so look it up again.
	scene = Game.instance
	if args.has("track"):
		await _track_other_cats(scene, int(args["track"]))

	if args.has("net_stats") and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		# --net_stats=N: how much network data this computer sends / receives, over N frames.
		var connection := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
		connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
		connection.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
		var started := Time.get_ticks_msec()
		var peer := multiplayer.multiplayer_peer
		for i in int(args["net_stats"]):
			await get_tree().process_frame
			if multiplayer.multiplayer_peer != peer:
				break  # the game ended under us (e.g. the host quit first): stop measuring
		var seconds := (Time.get_ticks_msec() - started) / 1000.0
		if multiplayer.multiplayer_peer != peer or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			print("DevCapture net: the game ended after %.1f s (host left?), no measurement" % seconds)
		else:
			var sent := connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
			var received := connection.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
			print("DevCapture net: sent %.1f KB/s, received %.1f KB/s over %.1f s | players=%d roombas=%d computers=%d" % [
				sent / 1024.0 / seconds, received / 1024.0 / seconds, seconds, Game.instance.player_count(),
				Game.instance.get_node("Roombas").get_child_count(), multiplayer.get_peers().size() + 1])
		scene = Game.instance  # (a fresh one if the game ended and the start menu came back)
	print("DevCapture fps=%d process=%.1fms physics=%.1fms objects=%d" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	# Which players' HUDs still show a middle-of-screen message / popup (split screen).
	var showing: Array = []
	for seat in PlayerId.MAX_LOCAL:
		var message := Hud.element("Message", seat)
		if message != null:
			showing.append("P%d message=%s popup=%s" % [seat + 1, message.visible, Hud.element("Popup", seat).visible])
	print("DevCapture hud: %s" % [showing])
	if scene.main_menu.visible and scene.main_menu.status_label.text != "":
		print("DevCapture menu status: %s" % scene.main_menu.status_label.text)
	if scene.main_menu.visible and scene.main_menu.play_screen.visible:
		print("DevCapture found games: %s" % [Net.found_games])
	var city := scene.get_node_or_null("City") as CityGenerator
	if city != null:
		# Fingerprint of where every city object is: identical cities print identical numbers.
		var layout := ""
		for child in city.get_children():
			if not child.is_queued_for_deletion():
				layout += str((child as Node3D).position.snapped(Vector3.ONE * 0.01))
		print("DevCapture city: seed=%d objects=%d fingerprint=%d meow_mart=%s" % [city.city_seed, layout.count("("), layout.hash(), city.meow_mart_position.snapped(Vector3.ONE * 0.1)])
		# The Blockbench street props (models from res://models/): how many, and a few spots.
		var props := {}
		for node in city.find_children("*", "Node3D", true, false):
			var file := node.scene_file_path.get_file().get_basename()
			if file in ["trash_bin", "traffic_cone"]:
				if not props.has(file):
					props[file] = []
				props[file].append((node as Node3D).global_position.snapped(Vector3.ONE * 0.1))
		for file in props:
			print("DevCapture props: %d x %s, e.g. %s" % [props[file].size(), file, props[file].slice(0, 4)])
		_mess._print_mess("snap")
	var heist := scene.get_node_or_null("Heist") as FishHeist
	if heist != null:
		# --mode: which mode this computer is playing, every cat's gang, and the layout it made.
		var manholes := heist.get_children().filter(func(n): return n is Manhole and not n.is_queued_for_deletion()).size()
		var cats_teams := []
		for cat_node in scene.players.get_children():
			cats_teams.append("%s:%d" % [cat_node.name, (cat_node as CatPlayer).team])
		var live_cars: Array = scene.cars().filter(func(c): return not c.is_queued_for_deletion())
		print("DevCapture mode: %s cats=%s entries=%d exits=%d manholes=%d cars=%s" % [
			"TURF WAR" if Game.is_turf_war() else "CO-OP", cats_teams,
			1 if heist.entry_position(0) == heist.entry_position(1) else 2, heist.exit_positions.size(), manholes,
			live_cars.map(func(c): return "%s(team %d)" % [c.name, c.team])])
		print("DevCapture heist: entries=%s exits=%s open=%s revealed=%s sealed=%s cash=%s" % [[heist.entry_position(0), heist.entry_position(1)], heist.exit_positions, [heist.exit_is_open(0), heist.exit_is_open(1)], heist.revealed, heist.sealed, Wallet.instance.cash])
	if HeatMeter.instance != null:
		var regulars := 0
		var bosses := 0
		for roomba in scene.get_node("Roombas").get_children():
			if roomba is Roomba and not roomba.is_queued_for_deletion():
				if (roomba as Roomba).is_boss:
					bosses += 1
				else:
					regulars += 1
		print("DevCapture heat: %.1f level=%d roombas=%d bosses=%d" % [HeatMeter.instance.heat, HeatMeter.instance.level(), regulars, bosses])
	var items := scene.get_node_or_null("Items") as ItemManager
	if items != null:
		var lying := {}
		for id in items.world:
			lying[items.world[id].item] = lying.get(items.world[id].item, 0) + 1
		print("DevCapture items: on street=%s inventories=%s" % [lying, items.inventories])
		for cat in scene.get_node("Players").get_children():
			for hand in 2:
				var weapon := items.held_item(cat, hand) as Weapon
				if weapon != null:
					print("DevCapture weapon: cat %s hand %d shots_seen=%d heat=%.2f overheated=%s" % [cat.name, hand, weapon.shots_seen, weapon.heat, weapon.is_overheated])
	var roombas := scene.get_node_or_null("Roombas")
	if roombas != null:
		var lines := PackedStringArray()
		for roomba in roombas.get_children():
			if roomba is Roomba and not roomba.is_queued_for_deletion():
				lines.append("%s %s %s %s hp=%d stomach=%s" % [roomba.name, roomba.display_name, Roomba.State.keys()[roomba.state], roomba.global_position.snapped(Vector3.ONE * 0.1), roomba.health, roomba.stomach])
		print("DevCapture roombas (%d): %s" % [lines.size(), " | ".join(lines)])
		for cat in scene.get_node("Players").get_children():
			print("DevCapture sticky: cat %s paws=%.1f s, patches=%d, speed=%.1f, hp=%d" % [cat.name, cat._sticky_left,
				StickyPatch.count(), Motion.flat(cat.velocity).length(), CatHealth.instance.get_health(cat.player_id)])
	for seat in 4:
		var compass := Hud.element("Compass", seat) as HudCompassArrow
		if compass != null:
			print("DevCapture compass seat %d: shown=%s text='%s' yaw=%.0f deg urgent=%s top=%.0f" % [seat, compass.visible,
				compass._text, rad_to_deg(compass._target_yaw), compass._urgent, compass.offset_top])
	for car in (scene as Game).cars():
		print("DevCapture car %s (gang %d): position=%s driver=%d passengers=%s frozen=%s" % [car.name, car.team,
			car.global_position.snapped(Vector3.ONE * 0.1), car.driver_id, car.passenger_ids, car.freeze])
		print("DevCapture car_look %s: trim=%s wheels=%d spin=%.2f steer=%.1f deg (input %.2f) speed=%.1f" % [car.name,
			car.trim_color().to_html(false), car._wheels.size(), car._wheel_spin, rad_to_deg(car._wheel_steer), car.steer, car._rolling_speed])
	var players := scene.get_node_or_null("Players")
	if players != null:
		for cat in players.get_children():
			print("DevCapture cat %s: name=\"%s\" tag=\"%s\" visible=%s position=%s in_hub=%s speed_boost=%.1f hp=%d knocked_out=%s team=%d" % [cat.name, cat.player_name, cat.get_node("NameTag").text, cat.visible, cat.position.snapped(Vector3.ONE * 0.1), UndergroundHub.is_in_hub(cat.global_position), cat.speed_boost, CatHealth.instance.get_health(cat.player_id), cat.knocked_out, cat.team])
			# AIM DOWN SIGHTS + recoil (scripts/cat/cat_aim.gd).
			print("DevCapture aim %s: aiming=%s amount=%.2f bloom=%.2f fov=%.1f arm_len=%.2f arm_x=%.2f pitch=%.1f" % [cat.name,
				cat.aim.is_aiming(), cat.aim.amount(), cat.aim.bloom_degrees, cat.camera.fov, cat.spring_arm.spring_length,
				cat.spring_arm.position.x, rad_to_deg(cat.spring_arm.rotation.x)])
			# What it's wearing, as seen on THIS computer (fur colour as hex + accessories).
			var model: Node3D = cat.cat_model
			var worn := PackedStringArray()
			for slot in CatLook.SLOTS:
				var part := model.get_node_or_null("Look_" + slot.capitalize())
				worn.append("%s=%s" % [slot, part.get_meta("part_id") if part != null else "-"])
			var fur: Color = ((model.get_node("Body") as MeshInstance3D).get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("albedo_color")
			print("DevCapture look %s: fur=#%s %s voice=%s" % [cat.name, fur.to_html(false), " ".join(worn), CatLook.voice_of(cat.look)])

	# Headless runs have no picture to save (no real renderer): all the DevCapture lines
	# above are printed already, so just quit instead of crashing on an empty image.
	if DisplayServer.get_name() == "headless":
		print("DevCapture: headless run, no screenshot saved")
		get_tree().quit()
		return

	# The whole window: the blown-up game picture plus the sharp HUD on top.
	# --scale=N saves it as if each game pixel were N screen pixels (N x 240 tall).
	var image := get_viewport().get_texture().get_image()
	var screen := GameScreen.instance
	var game_pixels_tall := screen.game_view.size.y / get_viewport().get_visible_rect().size.y * image.get_height()
	var factor := float(args.get("scale", "4")) * screen.game_height / game_pixels_tall
	image.resize(roundi(image.get_width() * factor), roundi(image.get_height() * factor),
		Image.INTERPOLATE_BILINEAR if factor < 1.0 else Image.INTERPOLATE_NEAREST)
	var path := ProjectSettings.globalize_path("res://" + args["capture"])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("DevCapture saved: ", path)
	get_tree().quit()


## Watches every OTHER player's cat for a number of frames and prints how smoothly it
## moved on screen, next to how the raw network updates arrived.
## "still" = frames where it didn't move at all; "jump" = biggest single-frame move.
func _track_other_cats(scene: Node, frame_count: int) -> void:
	var cats: Array[CatPlayer] = []
	for node in scene.get_node("Players").get_children():
		if not node.is_multiplayer_authority():
			cats.append(node)
	var last_shown := {}
	var last_raw := {}
	var shown_steps := {}
	var raw_steps := {}
	for cat in cats:
		last_shown[cat] = cat.position
		last_raw[cat] = cat.sync_position
		shown_steps[cat] = []
		raw_steps[cat] = []
	for i in frame_count:
		await get_tree().process_frame
		for cat in cats:
			shown_steps[cat].append(cat.position.distance_to(last_shown[cat]))
			raw_steps[cat].append(cat.sync_position.distance_to(last_raw[cat]))
			last_shown[cat] = cat.position
			last_raw[cat] = cat.sync_position
	for cat in cats:
		print("DevCapture track cat %s: on screen %s | raw network %s" % [cat.name, _describe(shown_steps[cat]), _describe(raw_steps[cat])])


func _describe(steps: Array) -> String:
	var still := 0
	var biggest := 0.0
	var total := 0.0
	for step in steps:
		if step < 0.0005:
			still += 1
		biggest = maxf(biggest, step)
		total += step
	return "still %d/%d frames, avg %.3f m, jump %.3f m" % [still, steps.size(), total / maxf(steps.size(), 1), biggest]


## Test only (a client's --give): the host's test tool puts the items in that player's paws.
@rpc("any_peer", "reliable")
func _test_give(player_id: int, item_list: String) -> void:
	if multiplayer.is_server() and PlayerId.sender_owns(player_id):
		for item_id in item_list.split(","):
			ItemManager.instance._put_in_inventory(player_id, item_id, Vector3.ZERO)


## --near_speaker=D: stand D metres out in the street from the loudspeaker pole nearest the
## city's middle (its horns face the street), facing it.
func _near_speaker(player: CatPlayer, args: Dictionary) -> void:
	var poles := Game.instance.city.loudspeakers
	print("DevCapture speaker: %d loudspeaker poles in this city" % poles.size())
	if poles.is_empty():
		return
	var pole: Node3D = poles[0]
	for p in poles:
		if Vector2(p.global_position.x, p.global_position.z).length() < Vector2(pole.global_position.x, pole.global_position.z).length():
			pole = p
	var front := -pole.global_basis.z  # the way the horns point
	var side := pole.global_basis.x
	player.global_position = pole.global_position + front * float(args["near_speaker"]) + side * float(args.get("speaker_side", "2.5")) + Vector3(0, 0.5, 0)
	var look := (pole.global_position - player.global_position) * Vector3(1, 0, 1)
	player.camera_pivot.rotation.y = atan2(-look.x, -look.z) + deg_to_rad(float(args.get("speaker_turn", "0")))
	player.unseen_by_bots = true  # (a test: keep the VAC-COPs off while we look)
	print("DevCapture speaker: %s at %s, cat at %s" % [pole.name, pole.global_position, player.global_position])


## --announce[=moment]: OVERCLEAN says one of its lines now (after a short wait), on the poles.
func _announce(args: Dictionary) -> void:
	await _seconds(1.0)
	var a := OvercleanAnnouncer.instance
	var moment: String = args["announce"] if not args["announce"] in ["", "true"] else "boss"
	var pick: Array = {
		"boss": [a.boss_sound, a.boss_line], "seal": [a.seal_sound, a.seal_line],
		"level2": [a.level_2_sound, a.level_2_line], "level3": [a.level_3_sound, a.level_3_line],
		"level4": [a.level_4_sound, a.level_4_line], "ko": [a.knockout_sound, a.knockout_line],
		"deploy": [a.deploy_sounds[0], a.deploy_lines[0]],
	}.get(moment, [a.boss_sound, a.boss_line])
	a.say(pick[0], pick[1], true, 0.0, "test --announce=" + moment)
	await _seconds(1.5)
	var talking := 0
	for node in get_tree().get_nodes_in_group(Loudspeaker.GROUP):
		if (node as FloatingLine).is_talking():
			talking += 1
	print("DevCapture speaker: announced \"%s\" on %d poles, subtitle shown=%s" % [a.last_text.left(50), talking, (Hud.element("Subtitle") as Control).visible if Hud.element("Subtitle") != null else false])


## --car_watch=N: every N frames, print where the car camera is looking (runs alongside the rest).
func _watch_car_camera(car: GetawayCar, every: int) -> void:
	while is_instance_valid(car):
		for i in every:
			await get_tree().process_frame
		if is_instance_valid(car):
			print("DevCapture car_watch: look_yaw=%.2f look_pitch=%.2f speed=%.1f" % [car.look_yaw, car.look_pitch, -car.global_basis.z.dot(car.linear_velocity)])


## DISTRICT TWISTS (scripts/district_twist.gd): what this district's twist did to the city.
func _print_twist(scene: Node, args: Dictionary) -> void:
	var twist := DistrictTwist.instance
	if args.has("twist_rolls"):
		# What 1000 districts in a row (district 2 onwards) would roll, from seeds 1..1000.
		var counts := {}
		var saved := twist.kind
		var saved_forced := DistrictTwist.forced_kind
		DistrictTwist.forced_kind = -1
		var repeats := 0
		for city_seed in range(1, 1001):
			var rolled := twist.roll(city_seed, 2)
			if rolled != DistrictTwist.Kind.NONE and rolled == twist.kind:
				repeats += 1
			twist.kind = rolled
			counts[DistrictTwist.name_of(rolled) if rolled != 0 else "NONE"] = int(counts.get(DistrictTwist.name_of(rolled) if rolled != 0 else "NONE", 0)) + 1
		twist.kind = saved
		DistrictTwist.forced_kind = saved_forced
		print("DevCapture twist rolls (1000 districts): %s back-to-back repeats=%d district1=%s tutorial-safe" % [counts, repeats,
			DistrictTwist.name_of(twist.roll(42, 1)) if DistrictTwist.forced_kind < 0 else "(forced)"])
	var bots := 0  # (counted now, before any --kill_roombas)
	var sight := 0.0
	for node in scene.get_node("Roombas").get_children():
		var bot := node as Roomba
		if bot != null and not bot.is_boss:
			bots += 1
			sight = bot.sight_range * DistrictTwist.sight_multiplier()
	for i in 30:
		await get_tree().physics_frame
	var city := scene.get_node("City") as CityGenerator
	var lamps_lit := 0
	var lamps := 0
	for child in city.get_children():
		var cone := child.get_node_or_null("LightCone") as Light3D
		if cone != null:
			lamps += 1
			lamps_lit += 1 if cone.visible else 0
	var door := city.meow_mart_position
	var mart_fish := 0
	var mart_koi := 0
	for id in ItemManager.instance.world:
		var entry: Dictionary = ItemManager.instance.world[id]
		if (entry.pos as Vector3).distance_to(door) < 7.0:
			mart_fish += 1 if entry.item == "fish" else 0
			mart_koi += 1 if entry.item == "golden_koi" else 0
	var kinds := {}
	for p in city.mess_props:
		var key: String = MessProp.Kind.keys()[p.kind]
		kinds[key] = int(kinds.get(key, 0)) + 1
	var intel: Array = [DistrictTwist.intel_line()]  # (the line itself: the CRT only shows the % now)
	print("DevCapture twist: %s district=%d city=#%d lamps lit %d/%d ambient=%.2f moon=%.2f bot sight=%.1f m (x%.2f) mess props=%d %s" % [
		DistrictTwist.name_of(twist.kind) if twist.kind != 0 else "NONE", twist.district_number, city.city_seed, lamps_lit, lamps,
		(scene.get_node("WorldEnvironment") as WorldEnvironment).environment.ambient_light_energy,
		(scene.get_node("Moonlight") as Light3D).light_energy, sight, DistrictTwist.sight_multiplier(), city.mess_props.size(), kinds])
	print("DevCapture twist: meow-mart fish=%d koi=%d | regular bots=%d (x%.2f) | heat x%.2f | CRT intel %s | boss news \"%s\" | send-off \"%s\"" % [
		mart_fish, mart_koi, bots, DistrictTwist.bot_multiplier(), DistrictTwist.heat_multiplier(), intel, twist.news_line(),
		DistrictTwist.send_off_line("(usual)")])
	if args.has("twist_heat") and multiplayer.is_server():
		var frames := int(args["twist_heat"])
		var before := HeatMeter.instance.heat
		for i in frames:
			await get_tree().physics_frame
		var rise := HeatMeter.instance.heat - before
		print("DevCapture twist heat: +%.2f in %d frames = %.3f/s (base %.3f/s, twist x%.2f, up top %d)" % [rise, frames,
			rise / (frames / float(Engine.physics_ticks_per_second)), HeatMeter.instance.heat_per_second,
			DistrictTwist.heat_multiplier(), Game.instance.players_up_top()])


## How many of this item lie on the street / sewer floors right now.
func _count_world_items(item_id: String) -> int:
	var count := 0
	for id in ItemManager.instance.world:
		count += 1 if ItemManager.instance.world[id].item == item_id else 0
	return count


## A fake controller event: "A" / "Start" press or release, or a stick / trigger pushed all
## the way (pressed) or let go (not pressed). Same names as Controls.PAD_BUTTONS / PAD_AXES.
func _pad_event(pad_name: String, pressed: bool) -> InputEvent:
	var event := Controls._event_from_name("Pad " + pad_name)
	assert(event != null, "unknown controller name: " + pad_name)
	event.device = int(_args.get("pad_device", "0"))
	if event is InputEventJoypadButton:
		event.pressed = pressed
	elif not pressed:
		event.axis_value = 0.0
	return event


## "Button 'RESUME'" for the focus printout (or "-" when nothing is highlighted).
func _describe_focus(control: Control) -> String:
	if control == null:
		return "-"
	var text: String = control.get("text") if control.get("text") != null else ""
	return "%s '%s'" % [control.get_class(), text]


## --test-room-code (headless): every way of writing a code must give the same address back.
## Prints a PASS / FAIL line and quits with exit code 1 on any failure.
func _test_room_code() -> void:
	var failures: Array[String] = []
	var check := func(what: String, got: Variant, wanted: Variant) -> void:
		if got != wanted:
			failures.append("%s: got '%s', wanted '%s'" % [what, got, wanted])
	check.call("example", Net.ip_to_code("73.154.33.176"), "MEOW-499A-21B0")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1999
	var addresses: Array[String] = ["0.0.0.0", "255.255.255.255", "127.0.0.1", "10.0.0.1"]
	for i in 500:
		addresses.append("%d.%d.%d.%d" % [rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255)])
	for ip in addresses:
		var code := Net.ip_to_code(ip)
		var bare := code.trim_prefix("MEOW-")
		for spelling in [code, code.to_lower(), bare, bare.to_lower(), bare.replace("-", ""),
				bare.replace("-", " "), "  %s  " % code, ip, ip + ":7777"]:
			check.call(spelling, Net.code_to_ip(spelling), ip)
	for junk in ["", "MEOW", "MEOW-499A", "MEOW-499A-21BG", "499A21B0F", "+499A21B", "not a code", "::1", "256.1.1.1"]:
		check.call("junk " + junk, Net.code_to_ip(junk), "")
	for not_ipv4 in ["", "::1", "999.1.1.1", "hello"]:
		check.call("no code for " + not_ipv4, Net.ip_to_code(not_ipv4), "")
	check.call("public", Net.is_public_ip("73.154.33.176"), true)
	for private in ["10.1.2.3", "100.64.0.1", "100.127.255.1", "172.16.0.1", "192.168.1.1", "127.0.0.1", "169.254.1.1", ""]:
		check.call("private " + private, Net.is_public_ip(private), false)
	check.call("VPN first", Net.best_local_ip(PackedStringArray(["127.0.0.1", "fe80::1", "172.20.0.1", "192.168.1.5", "100.100.1.1"])), "100.100.1.1")
	check.call("home over WSL", Net.best_local_ip(PackedStringArray(["172.20.0.1", "192.168.1.5", "192.168.56.1"])), "192.168.1.5")
	check.call("Wi-Fi over Hyper-V", Net.best_local_ip(PackedStringArray(["169.254.1.2", "192.168.128.1", "192.168.130.247"])), "192.168.130.247")
	check.call("nothing usable", Net.best_local_ip(PackedStringArray(["127.0.0.1", "169.254.3.4", "::1"])), "")
	for failure in failures.slice(0, 20):
		print("DevCapture room code FAIL ", failure)
	print("DevCapture room code test: %s (%d addresses, %d failures)" % ["FAIL" if failures.size() > 0 else "PASS", addresses.size(), failures.size()])
	get_tree().quit(1 if failures.size() > 0 else 0)


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var result := {}
	for arg in raw:
		var parts := arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return result


# --- MEOW-MART (scripts/interiors/meow_mart_interior.gd) ---


## Makes one test module (a child node) and hands it the command line options.
func _add_module(path: String) -> Node:
	var module: Node = (load(path) as GDScript).new()
	module.name = path.get_file().get_basename()
	module._args = _args
	add_child(module)
	return module
