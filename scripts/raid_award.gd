class_name RaidAward
extends Resource
## CYPURRPUNK — ONE SILLY AWARD on the RAID REPORT (scripts/raid_report.gd), e.g. "BUTTERPAWS".
##
## Every award is one of these saved as a .tres card in res://raid_awards/. The report loads
## every card in that folder by itself, so ADDING AN AWARD = ADDING A CARD:
##   1. In the FileSystem dock, open the raid_awards folder, right-click any card (e.g.
##      butterpaws.tres) > Duplicate..., and give the copy a new file name.
##   2. Click the new card and change it in the Inspector (every field is explained there).
##   3. Run the game. That's it: no code.
##
## HOW AWARDS ARE HANDED OUT (the same on every computer, because the host does it once and
## sends the result to everyone):
##   - The cards are tried in ORDER (lowest number first).
##   - For each card, every cat that has NO award yet and QUALIFIES (its stat is between At Least
##     and At Most, and its Needs stat is 1 or more) is a candidate. The one with the MOST (or
##     LEAST) of the stat wins. A tie goes to the cat higher up the report (who joined first).
##   - So every cat gets exactly ONE award, and no two cats get the same one. The cards with no
##     stat (WARM LOAF, BACKGROUND CAT...) fit anyone: they're the safety net at the end.
##
## THE STATS an award can look at (one row's numbers on the report):
##   cash       cash brought home (loot + quest bonus)   loot      loot value alone
##   bonus      quest bonus cash                          bots      VAC-COPs smashed (bosses too)
##   bosses     MEGA VAC-COPs smashed                     downs     times DOWNED
##   revives    team-mates picked back up                 damage    HP of damage taken
##   vacuumed   loot items a VAC-COP sucked out of them   knockouts times VACUUMED (knocked out)
##   robbed     rival cats they robbed (TURF WAR)         went_up   1 = went up top, 0 = stayed home
##   extracted  1 = made it down an exit                  left      1 = quit before the end
##   mess       MESS MADE (always 0 until mess-making arrives in Phase 1)

enum Pick { MOST, LEAST }

## Short unique name, used by tests and the "DevCapture report" line. No spaces, e.g. "butterpaws".
@export var id: String = ""
## The award's name, BIG on the report, e.g. "BUTTERPAWS". Keep it short (about 14 letters):
## the whole report shares one 240-pixel-tall screen.
@export var title: String = ""
## The small line under the title. {value} becomes the stat's number, e.g.
## "LOST {value} LOOT TO BOTS" -> "LOST 3 LOOT TO BOTS". Keep it short too (about 18 letters).
@export var line: String = ""
## Which stat decides it (from the list at the top of this script). Empty = anyone qualifies
## (a safety-net award: ties go to whoever is highest on the report).
@export var stat: String = ""
## MOST = the biggest number wins; LEAST = the smallest wins.
@export var pick: Pick = Pick.MOST
## Only cats whose stat is at least this much can get it (e.g. 1 = "did it at least once").
@export var at_least: float = 0.0
## ...and at most this much (e.g. 0 with LEAST = "never did it").
@export var at_most: float = 999999.0
## Another stat that must be 1 or more, or empty for none. E.g. GHOST needs "extracted"
## (no damage AND made it home; staying home doesn't count).
@export var needs: String = ""
## Lower numbers are handed out first. Leave gaps (10, 20, 30...) so new cards fit in between.
@export var order: int = 100
## The title's colour on the report.
@export var color: Color = Color(1, 0.85, 0.3)
