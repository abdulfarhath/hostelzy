part of '../../state.dart';

// F09 rewards
mixin _RewardsData {

  /// Member after a first stay through Hostelzy.
  bool member = false;
  String memberSince = '';

  /// From the stay record (sample until the backend keeps it): months stayed
  /// in Hostelzy hostels, months the rent was late, owner complaints.
  int monthsOnTime = 0, lateRentMonths = 0, ownerComplaints = 0;

  /// The ₹100 Member reward has been used at a move-in.
  bool rewardUsed = false;

  /// ₹100 credits for owners' next Hostelzy invoices (F10).
  final List<({String hid, String what, int amt})> ownerCredits = [];
  int friendsJoined = 1;

  /// Hold request whose Trusted tenant badge is open.
  String? trustedReq;

  /// S6: on Supabase, the user's code from the server, whether they used a
  /// friend's code, their balance (₹), and the code being typed.
  String? serverRefCode;
  bool referred = false, _codeAsked = false;
  int rewardBalance = 0;
  String friendCode = '';
}

extension RewardsActions on AppState {

  /// none | member | trusted. Trusted tenant is earned, not given: 6 months in
  /// Hostelzy hostels, rent always on time, no complaints from the owner (F09).
  String get level => !member
      ? 'none'
      : monthsOnTime >= trustedMonths && lateRentMonths == 0 && ownerComplaints == 0
      ? 'trusted'
      : 'member';

  bool get isMember => level != 'none';
  int get holdSecs => isMember ? memberHoldSecs : freeHoldSecs;
  String get referralCode => serverRefCode ?? (onServer ? '…' : 'RAHUL-$referralReward');

  /// S6: makes or fetches this user's code on the server, once.
  Future<void> loadReferralCode() async {
    if (!onServer || serverRefCode != null || _codeAsked) return;
    _codeAsked = true;
    try {
      final c = await data.referralCode();
      update(() => serverRefCode = c);
    } catch (e) {
      _codeAsked = false;
      toastMsg('$e'.contains('add your name') ? 'Add your name in Settings first, then your code appears here.' : 'Couldn’t get your code. Check your internet and try again.');
    }
  }

  /// S6: a new tenant enters a friend's code before their first stay.
  Future<void> useFriendCode() async {
    final c = friendCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3,5}-[A-Z0-9]{4}$').hasMatch(c)) return toastMsg('Enter your friend’s code, like ASHA-4K7Q.');
    try {
      final who = await data.useReferralCode(c);
      update(() {
        referred = true;
        friendCode = '';
      });
      toastMsg('Code saved. You and $who each get ${fmt(referralReward)} after your first month at a Hostelzy hostel.');
    } catch (e) {
      final m = '$e';
      toastMsg(m.contains('isn\'t valid') || m.contains('isn’t valid')
          ? 'That code isn’t valid. Check it with your friend.'
          : m.contains('own code')
          ? 'That’s your own code. Share it with a friend instead.'
          : m.contains('already used')
          ? 'You already used a friend’s code.'
          : m.contains('first stay')
          ? 'Codes are for your first stay through Hostelzy.'
          : 'Couldn’t save it. Check your internet and try again.');
    }
  }

  void becomeMember(String hostelName) {
    if (isMember) return;
    member = true;
    memberSince = 'Since ${dayMon(appToday.add(const Duration(days: 1)))} · first stay via Hostelzy at $hostelName';
  }

  /// Move-in for a booked or confirmed hold: the Member reward comes off the
  /// first month and is credited to the owner (no cash from Hostelzy).
  void moveIn(Hold hold) {
    final h = hostelById(hold.hid);
    // S6: on Supabase the owner confirms the stay; the server then applies the
    // reward and credits the owner. Nothing is claimed here first.
    if (onServer) {
      return toastMsg(isMember && !rewardUsed ? 'Pay what’s shown. ${h.owner} gives the ${fmt(memberReward)} off once they add you, and Hostelzy credits them.' : '${h.owner} adds you as a resident. Then My stay opens here.');
    }
    final useReward = isMember && !rewardUsed;
    update(() {
      if (useReward) {
        rewardUsed = true;
        ownerCredits.add((hid: hold.hid, what: 'Member reward · ${hold.bed}', amt: memberReward));
      }
      becomeMember(h.name);
      role = 'resident';
      screen = 'rHome';
      hist = [];
    });
    toastMsg(useReward ? 'Welcome home. ${fmt(memberReward)} Member reward used.' : 'Welcome home. This is your stay now.');
  }
}
