# TileSense mobile submission kit

The application ID and Apple bundle ID are both `com.ericrxu.tilesense`.
Use the version and build from `../pubspec.yaml`. Check each store's upload
history before reusing a build number. These builds use the native defaults:
local single-player bots and guide, bundled daily puzzles and optional private
multiplayer over `wss://app.ericrxu.com/tilesense/mp/`. Remote Mortal analysis
is an optional build setting and is disabled in this configuration.

## English listing

| Field | Copy |
| --- | --- |
| Name | TileSense |
| Google Play category | Game · Board |
| Google Play short description | Practice mahjong with a live discard guide or play a private game with friends. |
| Apple primary category | Games · Board |
| Apple subtitle | Mahjong practice and strategy |
| Apple keywords | riichi,sanma,shanten,ukeire,tiles,discard,puzzle,hong kong,taiwanese,sichuan,fuzhou,mcr |
| Public support email | support@ericrxu.com |
| Support URL | https://app.ericrxu.com/static/tilesense-mobile/support.html |
| Mobile privacy policy URL | https://app.ericrxu.com/static/tilesense-mobile/privacy.html |

### Full description

Which tile would you discard? Play a hand of mahjong and use TileSense's live guide to see how each choice affects your path to a win. Compare the tiles that improve your hand, what your hand could score and which discards are risky.

Play against bots at your own pace, answer a daily puzzle or set up a specific hand in the scenario builder. Beginners can learn the tiles and calls through guided practice. When you want to play with friends, create a private room and share its code. Bots can fill the empty seats.

Choose from Japanese riichi, three-player sanma, Hong Kong, Taiwanese, Mahjong Competition Rules, Sichuan and Fuzhou. Single-player practice works offline. Online rooms require an internet connection.

### Release notes

Play seven mahjong variants, study discards with a live guide, solve daily puzzles and invite friends to a private table.

### Reviewer notes

No login or purchase is required. Hold the phone in landscape. Start a single-player game to inspect the guide and tap a tile to discard. For multiplayer, choose Play Online, create a room and choose Start Game. Bots fill the empty seats automatically. A second device can join by entering the room code.

## Google Play

1. Build from `flutter_client` with `flutter build appbundle --release`. Use the AAB in `build/app/outputs/bundle/release/`. Compare the upload certificate with Play Console's **App integrity** page if the app already exists. Keep the upload key and passwords private.
2. Use the English copy above and the files under `google-play/` for the main listing. Select the countries, price, target audience and age questionnaire answers for your account. The game scores hands with points, has no cash wagers or prizes, and contains no ads or in-app purchases.
3. Publish the files in `store/pages/` at the two HTTPS URLs above, on the same static host as the rules PDFs. This keeps both pages accessible across app deployments and rollbacks. Open both URLs in a signed-out browser and check the page titles. The site's single-page fallback can return HTTP 200 for a missing file. Confirm the public contact and the service's retention settings before submission.
4. Complete Data safety using the disclosure worksheet below. Choose the applicable app access and content ratings answers, then upload to an internal or closed track and review Play's pre-launch report. For personal accounts created after November 13, 2023, Google currently requires 12 testers opted in continuously for 14 days before applying for production access. [Google testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465)
5. Publish the corresponding GPL source for the exact binary and keep its version identifiable. Confirm the distribution rights for the bundled voices, artwork and third-party material. Submit the tested build for review when the account's production requirements are satisfied.

## Privacy disclosure worksheet

| Native feature | Data and purpose |
| --- | --- |
| Local play and quiz | Run on-device. The native client disables the web analytics transport. |
| Private rooms | The service receives a random guest ID, nickname, character, room code and moves for game operation and reconnection. Other players see the nickname, character and public game state. Online play is optional. |
| Server-side multiplayer analytics | When ingest is configured, the server records guest and session IDs, match settings and participation, decisions and results. Online records are linked by guest ID. The default retention sweep is 90 days. Verify the active sweep, proxy logs and backup policy with the service operator. |
| Advertising and tracking | The client has no advertising SDK, advertising identifier or cross-app tracking. Connections to the room service use TLS. External links open in the user's browser. |

For Play, assess **Personal info → User IDs** (including nicknames), **App activity → App interactions** and **Other user-generated content** as applicable to gameplay. Select app functionality and analytics where used. Declare ephemeral processing separately for information handled only during the live request. Review user-directed visibility to room members and the hosting provider against Google's sharing definitions. Check how network addresses are logged and used before answering any device ID or approximate location questions. [Google Data safety definitions](https://support.google.com/googleplay/android-developer/answer/10787469)

## Apple App Store

1. Select the enrolled Apple Developer team for Runner in `ios/Runner.xcworkspace`. Register the bundle ID and create its App Store Connect record. Build with `flutter build ipa --release`, then validate and upload through Organizer or Transporter. An archive made with `--no-codesign` is a local build check. Rebuild with signing before uploading.
2. Use the English listing, support and privacy URLs, and screenshots under `app-store/`. Provide the review contact, copyright holder, age rating, pricing and regional availability. Review export compliance and distribution terms, including the project's GPLv3 upstream code, under the account holder's agreements.
3. The Runner privacy manifest declares **User ID**, **Gameplay Content** and **Product Interaction** for app functionality and analytics, linked through online guest IDs. It declares tracking off. Generate the archive privacy report in Xcode and reconcile App Privacy answers with the deployed services and included SDKs. [Apple privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
4. Test the signed build through TestFlight, then select that build for App Review. Apple specifies the accepted sizes for iPhone and 13-inch iPad captures. [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
