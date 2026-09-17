/// A per-device guest identity for multiplayer: no accounts, just a stable
/// random id (so a reconnect can be matched back to the seat it left) plus a
/// remembered display name. Reuses the same web/native platform split and
/// UUID generator the telemetry module already has, rather than inventing a
/// second copy of either.
///
/// Persisted via `localStorage` on web. On native (no `dart:io` `localStorage`
/// wired up here yet) the id is memoized for the life of the app but not
/// written to disk, so it is stable for a session — enough for the reconnect
/// grace period — but regenerates on the next launch. Fine for the guest-only
/// MVP; a real prefs store is a follow-up if native ships.
library;

import '../game/sfx.dart' show Character, kSelectableCharacters;
import '../telemetry/src/platform_web.dart'
    if (dart.library.io) '../telemetry/src/platform_stub.dart' as platform;
import '../telemetry/telemetry.dart' show newUuid;

const _kGuestIdKey = 'ts_mp_guest_id';
const _kNameKey = 'ts_mp_guest_name';
const _kCharacterKey = 'ts_mp_guest_character';

class GuestIdentity {
  GuestIdentity._(this.guestId, this.name, this.character);

  final String guestId;
  String name;
  Character character;

  static GuestIdentity? _cached;

  /// Loads (or creates) this device's guest identity. Safe to call repeatedly
  /// — later calls return the same instance.
  factory GuestIdentity.load() {
    final cached = _cached;
    if (cached != null) return cached;

    var id = platform.localStorageGet(_kGuestIdKey);
    if (id == null || id.isEmpty) {
      id = newUuid();
      platform.localStorageSet(_kGuestIdKey, id);
    }
    final name = platform.localStorageGet(_kNameKey) ?? '';
    final character = kSelectableCharacters.firstWhere(
      (c) => c.name == platform.localStorageGet(_kCharacterKey),
      orElse: () => Character.eric,
    );
    final identity = GuestIdentity._(id, name, character);
    _cached = identity;
    return identity;
  }

  void saveName(String value) {
    name = value;
    platform.localStorageSet(_kNameKey, value);
  }

  void saveCharacter(Character value) {
    character = value;
    platform.localStorageSet(_kCharacterKey, value.name);
  }
}
