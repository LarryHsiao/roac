/// Whether this launch owes its reader the welcome.
///
/// [pending] is what was written down last time: true while the welcome has
/// been shown but neither finished nor skipped, false once it has, and null
/// when nothing was ever written. Only then is the question open, and it is
/// owed only where nothing says Roäc has run here before — no
/// [lastSeenVersion] and no settings file. The answer is written back at
/// once, so a welcome quit half way is still owed next time.
Future<bool> welcomeOwed({
  required bool? pending,
  required String? lastSeenVersion,
  required bool hasSettings,
  required Future<void> Function(bool pending) writePending,
}) async {
  if (pending != null) return pending;
  final owed = lastSeenVersion == null && !hasSettings;
  await writePending(owed);
  return owed;
}
