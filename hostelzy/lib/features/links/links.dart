part of '../../state.dart';

// F17 links
mixin _LinksData {

  /// The last link the app tried to open (WhatsApp, phone, maps, UPI).
  Uri? lastLink;

  /// Holds that ran out (shown as "Hold expired").
  final Set<String> expiredHolds = {};
}

extension LinksActions on AppState {

  /// Opens another app. Nothing is sent from Hostelzy itself.
  Future<void> openLink(Uri u, String app) async {
    lastLink = u;
    try {
      if (await launchUrl(u, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    toastMsg('Couldn’t open $app on this device.');
  }

  /// WhatsApp with the message filled in; [phone] empty lets the user pick a chat.
  void whatsapp(String phone, String text) {
    if (_fakeContact(phone)) return;
    openLink(Uri.parse('https://wa.me/${phone.isEmpty ? '' : '91$phone'}?text=${Uri.encodeComponent(text)}'), 'WhatsApp');
  }

  void call(String phone) {
    if (phone.isEmpty) return toastMsg('No number to call yet.');
    if (_fakeContact(phone)) return;
    openLink(Uri.parse('tel:+91$phone'), 'the phone app');
  }

  /// F18: the Play Store build never opens WhatsApp or the dialler for a
  /// sample number; it says so instead.
  bool _fakeContact(String phone) {
    if (AppState.samples || !AppState.isSampleNumber(phone)) return false;
    toastMsg('This is a sample listing, so there’s no real number yet.');
    return true;
  }
  void directions(Hostel h) => openLink(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${posOf(h).$1},${posOf(h).$2}'), 'Maps');

  /// The tenant's last ended hold: "Did you join?" asks about it (F07).
  Hold? get endedHold => holds.where((h) => h.status == 'released').lastOrNull;

  bool _expireHolds(int n) {
    final out = holds.where((h) => const ['waiting', 'confirmed', 'held'].contains(h.status) && holdSecs - (n - h.start) / 1000 <= 0).toList();
    if (out.isEmpty) return false;
    now = n;
    update(() {
      for (final h in out) {
        if (findBed(h.hid, h.bed).b?.mine == true) _freeBed(h.hid, h.bed);
        expiredHolds.add(h.id);
      }
      holds = holds.map((h) => out.contains(h) ? h.withStatus('released') : h).toList();
    });
    return true;
  }

  /// Test hook: run the expiry check at time [n].
  @visibleForTesting
  bool expireHoldsAt(int n) => _expireHolds(n);
}
