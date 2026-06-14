# BYPASS — GOATvision Seattle: Full Project Overview
> Use this file to onboard a new Claude chat with full context on the build.

---

## What Is This?

**BYPASS** is a satirical browser-based game built in React (Vite) that simulates the modern job application experience. The concept: you're a job seeker trying to get your resume past a fictional ATS (Applicant Tracking System) called **SENTINEL-7**, then survive a 16-bit Zoom interview with a glitching hiring manager named "Dave K."

It's a 4-phase single-page game with a dark terminal/CRT aesthetic, custom audio with Web Audio API effects, and optional Claude AI (Anthropic API) integration for dynamic content generation.

The project was built and iterated on at **GOATvision Seattle** as a demo/showcase build.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | React 18 + Vite |
| Styling | Tailwind CSS + inline styles (IBM Plex Mono font) |
| Animation | Framer Motion |
| Icons | Lucide React |
| Audio | Web Audio API (custom hook) |
| AI (optional) | Anthropic Claude API (`claude-haiku-4-5-20251001`) |
| Build | Vite (`npm run dev` / `npm run build`) |

**No backend.** Everything runs client-side. The Anthropic API key is optional — all AI calls have static fallbacks built in.

---

## File Structure

```
BYPASS/
├── src/
│   ├── App.jsx                  ← Root component, phase state machine
│   ├── main.jsx                 ← React entry point
│   ├── index.css                ← Global styles (CRT effects, glitch, etc.)
│   ├── components/
│   │   ├── IntroScreen.jsx      ← Phase 0: Title screen + mission briefing
│   │   ├── Phase1Cram.jsx       ← Phase 1: 7-second JD memorization
│   │   ├── Phase2Gauntlet.jsx   ← Phase 2: Swipe card gauntlet (21 cards)
│   │   ├── SwipeCard.jsx        ← Draggable/swipeable card component
│   │   ├── ResumeShredder.jsx   ← Fail animation (resume shredder)
│   │   ├── Phase3Wait.jsx       ← Phase 3: Fake ATS processing screen
│   │   ├── Phase4Boss.jsx       ← Phase 4: Pixel boss Zoom interview
│   │   ├── ResultScreen.jsx     ← Outcome screen (hire/holding/reject)
│   │   └── ShareResult.jsx      ← LinkedIn mock card + copy-to-clipboard
│   ├── data/
│   │   └── gameContent.js       ← ALL game content: JD templates, cards, boss Qs, results
│   ├── hooks/
│   │   └── useAudio.js          ← Web Audio API hook (battle + interview tracks)
│   └── utils/
│       └── llmApi.js            ← Anthropic Claude API calls with static fallbacks
├── public/
│   ├── ats_battle.mp3           ← Battle music (Phase 1–2)
│   └── interview_vibe.mp3       ← Interview music (Phase 4)
└── package.json
```

---

## How the Game Works: Phase by Phase

### App.jsx — The State Machine

`App.jsx` controls everything via a `phase` state variable with 6 states:
`INTRO → CRAM → GAUNTLET → WAIT → BOSS → RESULT`

Each phase is a separate component. `AnimatePresence` handles transitions between them. `gameData` accumulates: the JD pulled, gauntlet score, boss score, and final outcome.

---

### Phase 0: INTRO (`IntroScreen.jsx`)

- Title screen with glitch CSS effect on "BYPASS"
- Mission briefing card explains the 4 phases
- "INITIATE BYPASS" button with blinking cursor effect
- Keyboard hint: ← = Not in JD, → = Was in JD

---

### Phase 1: THE CRAM (`Phase1Cram.jsx`)

- **7 seconds** to memorize a randomly selected Job Description
- Circular countdown timer (SVG, color shifts green→yellow→pink)
- JD card shows: job title, company name, satirical "about" blurb, requirements
- **Green highlighted section**: 5 Required KSAs (these are on the quiz)
- **Teal highlighted section**: 5 additional items listed in requirements (also on quiz)
- Timer bar at bottom
- Auto-advances to Gauntlet when timer hits 0

---

### Phase 2: THE GAUNTLET (`Phase2Gauntlet.jsx` + `SwipeCard.jsx` + `ResumeShredder.jsx`)

**21 cards total**, shuffled randomly each game:

