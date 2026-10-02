part of '../../state.dart';

// F21 Wave 1: the resident's own stay for every resident screen. Demo builds
// show the sample (Rahul, Anjani Residency 204-B); on the server it is the
// user's real, confirmed stay, never sample data.
mixin _MyStayData {
  /// F21: the user's own confirmed stay on the server.
  Resident? myStayRow;
}

typedef MyStay = ({String hid, String bed, int rent, int joinDay, String? key});

extension MyStayActions on AppState {
  MyStay? get myStay {
    if (!onServer) return AppState.samples ? (hid: 'anjani', bed: '204-B', rent: 8020, joinDay: residentJoinDay, key: null) : null;
    final r = myStayRow, h = myHostel;
    if (r == null || h == null || !hostels.any((x) => x.id == h)) return null;
    return (hid: h, bed: r.bed, rent: r.amt, joinDay: r.joinAt == null ? 1 : DateTime.fromMillisecondsSinceEpoch(r.joinAt!).day, key: r.key);
  }

  /// The hostel the resident lives in (the sample one in demo builds).
  Hostel get stayHostel => hostelById(myStay?.hid ?? 'anjani');

  /// The owner's name, or "your owner" when the server has none.
  String get stayOwner => stayHostel.owner.trim().isEmpty ? 'your owner' : stayHostel.owner;

  /// "204" and "B" from "204-B".
  String get stayRoom => (myStay?.bed ?? '').split('-').first;
  String get stayBedLetter => (myStay?.bed ?? '').contains('-') ? myStay!.bed.split('-').last : '';

  /// "Anjani Residency · Room 204 · Bed B"
  String get stayLine => [stayHostel.name, if (stayRoom.isNotEmpty) 'Room $stayRoom', if (stayBedLetter.isNotEmpty) 'Bed $stayBedLetter'].join(' · ');

  /// The owner's WhatsApp number, when Hostelzy has it (never a sample on the server).
  String get stayOwnerPhone => ownerPhones[stayHostel.id] ?? '';

  /// This month's rent payment: the sample in demo builds; on the server the
  /// newest one for this hostel started this month (null until the resident pays).
  Payment? get myRentPay {
    if (!onServer) return payments.where((x) => x.id == 'rent204B').firstOrNull;
    final st = myStay;
    if (st == null) return null;
    final t = appToday;
    return payments.where((x) {
      if (x.kind != 'rent' || x.hid != st.hid || x.status == 'cancelled') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(x.at);
      return d.year == t.year && d.month == t.month;
    }).firstOrNull;
  }

  /// "Rent Oct · 204-B"
  String get rentNote => 'Rent ${dayMon(appToday).split(' ').last}${myStay?.bed.isNotEmpty == true ? ' · ${myStay!.bed}' : ''}';

  /// Pay rent by UPI. On the server the month's rent payment is started first.
  Future<void> payMyRent() async {
    final existing = myRentPay;
    if (existing != null) return payByUpi(existing);
    final st = myStay;
    if (st == null || st.key == null) return toastMsg('Your stay isn’t on Hostelzy yet. Ask $stayOwner to add you.');
    if (st.rent <= 0) return toastMsg('$stayOwner hasn’t set your rent on Hostelzy yet. Ask them on WhatsApp.');
    final ok = await _write(() => data.startRent(hid: st.hid, stayKey: st.key!, amount: st.rent, note: rentNote));
    if (!ok) return;
    final p = myRentPay;
    if (p != null) payByUpi(p);
  }
}
