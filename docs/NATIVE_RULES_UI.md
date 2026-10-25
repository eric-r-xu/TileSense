# Native rules reader

Status: first pass implemented on 2026-10-25.

## What is available

All six variants have a native, scrollable English summary covering setup,
calls, winning requirements, scoring, payments and game length. Sanma includes
kita; Sichuan includes the void suit and continued play after a win.

- On the welcome screen, each variant has **Read rules** alongside its existing
  external reference button. Reading another variant does not select it for play.
- The offline game toolbar, phone menu, Learn to Play and hand builder open the
  reader for their current variant.
- Search matches section titles and text, ignoring case and surrounding spaces.
  The clear button restores the list. Text can be selected and copied.
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

`flutter_client/lib/ui/rules_content.dart` holds typed sections with stable IDs,
using the six `docs/*_RULES.md` summaries as the editorial source. Keep both in
step when rules change. Configurable minimum defaults and choices come from
`mahjong_core`, and table-specific values are passed by the caller.

`flutter_client/lib/ui/rules_reader.dart` implements the dialog, search, scrolling
and external reference action. It uses existing Flutter widgets and the existing
`url_launcher` dependency. No server, protocol or dependency changes are needed.

Controls, search hints and notices use the app's ARB localization workflow in
English, Japanese, Simplified Chinese and Traditional Chinese. The rule text is
English in this first pass, and the notice and search hint say so in each language.

## Limits and follow-up work

These are quick summaries of TileSense's implemented rules, not complete scoring
catalogues. The external references and repository rule pages provide additional
detail. Full yaku/faan/tai/fan lists, MCR exclusions, tile illustrations and reviewed
translations remain follow-up work. The summaries retain source attribution.

PDFs continue to open externally. Displaying a PDF beside the native text within
the app would require a separate viewer decision. No viewer is bundled here.

## Verification

`flutter_client/test/rules_reader_test.dart` covers all variants, configured
minimums, search and clearing, scrolling, reference destinations and failure,
small-screen layouts with larger text in all UI languages, and welcome/game
navigation. `flutter_client/e2e/tests/rules.spec.ts` exercises the reader in the
release web app at desktop and landscape-phone sizes, including search and Back.
