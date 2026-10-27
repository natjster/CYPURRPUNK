# CYPURRPUNK Discord: setup kit

Everything here can be copied and pasted into Discord. Do the steps in order; it takes about 30 minutes.
Screenshots for your first posts are in `discord/shots/` (`city.png`, `hub.png`).

---

## 1. Make the server

1. In Discord, click the **+** at the bottom of the server list (left side).
2. **Create My Own** → **For a club or community**.
3. Name: **CYPURRPUNK** — upload an icon (see section 9), then **Create**.
4. Delete the default `#general` and voice channels Discord makes. You'll build your own below.

### Turn on "Community" (do this — it unlocks the good stuff)
**Server name (top left) → Server Settings → Enable Community → Get Started.**
It asks for a rules channel and an updates channel: create `#the-rules` and `#mod-stuff` first (section 3),
or let it make them and rename them later. Community gives you:
- **Announcement channels**: people in other servers can press "Follow" on `#devlog` and get your posts.
- **Onboarding**: new members pick roles themselves (no bot needed — section 5).
- **Server Discovery** later, once you have enough members.

Safety settings it asks for: **Verification level: Low**, **Explicit media filter: scan all members**.

---

## 2. Server description
**Server Settings → Overview** (and in Community → Overview):

> A PS1-style cyberpunk extraction game about cats. Steal fish. Dodge the VAC-COPs. Get back to the sewers before the beam closes. Dev-logs, updates, and an unreasonable number of cat pictures.

---

## 3. Channels

Right-click the channel list → **Create Category**, then **+** next to a category to add channels.
"📢" = choose **Announcement** as the channel type. "💬" = Text. "🗂" = **Forum**. "🔊" = Voice.

