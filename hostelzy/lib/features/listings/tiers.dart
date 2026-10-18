part of '../../state.dart';

// F26 #21: two listing tiers. UNVERIFIED hostels (status 'listed' on the
// server) show a photo, name, area and an expected rent range; no beds,
// holds, layouts or owner contact. Tenants can ask to hear when one is
// verified, ask Hostelzy on WhatsApp, and owners can claim theirs.
mixin _TiersData {
  /// Listed hostels this user asked "Tell me when verified" about.
  final Set<String> waitlist = {};

  /// Per area from `area_counts()`; null: counted from the hostels on this phone.
  Map<String, ({int verified, int listed})>? areaCountsSrv;

  /// The claim sheet (H44): which hostel, and the owner's name and phone.
  String? claimHid;
  String claimName = '', claimPhone = '';

  /// Hostels this user already sent a claim for (this session).
  final Set<String> claimed = {};
}

/// The price band a rent falls in, ₹2,000 wide: ₹5,000–7,000, ₹7,000–9,000…
/// (F26 #21's Price ↑ interleave; F28 Part 1 puts every verified hostel
/// first instead, so Explore no longer compares bands.)
int priceBand(int rent) => rent <= 1000 ? 0 : (rent - 1000) ~/ 2000;

/// Explore's tier step: verified before listed. [byPrice]: compare the
/// price bands first (the F26 #21 rule); false (F28 Part 1): only the tier.
int tierCompare(Hostel a, Hostel b, int Function(Hostel) price, {bool byPrice = true}) {
  if (byPrice) {
    final d = priceBand(price(a)).compareTo(priceBand(price(b)));
    if (d != 0) return d;
  }
  return (a.listed ? 1 : 0).compareTo(b.listed ? 1 : 0);
}

/// F28 Part 4 (28-90): a listed hostel's rent is shown only while a person's
/// confirmation is within 60 days; after that it is "Rent on request".
const rentFreshDays = 60;
bool rentFresh(Hostel h, {DateTime? now}) {
  if (!h.listed) return true;
  final at = h.rentConfirmedAt;
  return at != null && (now ?? DateTime.now()).difference(at).inDays < rentFreshDays;
}

/// What the card and the page say for the rent: the range, or "Rent on request".
String rentLine(Hostel h, {DateTime? now}) => rentFresh(h, now: now) ? rentRange(h) : 'Rent on request';

/// F28 Part 4: priced listed hostels before "Rent on request" ones.
int rentFreshCompare(Hostel a, Hostel b, {DateTime? now}) => (rentFresh(a, now: now) ? 0 : 1).compareTo(rentFresh(b, now: now) ? 0 : 1);

/// "Around ₹7,000–9,000".
String rentRange(Hostel h) => h.rentMax > h.rentMin ? 'Around ${fmt(h.rentMin)}–${fmt(h.rentMax).replaceFirst('₹', '')}' : 'Around ${fmt(h.rentMin)}';

extension TiersActions on AppState {

  /// Verified and listed hostels in [area] (all of Hyderabad when null).
  ({int verified, int listed}) tierCounts(String? area) {
    final srv = areaCountsSrv;
    if (srv != null) {
      var v = 0, l = 0;
      for (final e in srv.entries) {
        if (area == null || e.key == area) {
          v += e.value.verified;
          l += e.value.listed;
        }
      }
      return (verified: v, listed: l);
    }
    final hs = browsable.where((h) => (area == null || h.area == area) && !removed(h.id));
    return (verified: hs.where((h) => !h.listed).length, listed: hs.where((h) => h.listed).length);
  }

  /// Explore header, after "Hyderabad · N beds free now": " · 12 verified ·
  /// 84 listed"; null when nothing is listed yet.
  String? tierLine(String? area) {
    final c = tierCounts(area);
    if (c.listed == 0) return null;
    return ' · ${c.verified} verified · ${c.listed} listed';
  }

  /// After the hostels load: the server's area counts and this user's waitlist.
  Future<void> loadTiers() async {
    if (!data.remote) return;
    try {
      final counts = await data.areaCounts();
      final mine = signedIn ? await data.myWaitlist() : const <String>{};
      update(() {
        areaCountsSrv = counts;
        waitlist
          ..clear()
          ..addAll(mine);
      });
    } catch (e) {
      debugPrint('tiers: $e');
    }
  }

  /// "Tell me when verified": one push when the team verifies it.
  void tellWhenVerified(Hostel h) {
    if (waitlist.contains(h.id)) return toastMsg('We’ll tell you when ${h.name} is verified.');
    if (!needSignIn('verify', () => tellWhenVerified(h))) return;
    if (!data.remote || isSeedHostel(h.id)) {
      update(() => waitlist.add(h.id));
      return toastMsg('We’ll tell you when ${h.name} is verified.');
    }
    update(() => waitlist.add(h.id));
    data.joinWaitlist(h.id).then((_) => toastMsg('We’ll tell you when ${h.name} is verified.'), onError: (Object e) {
      debugPrint('waitlist: $e');
      // Asked before (the row is there already): that's fine.
      if ('$e'.contains('23505') || '$e'.contains('duplicate')) return toastMsg('We’ll tell you when ${h.name} is verified.');
      update(() => waitlist.remove(h.id));
      toastMsg('Couldn’t save that. Check your internet and try again.');
    });
  }

  /// "Ask Hostelzy": WhatsApp to the support number, the hostel filled in.
  void askHostelzy(Hostel h) => whatsapp(supportWhatsApp, 'Hi Hostelzy, I have a question about ${h.name} in ${h.area}.');

  /// "Are you the owner? Claim this hostel ›": the claim sheet.
  void openClaim(Hostel h) {
    if (!needSignIn('claim', () => openClaim(h))) return;
    update(() {
      claimHid = h.id;
      claimName = meName;
      claimPhone = myPhone;
      sheet = 'claim';
    });
  }

  Future<void> sendClaim() async {
    final hid = claimHid;
    if (hid == null) return;
    final name = claimName.trim(), phone = claimPhone.replaceAll(RegExp(r'\D'), '');
    if (name.length < 2) return toastMsg('Enter your name.');
    if (phone.length != 10) return toastMsg('Enter your 10-digit phone.');
    if (data.remote && !isSeedHostel(hid)) {
      try {
        await data.sendClaim(hid, name, phone);
      } catch (e) {
        debugPrint('claim: $e');
        if (!'$e'.contains('23505') && !'$e'.contains('duplicate')) return toastMsg('Couldn’t send it. Check your internet and try again.');
      }
    }
    update(() {
      claimed.add(hid);
      sheet = null;
    });
    toastMsg('Sent. The Hostelzy team will call you on ${phoneSpaced(phone)}.');
  }
}
