part of '../../state.dart';

// F13 backend
mixin _SyncData {

  String delReason = '';

  /// C: deleting (Google confirm + server) is in progress.
  bool deleting = false;

  /// B6: Realtime subscription and its debounce.
  StreamSubscription<String>? _liveSub;
  Timer? _liveWait;
}

extension SyncActions on AppState {

  /// B6: the signed-in user's live holds, enquiries, payments and complaints
  /// replace the lists. Never mixed with samples: on Supabase the lists start
  /// empty (AppState.samples is false).
  void applyLive(LiveRows l) => update(() {
    holds = l.holds;
    enquiries = l.enquiries;
    payments = l.payments;
    complaints = l.complaints;
    expiredHolds
      ..clear()
      ..addAll(l.expired);
  });

  Future<void> refreshLive() async {
    try {
      final l = await data.live(me: account?.uid);
      if (l != null) applyLive(l);
    } catch (e) {
      debugPrint('live: $e');
    }
  }

  /// Signed in on Supabase: load the live rows, then refetch whenever one of
  /// them changes (Realtime), at most once per 400 ms.
  Future<void> startLive() async {
    if (account == null) return;
    await refreshLive();
    await _liveSub?.cancel();
    _liveSub = data.changes().listen((_) {
      _liveWait?.cancel();
      _liveWait = Timer(const Duration(milliseconds: 400), refreshLive);
    });
  }

  void stopLive() {
    _liveSub?.cancel();
    _liveSub = null;
    _liveWait?.cancel();
  }

  /// Why the account can't be deleted yet, or null.
  ({String title, String body, String cta, VoidCallback go})? get deleteBlock {
    final h = holds.where((x) => const ['waiting', 'confirmed', 'held', 'paying'].contains(x.status)).firstOrNull;
    if (h != null) {
      return (title: 'You have an open hold', body: 'Your hold on bed ${h.bed} at ${hostelById(h.hid).name} is still open. Cancel it or let it end first.', cta: 'Go to my hold', go: () => update(() {
        holdId = h.id;
        hist = [...hist, screen];
        screen = 'hold';
      }));
    }
    if (role == 'owner' && (invoice.status == 'due' || invoice.status == 'missing')) {
      return (title: 'Your Hostelzy plan is unpaid', body: 'Owners: invoice ${invoice.ref} (${fmt(invoiceAmt)}) is due. Pay it or contact us, then delete.', cta: 'Open invoice', go: () => go('oInvoice'));
    }
    return null;
  }

  bool isDark(Brightness phone) => theme == 'dark' || (theme == 'system' && phone == Brightness.dark);

  /// C: delete account v2. Signed in with Google: confirm with Google, delete
  /// the server data, then the Firebase user. Either way, this phone forgets
  /// everything. Nothing is said to be deleted unless it was.
  Future<void> confirmDelete() async {
    if (deleting) return;
    if (account != null && signIn.available) {
      update(() => deleting = true);
      final fail = await signIn.reauth();
      if (fail != null) {
        update(() => deleting = false);
        return toastMsg(switch (fail) {
          SignInFail.cancelled => 'Not deleted. You closed Google.',
          SignInFail.otherAccount => 'That’s a different Google account. Pick ${account!.email}.',
          _ => 'Couldn’t check with Google. Check your internet and try again.',
        });
      }
      try {
        await data.deleteMyAccount();
        await forgetPushToken();
        await signIn.deleteUser();
      } catch (e) {
        update(() => deleting = false);
        final m = '$e';
        return toastMsg(m.contains('Owners:') ? 'Owners: ask Hostelzy to close or hand over your hostel first.' : 'Couldn’t delete it on the server. Check your internet and try again.');
      }
    }
    stopLive();
    final me = myPhone;
    update(() {
      enquiries = enquiries.where((e) => e.phone != me).toList();
      holds = [];
      saved.clear();
      member = false;
      monthsOnTime = 0;
      rewardUsed = false;
      phone = '';
      otp = '';
      signedIn = false;
      account = null;
      delReason = '';
      deleting = false;
      screen = 'delDone';
      hist = [];
      sheet = null;
    });
    store.clear();
  }

  /// F18: logging out forgets everything this phone kept about the user.
  void logOut() {
    forgetPushToken().then((_) => signIn.signOut());
    stopLive();
    final me = phone;
    update(() {
      for (final h in holds.where((h) => h.status != 'released')) {
        if (hostels.any((x) => x.id == h.hid) && findBed(h.hid, h.bed).b?.mine == true) _freeBed(h.hid, h.bed);
      }
      holds = [];
      saved.clear();
      if (me.isNotEmpty) enquiries = enquiries.where((e) => e.phone != me).toList();
      account = null;
      myName = '';
      role = 'tenant';
      screen = 'welcome';
      hist = [];
      phone = '';
      otp = '';
      signedIn = false;
      sheet = null;
    });
    store.clear();
    _saved = jsonEncode(snapshot());
  }
}