**THE SURFACE** (read-only: under the category's Edit → Permissions, turn **Send Messages ✗** for @everyone)
| Channel | Type | Topic (Edit Channel → Topic) |
|---|---|---|
| `#the-rules` | 💬 | Don Catleone's laws. Break them and you sleep with the sardines. |
| `#devlog` | 📢 | Dev-logs straight from the litter box. Press Follow to get them in your own server. |
| `#patch-notes` | 📢 | What changed, what broke, what got fixed by accident. |
| `#commit-feed` | 💬 | Live feed of every change to the game. Mostly "fix split screen" forever. (Section 7) |

**THE SEWERS** (main hangout)
| Channel | Type | Topic |
|---|---|---|
| `#the-sewers` | 💬 | General chat. Safe zone. Guns don't fire down here. |
| `#cat-pics` | 💬 | Real cats only. Your cat is the main character now. |
| `#memes-and-hairballs` | 💬 | Shitposting containment unit. |
| `#show-your-cat` | 💬 | Screenshots of your cat from MY CAT. Rate hats. |

**THE BLACK MARKITTEN** (game feedback)
| Channel | Type | Topic |
|---|---|---|
| `#bug-reports` | 🗂 | One post per bug. Tell us what you did, what happened, and what you expected. |
| `#ideas` | 🗂 | Pitch features. Comrade Whiskers takes all submissions, he promises nothing. |
| `#playtest-signups` | 💬 | Want to play builds early? Say so here. |

**MEOW-MART PARKING LOT** (voice)
| Channel | Type |
|---|---|
| `🔊 Getaway Car` (user limit 8 — max players) | Voice |
| `🔊 Lo-fi Sewer Beats` | Voice |

**STAFF ONLY** (Edit → Permissions → @everyone **View Channel ✗**, Mod role **✓**)
| `#mod-stuff` | 💬 | |

Bug-report forum tags (Edit Channel → Tags): `crash`, `multiplayer`, `split-screen`, `visual`, `roomba did something weird`, `fixed ✅`.

---

## 4. Roles
**Server Settings → Roles → Create Role.** Top to bottom (higher = more power):

| Role | Colour | Permissions | Who |
|---|---|---|---|
| **Don Catleone** | `#2ECC71` | Administrator | You |
| **Enforcer** | `#9B59B6` | Manage Messages, Timeout Members, Manage Threads | Mods you trust |
| **Playtester** | `#E67E22` | (none extra) | People testing builds |
| **Heist Crew** | `#00E5FF` | (none extra) | Everyone (given by onboarding) |
| **Devlog Pings** | grey | (none) | Want a ping on new devlogs |
| **Playtest Pings** | grey | (none) | Want a ping when a build is up |

Tick **Display role members separately** on Don Catleone, Enforcer and Playtester.
To ping a role in a post, also tick **Allow anyone to @mention this role** — or just ping it yourself as admin.

---

## 5. Onboarding (new members pick their own roles)
**Server Settings → Onboarding**. Default channels: `#the-rules`, `#devlog`, `#the-sewers`, `#cat-pics`.

**Question 1: "What brings you to the sewers?"** (multiple answers allowed)
- 📰 *I want devlogs* → gives **Devlog Pings**
- 🎮 *I want to playtest* → gives **Playtest Pings**, shows `#playtest-signups`
- 🐈 *I just want to look at cats* → shows `#cat-pics`

**Question 2: "Pick your cat crime"** (one answer, just for fun — gives nothing, or make tiny cosmetic roles)
- 🐟 Fish thief  ·  🧹 Roomba hater  ·  🐠 Golden koi or bust  ·  📦 Sits in boxes

**Welcome Screen** (Community → Welcome Screen) description:
> Welcome to the sewers, kitten. Read the rules, grab a role, and stay out of sight of the VAC-COPs.

---

## 6. Posts to paste

### `#the-rules`
```
📜 THE LAWS OF DON CATLEONE

1. Be nice. We're all cats here. Some of us are just bigger cats.
2. No hate, harassment, or creepy stuff. The Enforcers will escort you out. Permanently.
3. Keep it SFW. This is a family business.
4. No spam, no self-promo without asking. Comrade Whiskers controls the advertising market.
5. Bugs go in #bug-reports, not in the Don's DMs. He is a busy cat.
6. No leaking playtest builds. The VAC-COPs have your IP. (They don't. But they want it.)
7. Follow Discord's Terms of Service: https://discord.com/terms

Break a rule: warning. Break it again: timeout. Third time: you sleep with the sardines. 🐟
```

### First message in `#the-sewers`
```
🐾 The sewers are open. Pull up a pipe.

This is the home of CYPURRPUNK — a PS1-style cyberpunk extraction game where you play a cat
stealing fish from a neon city while robot vacuum cops hunt you down.

📢 #devlog for updates  ·  🐛 #bug-reports when things break (they will)  ·  🐈 #cat-pics is mandatory
```

### First devlog — `#devlog` (attach `city.png` and `hub.png`)
```
🐟 CYPURRPUNK DEVLOG #1 — "We Have A Game (Allegedly)"

Hi! I'm making a game about cats doing crimes. Here's what exists so far:

🏙️ THE CITY — Every match generates a brand-new neon city: rain, fog, glowing signs, a Meow-Mart.
   Everything renders at 320x240 with wobbly PS1 polygons and a CRT filter, on purpose.

🕳️ THE SEWERS — Your safe zone. Don Catleone sends you up top, Comrade Whiskers runs the
   Black Markitten (guns, gear, no refunds), and Lil' Mittens needs fish. Lots of fish.

🧹 THE VAC-COPS — Robot vacuums. They patrol. They hunt. They EAT YOUR LOOT. Smack one and it
   coughs up what it swallowed. Make too much noise and HEAT goes up — at max heat, the boss shows up.

🐠 THE LOOT — Sardines ($20), fish ($50), and one golden koi ($400) that every Roomba in the
   city will chase you for. Grab what you can and get to an extraction beam before it closes.

🎮 MULTIPLAYER — Up to 8 cats online, and up to 4 on one couch with split screen.
   Yes, it was painful. Yes, it works now. Mostly.

🎩 MY CAT — Make your own cat: fur colours, hats, faces, accessories. Save as many cats as you want.

Next up: more polish, more cat crimes, and getting it into your paws for playtesting.
Want in early? Go to #playtest-signups. 🐾

@Devlog Pings
```
(Type `@Devlog Pings` yourself when you post, so Discord turns it into a real ping.)

---

## 7. Automatic commit feed (optional, nerdy, fun)
Every time you push from GitHub Desktop, a message appears in `#commit-feed` with your commit message.
Your commit messages are already readable ("Fix split screen: player 2's messages stuck...") so this works
like a free mini-devlog.

1. In Discord: `#commit-feed` → **Edit Channel (⚙) → Integrations → Webhooks → New Webhook** →
   name it **Commit Cat** → **Copy Webhook URL**.
2. On GitHub: your repo → **Settings → Webhooks → Add webhook**.
3. **Payload URL** = the copied URL with **`/github`** added to the end.
4. **Content type** = `application/json`. Choose **Just the push event**. **Add webhook**.

⚠️ Everyone in the server will see commit messages (not the code). If the repo is private and you'd
rather keep it quiet, skip this — or put `#commit-feed` behind the Playtester role.

---

## 8. Writing devlogs without it eating your week
Short and regular beats long and rare. Every 1–2 weeks is great. Template:

```
🐟 CYPURRPUNK DEVLOG #N — "<funny title>"

✨ NEW: <the big thing, 1–3 lines, with a screenshot or GIF>
🔧 FIXED: <2–4 bullets>
😿 BROKE: <something that went hilariously wrong — people love these>
🔜 NEXT: <one line>

@Devlog Pings
```

Easy wins:
- **Ask Claude**: "write devlog #2 from the commits since the last devlog" — it can read the git history.
- **Screenshots**: take them in-game, or ask Claude for a `--capture` shot of any spot in the city.
- **GIFs**: Windows **Win+Alt+R** records the game (Xbox Game Bar); convert with ezgif.com. Short clips of
  Roombas eating things will do numbers.
- Pin your best devlog in `#devlog` (hover message → ⋯ → Pin).
- Title ideas: "The Roombas Have Unionized", "Split Screen Was A Mistake (It Works Now)",
  "Introducing: Hats", "Heat Level 5 And Other Bad Decisions", "We Fixed The Floor Flickering, Probably".

---

## 9. Icon, banner, emojis
- **Icon**: `discord/server_icon_don_catleone.png` (960×960, Don Catleone himself).
  **Server Settings → Overview → Upload Image**; Discord crops it to a circle — his face stays centred.
  Made with `--portrait=DonCatleone --portrait_dist=2.6 --portrait_side=0.5` (any NPC name works).
  Alternative: `discord/server_icon_rambo_cat.png` (1280×1280) — a pale-cyan player cat in the MOHAWK, CIGAR
  and BANDOLIER (real MY CAT accessories), lit by Don's pink lamp. Made with
  Same cat in the game's own fur colours: `server_icon_rambo_cat_charcoal.png` (`fur:#383342`) and
  `server_icon_rambo_cat_brown.png` (`fur:#734d33`).
  `"--wear=hat:mohawk,neck:bandolier,face:cigar,fur:#9fe6f2" --pos=6.3,-200,-14.2 --portrait=me --portrait_dist=1.8 --portrait_height=0.8 --portrait_side=0.6`.
- **Banner** needs boost level 2 — skip for now. **Invite background** needs level 1.
- **Emojis** (Server Settings → Emoji → Upload; 128×128 PNG): crop from game screenshots —
  `:roomba:`, `:goldenkoi:`, `:sardine:`, `:catleone:`, `:heat5:`, `:beam:`.
  Use them as custom reactions on devlogs.

---

## 10. Bots (optional — you don't need any to start)
- **Carl-bot**: auto-moderation, logs, reaction roles. Onboarding covers roles already, so only add it if you grow.
- Discord's built-in **AutoMod** (Server Settings → Safety Setup → AutoMod): turn on "Block spam" and
  "Block mention spam". Free and no bot needed.

---

## 11. Invite link that never expires
Right-click `#the-sewers` → **Invite People → Edit invite link** → Expire after: **Never**, Max uses: **No limit**.
Put that link in your itch.io/Steam page and your social bios later.
