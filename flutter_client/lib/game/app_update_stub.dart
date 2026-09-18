/// Native builds update through the stores; there is nothing to offer.
bool get updateSupported => false;

Future<String?> fetchServerBuildId() async => null;

Future<void> reloadWithFreshFiles() async {}