| Card Type | Count | Correct Swipe | Description |
|---|---|---|---|
| KSA cards | 5 | RIGHT (→) | Required KSAs from the JD |
| On-JD extras | 5 | RIGHT (→) | Other items listed in JD requirements |
| Decoy cards | 5 (of 8) | LEFT (←) | Similar-sounding terms NOT in this JD |
| Obvious fakes | 3 (of 4) | LEFT (←) | Absurd/impossible requirements |
| Bot-killers | 3 (of 8) | LEFT (←) | ATS-destroying resume formatting (nested tables, photos, dual columns, etc.) |

**Rules:**
- One wrong swipe = INSTANT FAIL → triggers ResumeShredder animation → goes to Result screen as "REJECT"
- Keyboard support: arrow keys ← →
- Cards can be dragged (SwipeCard)
- Vibe Meter starts at 100% (currently display only — decrements on wrong answer before fail state triggers)
- Battle music speeds up as you progress through cards (playbackRate ramps 1.0 → 1.6)
- On wrong swipe: vinyl scratch-to-silence Web Audio effect plays

---

### Phase 3: THE WAIT (`Phase3Wait.jsx`)

- **15-second** fake ATS processing screen
- Rotating status messages cycle through satirical processing steps (e.g., "Cross-referencing against 847 required skills...", "Routing to: HUMAN_REVIEW_QUEUE_7... Overriding. Re-routing to: AUTOMATED_REJECT...")
- Scrolling terminal log at the bottom
- Progress bar advances
- Auto-advances to Boss phase after 15s, triggering interview music swap

---

### Phase 4: THE BOSS (`Phase4Boss.jsx`)

- Simulated Zoom call with "Dave K. | Hiring Mgr"
- **Pixel art boss sprite** (8x8 grid, hand-coded color arrays) — animates mouth open/close while "typing"
- **7 questions** with typewriter text effect (gibberish corporate speech + the actual question decoded in brackets)
- YES / NO answer buttons appear after typing completes
- **Correct answers score +1**, wrong answers drop Vibe Meter by 18%
- Connection quality degrades as vibe drops: HD → SD → LOW (visual distortion on video panel)
- Interview music low-pass filter tightens as vibe drops (muffled effect)
- Score tracked with dot indicators at bottom

**Boss Questions (7 total, static):**
1. Can you leverage cross-functional synergy? → YES
2. Are you currently employed? → NO
3. Can you start immediately? → YES
4. Are you passionate about synergy? → YES
5. Do you have competing offers? → YES
6. Are you a disruptor (vs. stabilizer)? → YES
7. Are you hungry? → YES

---

### Result Screen (`ResultScreen.jsx` + `ShareResult.jsx`)

**Three possible outcomes** (determined in `App.jsx`):

| Outcome | Condition | Display |
|---|---|---|
| **HIRE** | Boss score = 7 AND random() < 0.10 (10% chance) | Trophy icon, green, offer email |
| **HOLDING** | Boss score 5–7 (and not the lucky 10%) | Clock icon, teal, "active consideration" email |
| **REJECT** | Boss score < 5, OR failed gauntlet | X icon, pink, rejection email |

- Shows performance stats: Gauntlet correct count + Boss score /7
- If failed on a specific card, shows exactly what card caused the fail
- Fake email rendered with outcome-appropriate copy
- **LinkedIn mock card** with a randomly selected satirical LinkedIn status
- "Copy LinkedIn Status" button (clipboard API)
- "ATTEMPT RE-APPLICATION" resets everything

---

## JD Templates (`gameContent.js`)

8 total JD templates, one randomly selected per game:

| ID | Title / Company |
|---|---|
| `tech-innovation` | Senior Thought Leader & Innovation Catalyst — SynergyCorp™ |
| `marketing` | Chief Experience Evangelist & Brand Alchemist — NarrativeCraft™ |
| `finance` | VP of Value Creation & Capital Flow Architect — Apex Capital Dynamics™ |
| `hr-people` | Head of People Excellence & Talent Ecosystem Builder — HumanFirst™ |
| `operations` | Director of Process Innovation & Operational Excellence — EfficiencyFirst™ |
| `consulting` | Senior Transformation Partner & Change Agent — McKBoston & Associates™ |
| `data-ai` | Principal Data Storyteller & Insight Monetization Lead — DeepSignal™ |
| `product` | Head of Product Visionary & Roadmap Orchestrator — BuildFast™ |

Each template contains: `ksas` (5), `on_jd_extras` (5), `decoys` (8, pick 5), `obvious_fakes` (4, pick 3).

---

## Bot-Killer Card Pool (8 cards, 3 picked per game)

