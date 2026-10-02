part of '../../state.dart';

// F17 links
mixin _LinksData {

  /// The last link the app tried to open (WhatsApp, phone, maps, UPI).
  Uri? lastLink;

  /// Holds that ran out (shown as "Hold expired").
  final Set<String> expiredHolds = {};

  /// A resident invite code from a link (app/j/), kept until the resident
  /// signs up with it.
  String? pendingInvite;

  /// C: the code the resident types on the gate, and the owner's code.
  String inviteDraft = '';
  bool joining = false;
  String? inviteCode;
}

extension LinksActions on AppState {

  /// Deep link app/r/?c=HZ-…: opens that enquiry for its owner, or the
  /// tenant's holds. Only enquiries this account can see.
  void openEnquiryLink(String code) {
    final c = code.trim().toUpperCase();
    if (!RegExp(r'^HZ-[0-9]{3,8}$').hasMatch(c)) return toastMsg('That link has no HZ code.');
    final e = enquiries.where((x) => x.ref == c).firstOrNull;
    if (!signedIn || e == null) return toastMsg('$c isn’t in this account. Sign in with the account that sent or got it.');
    update(() {
      hist = [];
      if (role == 'owner') {
        screen = 'oToday';
        enqRef = c;
        sheet = 'enq';
      } else {
        screen = 'holds';
        sheet = null;
      }
    });
  }

  /// C: the owner's invite code from the server (sample data: the sample code).
  Future<void> loadInvite({bool renew = false}) async {
    try {
      final c = await data.inviteCode(ownHid, renew: renew);
      update(() => inviteCode = c ?? (AppState.samples ? 'ANJ-7Q2' : null));
      if (renew && c != null) toastMsg('New code $c. The old link and poster stop working.');
    } catch (e) {
      debugPrint('invite: $e');
      toastMsg('Couldn’t get your invite code. Check your internet.');
    }
  }

  /// C: a signed-in resident asks to join with a code; the owner approves.
  Future<void> joinInvite() async {
    final c = (inviteDraft.trim().isEmpty ? pendingInvite ?? '' : inviteDraft).trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{2,6}-[A-Z0-9]{2,8}$').hasMatch(c)) return toastMsg('Enter the invite code from your owner, like ANJ-7Q2.');
    if (account == null) return toastMsg('Sign in with Google to join with a code.');
    if (joining) return;
    update(() => joining = true);
    try {
      final h = await data.joinWithInvite(c, name: meName, phone: phone);
      update(() {
        joining = false;
        pendingInvite = null;
        inviteDraft = '';
      });
      toastMsg('Asked to join $h. Your owner approves it, then your stay opens here.');
    } on UnsupportedError {
      update(() => joining = false);
      toastMsg('Invites work in the real Hostelzy app. This is sample data.');
    } catch (e) {
      update(() => joining = false);
      final m = '$e';
      toastMsg(m.contains('valid any more')
          ? 'That code isn’t valid any more. Ask your owner for the new one.'
          : m.contains('already asked')
          ? 'You already asked. Your owner will approve it.'
          : m.contains('name and 10-digit')
          ? 'Add your name and 10-digit phone in Settings first.'
          : 'Couldn’t send it. Check your internet and try again.');
    }
  }

  /// Deep link app/j/?c=…: keeps the invite code for the resident sign-up.
  void openInviteLink(String code) {
    final c = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{2,6}-[A-Z0-9]{2,8}$').hasMatch(c)) return toastMsg('That link has no invite code.');
    update(() => pendingInvite = c);
    toastMsg('Invite $c saved. Sign in and pick “I live in a Hostelzy PG”.');
  }

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
