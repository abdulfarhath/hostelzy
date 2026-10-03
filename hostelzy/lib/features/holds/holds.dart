part of '../../state.dart';

// F18 holds
mixin _HoldsData {

  /// F21 W4: holds released with Undo still showing; released for real after [undoSecs].
  final Set<String> releasing = {};

  /// What each bed was before a hold (free, or free soon), so releasing puts
  /// it back exactly (D10).
  final Map<String, String> _bedBefore = {};

  /// Walk-in holds the owner placed, and when they end (F8): ms.
  final Map<String, int> walkIns = {};

  /// The last text handed to the phone's share sheet (tests read it).
  String? lastShare;

  /// F14: the resident QR poster as an A4 PDF, shared through the share sheet
  /// (print it, or send it to a print shop on WhatsApp).
  int? lastPosterBytes;
}

extension HoldsActions on AppState {

  /// "from ₹X": the cheapest rent on the rate card now (D8), not the
  /// number frozen when the hostel was listed.
  int fromOf(Hostel h) {
    final rs = rooms[h.id];
    if (rs == null || rs.isEmpty) return h.from;
    return rs.map((r) => r.rent).reduce((a, b) => a < b ? a : b);
  }
  int get activeHolds => holds.where((h) => const ['waiting', 'confirmed', 'held', 'paying'].contains(h.status)).length;

  void _freeBed(String hid, String id) {
    final b = hostels.any((x) => x.id == hid) ? findBed(hid, id).b : null;
    if (b == null) return;
    b
      ..state = _bedBefore.remove('$hid|$id') ?? 'free'
      ..mine = false;
  }

  /// Release a hold: the bed goes back to how it was, the hold record says
  /// Released, and any unconfirmed advance for it is dropped (D10, F9).
  void releaseHold(Hold h, {String? msg}) {
    // S1: a server hold is released on the server (the bed frees itself
    // there); the tenant's release also cancels its unconfirmed advance.
    if (onServer && !RegExp(r'^h\d+$').hasMatch(h.id)) {
      _write(() => data.releaseHold(h.id, cancelPay: role == 'tenant')).then((ok) {
        if (!ok) return;
        update(() => _freeBed(h.hid, h.bed));
        if (msg != null) toastMsg(msg);
      });
      return;
    }
    update(() {
      _freeBed(h.hid, h.bed);
      holds = holds.map((x) => x.id == h.id ? x.withStatus('released') : x).toList();
      payments = payments.where((x) => x.holdId != h.id || x.status == 'paid').toList();
    });
    if (msg != null) toastMsg(msg);
  }

  /// F21 W4: the tenant's Release, with 5 seconds to Undo before it happens.
  void releaseWithUndo(Hold h) {
    update(() {
      releasing.add(h.id);
      if (screen == 'hold') {
        final hs = List.of(hist);
        screen = hs.isNotEmpty ? hs.removeLast() : 'holds';
        hist = hs;
      }
    });
    final t = Timer(undoSecs, () {
      if (releasing.remove(h.id)) releaseHold(h);
    });
    toastWithUndo('Hold on bed ${h.bed} released', () {
      t.cancel();
      update(() => releasing.remove(h.id));
    });
  }

  /// Owner releases a held bed: the tenant's hold record follows (F9).
  void ownerReleaseBed(String hid, Bed b) {
    final h = holds.where((x) => x.hid == hid && x.bed == b.id && x.status != 'released').firstOrNull;
    if (h != null) return releaseHold(h);
    final k = '$hid|${b.id}';
    final was = walkIns.remove(k);
    final before = _bedBefore[k] ?? 'free';
    update(() {
      _freeBed(hid, b.id);
      b.walkInUntil = 0;
    });
    // F24 item 8: a walk-in hold on the server ends there too.
    final key = b.key;
    if (!onServer || key == null || isSeedHostel(hid)) return;
    data.releaseWalkIn(key).then((_) {}, onError: (Object e) {
      debugPrint('walk-in release: $e');
      update(() {
        b.state = 'held';
        if (was != null) {
          walkIns[k] = was;
          _bedBefore[k] = before;
        }
      });
      toastMsg('Couldn’t release it. Check your internet and try again.');
    });
  }

  /// Owner holds a bed for a walk-in for one hour; it frees itself after (F8).
  /// F24 item 8: on the server every tenant sees it held, and the server
  /// ends it after the hour.
  void holdWalkIn(String hid, Bed b) {
    final k = '$hid|${b.id}';
    final before = b.state;
    _bedBefore[k] = before;
    walkIns[k] = DateTime.now().millisecondsSinceEpoch + 3600 * 1000;
    update(() => b.state = 'held');
    final key = b.key;
    if (!onServer || key == null || isSeedHostel(hid)) return;
    data.holdWalkIn(key).then((until) {
      if (walkIns.containsKey(k)) update(() => walkIns[k] = b.walkInUntil = until.millisecondsSinceEpoch);
    }, onError: (Object e) {
      debugPrint('walk-in: $e');
      walkIns.remove(k);
      _bedBefore.remove(k);
      update(() => b.state = before);
      toastMsg('$e'.contains("isn't free") ? 'Bed ${b.id} isn’t free any more.' : 'Couldn’t hold it. Check your internet and try again.');
    });
  }

  /// F24 item 8: walk-in holds the server has for the owner's hostels (after
  /// the hostels load), so the countdown and Release work on any phone.
  void syncWalkIns() {
    final n = DateTime.now().millisecondsSinceEpoch;
    for (final hid in ownerHostels) {
      for (final r in rooms[hid] ?? const <Room>[]) {
        for (final b in r.beds) {
          final k = '$hid|${b.id}';
          if (b.walkInUntil > n && b.state == 'held') {
            walkIns[k] = b.walkInUntil;
          } else if (b.key != null && b.state != 'held') {
            walkIns.remove(k);
          }
        }
      }
    }
  }

  bool _expireWalkIns(int n) {
    final out = walkIns.entries.where((e) => e.value <= n).map((e) => e.key).toList();
    if (out.isEmpty) return false;
    update(() {
      for (final k in out) {
        walkIns.remove(k);
        final i = k.indexOf('|');
        _freeBed(k.substring(0, i), k.substring(i + 1));
      }
    });
    return true;
  }

  void copyText(String s) => Clipboard.setData(ClipboardData(text: s));

  /// Opens Android's share sheet (WhatsApp, SMS, Telegram…). Nothing is sent
  /// until the user picks an app and sends it.
  Future<void> share(String text) async {
    lastShare = text;
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      copyText(text);
      toastMsg('Sharing isn’t available here. The text is copied.');
    }
  }
  Future<void> sharePoster(String link) async {
    final bytes = await residentPoster(hostel: hostelById(ownHid).name, link: link);
    lastPosterBytes = bytes.length;
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: 'hostelzy-poster.pdf')], text: 'Hostelzy resident poster (A4)'));
    } catch (_) {
      toastMsg('Sharing isn’t available here.');
    }
  }

  /// "Find a PG on Hostelzy with my code …" (F09).
  String get referralText => 'I found my PG on Hostelzy: see the exact bed before you visit. Use my code $referralCode when you join a hostel through Hostelzy and we both get ${fmt(referralReward)} after your first month.'; 

  void setHold(String id, String status) => update(() => holds = holds.map((h) => h.id == id ? h.withStatus(status) : h).toList());
}
