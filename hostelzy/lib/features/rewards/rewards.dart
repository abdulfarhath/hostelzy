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
  String get referralCode => 'RAHUL-$referralReward';

  void becomeMember(String hostelName) {
    if (isMember) return;
    member = true;
    memberSince = 'Since ${dayMon(appToday.add(const Duration(days: 1)))} · first stay via Hostelzy at $hostelName';
  }

  /// Move-in for a booked or confirmed hold: the Member reward comes off the
  /// first month and is credited to the owner (no cash from Hostelzy).
  void moveIn(Hold hold) {
    final h = hostelById(hold.hid);
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
