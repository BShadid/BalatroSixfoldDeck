# Sixfold Deck

A [Balatro](https://www.playbalatro.com/) mod that adds the **Sixfold Deck**: a standard 52-card deck that lets you play and discard **up to 6 cards** at once, with nine new 6-card poker hands to chase.

<p align="center"><img src="docs/deck_back.png" alt="Sixfold Deck card back (placeholder art)" width="142"></p>

> **AI disclosure:** this mod was built with AI assistance. The code, and the current card back and planet card art, were created with an AI assistant. The art is a **placeholder** and will be replaced with commissioned, human-made pixel art before the first release. [Details below.](#ai-assistance)

**Status: in development.** There's no release yet. The first release will come out once all the placeholder art has been replaced with human-made art.

## The deck

> Play and discard up to **6** cards.
> Each **6-card hand** played gives **X0.1** Mult to 6-card hands and **$2** at end of round.
> **−1** hand every round.

- **Growing X-Mult:** every new 6-card hand you play permanently adds X0.1 Mult to 6-card hands for the rest of the run. A badge above your draw pile shows the current value.
- **Cash-out bonus:** each new 6-card hand played during a round pays $2 when you cash out, shown as its own line on the cash-out screen.
- **Stricter Straight Flush:** in Sixfold runs, a Straight Flush must be made from the same five cards. With six cards, vanilla would otherwise count any hand that holds a straight *and* a separate flush.

## New poker hands

Ranked among the vanilla hands, weakest to strongest:

| Hand | Made of | Base | Slots in above |
|---|---|---|---|
| Three Pair | 3 pairs of different ranks | 35 × 4 | Flush |
| Long Straight | 6 cards in a row | 50 × 5 | Full House |
| Big Flush | 6 cards of one suit | 55 × 5 | Long Straight |
| Double Trips | 2 three-of-a-kinds of different ranks | 70 × 7 | Four of a Kind |
| Mansion | Four of a Kind + a Pair | 80 × 8 | Double Trips |
| Long Straight Flush | 6 in a row, one suit | 120 × 10 | Straight Flush |
| *Six of a Kind* | 6 of one rank | 180 × 18 | Flush Five |
| *Flush Mansion* | Mansion, all one suit | 200 × 20 | Six of a Kind |
| *Flush Six* | 6 of one rank and suit | 220 × 22 | Flush Mansion |

Hands in *italics* are secret: they stay hidden until played, like Five of a Kind, and need duplicated cards. Shortcut allows gaps in the 6-card straights; Four Fingers does not shorten the 6-card hands.

The new hands and their planets only appear in Sixfold runs. Other decks play exactly as vanilla.

## Planet cards

Each new hand has its own planet: moons for the regular hands, dwarf planets for the secret ones.

![The nine new planet cards (placeholder art)](docs/planets.png)

*Placeholder art, made with AI-assisted code. It will be replaced with commissioned, human-made pixel art before the first release.*

Io (Three Pair) · Europa (Long Straight) · Ganymede (Big Flush) · Callisto (Double Trips) · Titan (Mansion) · Triton (Long Straight Flush) · Haumea (Six of a Kind) · Makemake (Flush Mansion) · Sedna (Flush Six)

## Joker changes (Sixfold runs only)

| Joker | Change |
|---|---|
| Superposition | A Long Straight with an Ace creates **2** Tarot cards |
| Seance | A Long Straight Flush creates **2** Spectral cards (with a little ceremony) |
| Runner | A Long Straight gains **+30** Chips |
| Spare Trousers | Three Pair gains **+4** Mult |
| Faceless Joker | Discarding **6** face cards at once earns **$12** |
| To Do List | Pays **double** when the target is a 6-card hand |

Each changed joker shows an extra tooltip explaining its change during Sixfold runs.

## Installation

There's no release yet (see **Status** above). Once there is:

1. Install [Steamodded](https://github.com/Steamodded/smods) (and Lovely, which it needs).
2. Download `SixfoldDeck.zip` from the [latest release](https://github.com/BShadid/BalatroSixfoldDeck/releases/latest).
3. Unzip it into your Mods folder, so you end up with `Mods/SixfoldDeck/`:
   - Windows: `%AppData%/Balatro/Mods`
   - macOS: `~/Library/Application Support/Balatro/Mods`
4. Start Balatro and pick the Sixfold Deck.

To try the in-development version now, with placeholder art, use **Code → Download ZIP** on this page. Unzip it, rename the folder to `SixfoldDeck`, and put it in your Mods folder as above.

### Requirements

- Steamodded **26.1002.0** (tested). Older versions back to **1.0.0~BETA-0509c** are also supported.
- Lovely **0.9.0** or newer (required by current Steamodded)
- The latest Steam version of Balatro

## Development

The mod is a single `main.lua` plus assets:

| Path | Contents |
|---|---|
| `main.lua` | Deck, hands, planets, joker changes, UI |
| `localization/en-us.lua` | Joker tooltip text |
| `assets/1x`, `assets/2x` | Card back and planet art (normal and double resolution) |
| `assets/sounds` | Seance sound effects |
| `art_src/` | Scripts that generate the art (Python 3 with Pillow and NumPy) |

To regenerate art, run a script with an output folder, then copy the results into `assets/`:

```
python art_src/make_planets.py out    # planets_1x.png, planets_2x.png
python art_src/make_back.py out       # back_1x.png, back_2x.png
```

### Releasing

1. Update `version` in `SixfoldDeck.json` and add a matching section to `CHANGELOG.md`.
2. Commit, then tag and push: `git tag v1.0.0 && git push origin v1.0.0`.
3. The release workflow checks the tag matches the mod's version, builds `SixfoldDeck.zip`, and publishes a GitHub release with that version's changelog notes.

## AI assistance

This mod was developed with the help of an AI assistant (Anthropic's Claude). In the current build:

- **Code:** the Lua code in `main.lua` and `localization/`, and the release workflow, were written with AI assistance. The deck's design, balance decisions and play-testing are by TCM.
- **Card back and planet card art:** created with AI-assisted code. The Python scripts in `art_src/` were written with the AI assistant and draw each image pixel by pixel. No image-generation models were used, but the art should still be considered AI-assisted. **This art is a placeholder** while I find an artist to commission human-made pixel art. All of it will be replaced before the first release.
- **Seance sound effects:** simple tones synthesised by AI-assisted code, also placeholders.

Future art credits will be listed here.

## License

[MIT](LICENSE). The art and sounds in this repository were generated by the scripts described above (see [AI assistance](#ai-assistance)) and are covered by the same license. Balatro is © LocalThunk and is not included.
