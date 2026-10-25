# Native rules reader

Status: summaries, full scoring catalogues and translations implemented on 2026-10-25.

## What is available

All six variants have a native, scrollable summary covering setup, calls,
winning requirements, scoring, payments and game length. Sanma includes kita;
Sichuan includes the void suit and continued play after a win.

Each summary is followed by a catalogue of every pattern its scorer counts,
with its value and a one-line definition:

- **Riichi and Sanma:** every yaku with closed and open han, the yakuman, dora
  (and kita), the fu table and the limit hands. Sanma omits Sanshoku Doujun.
- **Hong Kong:** every faan feature, including flower awards and Chicken Hand.
- **Taiwanese:** every tai pattern, with which tiers replace which.
- **MCR:** all 81 fan, grouped by points, each with the fan it excludes.
- **Sichuan:** every fan, with the fan-to-hand-value table.

The summaries and catalogues are written in English, Japanese, Simplified
Chinese and Traditional Chinese, and follow the app's language.

- On the welcome screen, each variant has **Read rules** alongside its existing
  external reference button. Reading another variant does not select it for play.
- The offline game toolbar, phone menu, Learn to Play and hand builder open the
  reader for their current variant.
- Search matches section titles and text, ignoring case and surrounding spaces.
  Inside a catalogue it keeps only the matching entries, and a pattern's
  English name finds it in every language. The clear button restores the list.
  Text can be selected and copied.
- Back and the external reference button stay available while scrolling.
  Five variants link to PDFs; Sanma links to the Japanese Mahjong Wiki.
- In a game or the builder, the reader shows the configured Hong Kong or
  Taiwanese minimum. Before setup, it explains the default and available choices.
- Summaries are bundled with the app and work offline. External references
  still need access to their host. A failed launch is reported inside the reader.

The reader uses a dialog on the root navigator, outside the scaled game canvas,
so text uses the device's actual display size. It does not change the table's
rules, pause state or timers. The online table has no new entry point in this pass;
players can read a variant from the welcome screen before joining.

## Content and implementation

`flutter_client/lib/ui/rules_content.dart` holds the section model and the
catalogues' values, once for every language. MCR's names, points and exclusions
come straight from `mcrFans`. Pattern names use the score screen's translations
(`MahjongTerms.scoringName`), so the reader and the result screen always agree.
MCR now has its own name table there, which also translates MCR fan on the score
screen. Configurable minimum defaults and choices come from `mahjong_core`, and
table-specific values are passed by the caller.

The prose, catalogue notes and value wording live in one `RulesText` class per
language (`rules_text_en.dart`, `_ja`, `_zh`, `_zh_hant`). Every language must
implement every member, so a missing translation fails to compile. English is the
reference wording, using the six `docs/*_RULES.md` pages as the editorial source.
When rules change, update the doc, the catalogue values and all four texts.

`flutter_client/lib/ui/rules_reader.dart` implements the dialog, search, scrolling
and external reference action. It uses existing Flutter widgets and the existing
`url_launcher` dependency. No server, protocol or dependency changes are needed.

Controls, search hints and notices use the app's ARB localization workflow. The
notice says the translations are TileSense's own and that the external reference
(in English) is the source the rules follow.

## Limits and follow-up work

The summaries describe what TileSense implements, including its house rules and
simplifications. The catalogue notes are short definitions, not the full wording
of each source. The Japanese and Chinese texts have not yet been reviewed by
native-speaking players. Tile illustrations in the catalogue remain follow-up work.
The summaries retain source attribution.

PDFs continue to open externally. Displaying a PDF beside the native text within
the app would require a separate viewer decision. No viewer is bundled here.

## Verification

`flutter_client/test/rules_reader_test.dart` covers all variants, configured
minimums, search and clearing, scrolling, reference destinations and failure,
small-screen layouts with larger text in all UI languages, and welcome/game
navigation. It also checks that every language has the same sections, a note for
every entry and no untranslated names. It scans each scorer's source for the
pattern names it can report and fails if the catalogue misses one. `flutter_client/e2e/tests/rules.spec.ts` exercises the reader in the
release web app at desktop and landscape-phone sizes, including search and Back,
a catalogue search, and the Japanese reader.