These are always LEFT-swipe (never in a real JD). They represent ATS-destroying resume formatting:
- Nested merged data table
- Profile photo / headshot
- Dual-column layout
- Unicode/symbol decorative headers
- Floating text box (outside main flow)
- Non-standard font (Papyrus)
- Special character horizontal dividers
- Header/footer with name + address

---

## Audio System (`useAudio.js`)

Custom React hook using Web Audio API. Two tracks:

**`ats_battle.mp3`** — plays during Phase 1 (Cram) and Phase 2 (Gauntlet)
- Gain: 0.6
- Tempo ramps up as gauntlet progresses (playbackRate 1.0 → 1.6 over 21 cards)
- On wrong swipe: **vinyl scratch-to-silence** effect
  - Phase 1 (0–500ms): rapid playbackRate oscillation simulating record scratch
  - Phase 2 (500–900ms): slow grind down (0.25 → 0.15 → 0.08)
  - Gain: linear ramp to 0 over 900ms
  - Low-pass filter: closes to 200Hz over 500ms
  - Track pauses and resets after 950ms

**`interview_vibe.mp3`** — plays during Phase 4 (Boss)
- Gain: 0.5
- Low-pass filter frequency tied to Vibe Meter: `400 + (vibe/100) * 19600`
- As vibe drops, music gets increasingly muffled/distorted

---

## Claude API Integration (`llmApi.js`)

**API:** Anthropic Messages API (`https://api.anthropic.com/v1/messages`)
**Model:** `claude-haiku-4-5-20251001`
**Key:** `VITE_ANTHROPIC_API_KEY` (set in `.env` file — not committed to repo)
**Max tokens:** 256 per call

Four functions, each with a static fallback if API key is missing or call fails:

| Function | What it generates | Fallback |
|---|---|---|
| `generateJobTitle()` | Over-inflated corporate job title | Static `JOB_DESCRIPTION.title` |
| `generateRejectionMessage(trigger)` | Corporate rejection email sentence | Pool from `REJECTION_MESSAGES` |
| `generateBossGibberish()` | Corporate buzzword gibberish for boss | `null` → uses static boss questions |
| `generateLinkedInStatus(outcome)` | Satirical LinkedIn post | Pool from `LINKEDIN_STATUSES` |

> **Note:** As of current build, the static content in `gameContent.js` is what's actively used. The LLM functions are wired up and working but not all are called in the current phase flow. They're ready to plug in for dynamic JD generation, dynamic boss dialogue, etc.

---

## Visual Design

- **Background:** `#0b0d0f` (near-black)
- **Primary font:** IBM Plex Mono (monospace throughout)
- **Color palette:**
  - Green glow: `#00ff41` (correct, KSAs, success)
  - Teal: `#00d9ff` (info, phase labels)
  - Lime: `#aaff00` (warnings, wait phase)
  - Pink: `#ff6b9d` (wrong, reject, danger)
- **CRT effects:** scanline sweep overlay, radial gradient ambient lighting
- **Cards:** "iridescent" style with subtle border glow
- **Glitch effect** on the BYPASS title (CSS animation)

---

## Running the Project

```bash
# Install dependencies
npm install

# Dev server (localhost:5173)
npm run dev

# Production build
npm run build
```

**To enable Claude API (optional):**
Create `.env` in project root:
```
VITE_ANTHROPIC_API_KEY=sk-ant-...
```

---

## Known State / What Was Last Being Worked On

- Core 4-phase game loop: **complete and working**
- All 8 JD templates: **complete**
- Gauntlet card logic (21 cards, correct/fail): **complete**
- Boss fight (7 questions, vibe meter, pixel sprite): **complete**
- Audio system with scratch effect and vibe filter: **complete**
- Result screen with LinkedIn share: **complete**
- Claude API integration: **wired up, fallbacks in place, ready to expand**

**Potential next directions to continue:**
- Swap in live Claude API calls for dynamic JD generation (replace static `generateRandomJD()`)
- Add dynamic boss gibberish via `generateBossGibberish()` 
- Add more JD templates
- Mobile swipe polish
- Leaderboard / score tracking
- Deploy to web (Vercel/Netlify — it's a static Vite build, zero config needed)
- Add more phases or difficulty modes
- Sound effects for card swipes

---

*Project location: `C:\Users\mjhin\OneDrive\Desktop\BYPASS`*
*To open: double-click `BYPASS Claude.bat` on Desktop, then `npm run dev`*
