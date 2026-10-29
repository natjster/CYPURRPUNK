class_name Teams
## CYPURRPUNK — THE TWO REBELLIONS. Every cat belongs to one of two gangs hiding under the city,
## each with its own sewer (its own UndergroundHub, scripts/hub.gd):
##   0 = THE CATLEONE FAMILY  - Don Catleone's crew (the "Hub" node in main.tscn)
##   1 = THE BURROW GANG      - Pawnie & Clawd's crew (the "GangHub" node in main.tscn)
## Each blames the other for letting OVERCLEAN take over. Both are sure they're the good guys.
##
## Players pick a gang for each game on the start menu's landing page (stored here in picks,
## by seat). A cat's gang is CatPlayer.team: its owner sets it from the pick, and the cat's
## MultiplayerSynchronizer sends it to everyone (like its name and look).
##
## What a gang changes so far: which sewer you start in and come home to, who can revive you
## (teammates only), and the colour of your name and floating health bar (your gang's cyan bar
## = friend, the other gang's = red). Guns don't hurt other cats yet (PvP is the next phase).
##
## ADDING A THIRD GANG: add a line to NAMES and COLORS, then a third hub in main.tscn (copy
## GangHub, set its Team to 2, move it 200 m further along x).
##
## Everything here is "static": call it on the class, e.g. Teams.same_team(a, b).

const CATLEONE := 0
const BURROW := 1

## Each gang's name (HUD, menus).
const NAMES: Array[String] = ["CATLEONE FAMILY", "BURROW GANG"]
## Each gang's colour: its cats' names over their heads and the menu button.
const COLORS: Array[Color] = [Color(1, 0.4, 0.85), Color(1, 0.65, 0.15)]

## The gang each seat on this computer picked on the landing page (seat 0 = player 1).
## Kept between games, so a rematch keeps the same sides.
static var picks: Array[int] = [CATLEONE, CATLEONE, CATLEONE, CATLEONE]


static func count() -> int:
	return NAMES.size()


static func name_of(team: int) -> String:
	return NAMES[clampi(team, 0, count() - 1)]


static func color_of(team: int) -> Color:
	return COLORS[clampi(team, 0, count() - 1)]


## The gang the player in this seat picked (for the game about to start).
static func picked(seat: int) -> int:
	return picks[seat] if seat >= 0 and seat < picks.size() else CATLEONE


## Landing page: switch this seat to the next (direction 1) or previous (-1) gang.
static func cycle_pick(seat: int, direction: int = 1) -> void:
	if seat >= 0 and seat < picks.size():
		picks[seat] = posmod(picks[seat] + direction, count())


## The gang of a player in the game (CATLEONE if they have no cat).
static func team_of(player_id: int) -> int:
	var cat := Game.instance.cat_for(player_id) if Game.instance != null else null
	return cat.team if cat != null else CATLEONE


## Are these two players in the same gang?
static func same_team(player_a: int, player_b: int) -> bool:
	return team_of(player_a) == team_of(player_b)
