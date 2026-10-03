import '../data.dart';

// ------------------------------------------------------------ F03 deals

/// The owner's deal menu (F03). Amounts are fixed for now.
const monthlyOff = 200, firstOff = 500, advanceOff = 1000, exitHz = 500, joiningFee = 1000, laundryCost = 50;

const dealMenu = ['exit', 'monthly', 'first', 'advance', 'laundry', 'noadmin'];

/// Max active deals per owner (DECISIONS 2026-10-02).
const maxDeals = 3;

/// Short perk labels for chips and the locked-deal card.
String dealPerk(String id) => switch (id) {
  'exit' => '${fmt(exitHz)} exit',
  'monthly' => '${fmt(monthlyOff)} off monthly',
  'first' => '${fmt(firstOff)} off first month',
  'advance' => '${fmt(advanceOff)} lower advance',
  'laundry' => 'Free laundry',
  _ => 'No joining fee',
};

/// A hostel's published deals: which ones, which room types (all | ac |
/// non, F16) and when the owner last confirmed them.
class Deals {
  const Deals({this.on = const {}, this.target = 'all', this.confirmed = '1 Oct'});
  final Set<String> on;
  final String target, confirmed;
  bool covers(bool ac) => on.isNotEmpty && (target == 'all' || (target == 'ac') == ac);
  String get targetText => switch (target) {
    'ac' => 'AC rooms only',
    'non' => 'non-AC rooms only',
    _ => 'all rooms',
  };
}

final seedDeals = <String, Deals>{
  'anjani': const Deals(on: {'exit', 'monthly', 'laundry'}),
  'saisri': const Deals(on: {'exit', 'advance'}),
  'greenview': const Deals(on: {'first', 'exit'}),
  'orchid': const Deals(on: {'monthly'}, target: 'non'),
};

/// Walk-in vs Hostelzy prices for one room type at one monthly [fee].
class DealQuote {
  DealQuote(Terms t, this.fee, Set<String> on)
    : hzFee = fee - (on.contains('monthly') ? monthlyOff : 0),
      adv = t.advance,
      hzAdv = t.advance - (on.contains('advance') ? advanceOff : 0),
      exit = t.maintenance,
      hzExit = on.contains('exit') && t.maintenance > exitHz ? exitHz : t.maintenance,
      join = on.contains('noadmin') ? joiningFee : 0,
      firstOffNow = on.contains('first') ? firstOff : 0,
      laundry = on.contains('laundry');
  final int fee, hzFee, adv, hzAdv, exit, hzExit, join, firstOffNow;
  final bool laundry;

  int get hzFirst => hzFee - firstOffNow;
  int get move => adv + fee + join;
  int get hzMove => hzAdv + hzFirst;
  int get back => adv - exit;
  int get hzBack => hzAdv - hzExit;

  /// Saving over the first 6 months (DECISIONS: the headline).
  int get save6 => (6 * fee + join) - (5 * hzFee + hzFirst);
  int get upfront => move - hzMove;
  int get moreBack => hzExit < exit ? exit - hzExit : 0;
  bool get any => hzFee != fee || hzAdv != adv || hzExit != exit || join > 0 || firstOffNow > 0 || laundry;

  /// Explore ribbon text.
  String get ribbon => save6 > 0
      ? 'Save ${fmt(save6)} in 6 mo'
      : upfront > 0
      ? '${fmt(upfront)} less upfront'
      : moreBack > 0
      ? '${fmt(moreBack)} more back'
      : 'Hostelzy deal';
}

/// Perks locked into a booking, as the locked-deal card lists them (F04).
List<String> dealPerks(DealQuote q, int noticeDays) => !q.any
    ? const []
    : [
        if (q.hzFee < q.fee) '${fmt(q.hzFee)} monthly',
        if (q.hzExit < q.exit) '${fmt(q.hzExit)} exit only',
        if (q.firstOffNow > 0) '${fmt(firstOff)} off first month',
        if (q.hzAdv < q.adv) '${fmt(q.hzAdv)} advance',
        if (q.join > 0) 'No joining fee',
        if (q.laundry) 'Free laundry weekly',
        '$noticeDays days notice',
      ];

/// F24 item 13: the deal the server locked on a booking (`holds.deal`,
/// `stays.deal`: on, fee, advance, maintenance, notice) → its perks and the
/// fixed monthly rent. Null when there is none.
({List<String> perks, int fee})? lockedDeal(Object? deal) {
  if (deal is! Map) return null;
  final fee = (deal['fee'] as num?)?.toInt() ?? 0;
  if (fee <= 0) return null;
  final t = Terms(advance: (deal['advance'] as num?)?.toInt() ?? 3000, maintenance: (deal['maintenance'] as num?)?.toInt() ?? 1000, noticeDays: (deal['notice'] as num?)?.toInt() ?? 30);
  final q = DealQuote(t, fee, {...(deal['on'] as List? ?? const []).whereType<String>()});
  return (perks: dealPerks(q, t.noticeDays), fee: q.hzFee);
}
