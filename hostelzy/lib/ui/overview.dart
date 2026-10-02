import 'package:flutter/material.dart';

import '../state.dart';
import 'kit.dart';
import 'shell.dart';

/// "All screens" canvas: every screen as a live, clickable phone.
class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.onOpenPrototype});
  final VoidCallback onOpenPrototype;

  static const _ink = Color(0xFF201E1D), _mu = Color(0xFF605D5D);

  static const sections = <(String, String?, List<(String, Map<String, String>)>)>[
    (
      '01 · Start',
      null,
      [
        ('Welcome', {'start': 'welcome'}),
        ('Phone', {'start': 'phone'}),
        ('OTP', {'start': 'otp'}),
        ('Pick a role', {'start': 'role'}),
      ],
    ),
    (
      '02 · Tenant: find and hold a bed',
      null,
      [
        ('Explore', {'start': 'explore', 'role': 'tenant'}),
        ('Search sheet', {'start': 'explore', 'role': 'tenant', 'sheet': 'search'}),
        ('Map', {'start': 'map', 'role': 'tenant'}),
        ('Hostel detail', {'start': 'detail', 'role': 'tenant'}),
        ('Ask on WhatsApp', {'start': 'detail', 'role': 'tenant', 'sheet': 'wa'}),
        ('Verified reviews', {'start': 'reviews', 'role': 'tenant'}),
      ],
    ),
    (
      '03 · Bed picker: three ways to choose',
      'All three are in the prototype behind the Plan / List / Building switch, so we can test which one tenants actually use.',
      [
        ('A · Floor plan of one room', {'start': 'picker', 'role': 'tenant', 'mode': 'plan'}),
        ('B · List of every open bed', {'start': 'picker', 'role': 'tenant', 'mode': 'list'}),
        ('C · Building cross-section', {'start': 'picker', 'role': 'tenant', 'mode': 'building'}),
        ('Hold options', {'start': 'picker', 'role': 'tenant', 'sheet': 'hold'}),
        ('Hold status', {'start': 'hold', 'role': 'tenant'}),
      ],
    ),
    (
      '04 · Resident: my stay',
      null,
      [
        ('Home', {'start': 'rHome', 'role': 'resident'}),
        ('Pay rent', {'start': 'rPay', 'role': 'resident'}),
        ('Food', {'start': 'food', 'role': 'resident'}),
        ('Complaints', {'start': 'help', 'role': 'resident'}),
        ('Give notice', {'start': 'move', 'role': 'resident', 'moveTab': 'vacate'}),
        ('Confirm your stay', {'start': 'rConfirm', 'role': 'resident'}),
        ('30-day review', {'start': 'rReview', 'role': 'resident'}),
        ('Exit review', {'start': 'rExit', 'role': 'resident'}),
        ('Swap bed', {'start': 'move', 'role': 'resident', 'moveTab': 'swap'}),
      ],
    ),
    (
      '05 · Owner: run the hostel',
      null,
      [
        ('Today + hold requests', {'start': 'oToday', 'role': 'owner'}),
        ('Live bed map', {'start': 'oBeds', 'role': 'owner'}),
        ('Rooms and rent', {'start': 'oMore', 'role': 'owner', 'moreTab': 'rates'}),
        ('Bed actions', {'start': 'oBeds', 'role': 'owner', 'sheet': 'bed'}),
        ('Add booking', {'start': 'oToday', 'role': 'owner', 'sheet': 'add'}),
        ('One enquiry', {'start': 'oToday', 'role': 'owner', 'sheet': 'enq'}),
        ('Residents', {'start': 'oMore', 'role': 'owner', 'moreTab': 'residents'}),
        ('Add a resident', {'start': 'oMore', 'role': 'owner', 'moreTab': 'residents', 'sheet': 'addR'}),
        ('Invite QR', {'start': 'oInvite', 'role': 'owner'}),
        ('Your ranking', {'start': 'oRank', 'role': 'owner'}),
        ('Reply to reviews', {'start': 'oReviews', 'role': 'owner'}),
        ('Rent collection', {'start': 'oRent', 'role': 'owner'}),
        ('Complaints queue', {'start': 'oMore', 'role': 'owner', 'moreTab': 'complaints'}),
        ('Edit menu', {'start': 'oMore', 'role': 'owner', 'moreTab': 'menu'}),
        ('Edit rules', {'start': 'oMore', 'role': 'owner', 'moreTab': 'rules'}),
        ('Hostelzy deals', {'start': 'oMore', 'role': 'owner', 'moreTab': 'deals'}),
      ],
    ),
    (
      '06 · Dark theme',
      null,
      [
        ('Explore', {'start': 'explore', 'role': 'tenant', 'theme': 'dark'}),
        ('Bed picker', {'start': 'picker', 'role': 'tenant', 'theme': 'dark'}),
        ('Resident home', {'start': 'rHome', 'role': 'resident', 'theme': 'dark'}),
        ('Owner today', {'start': 'oToday', 'role': 'owner', 'theme': 'dark'}),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // No line-height on this page's body: CSS `normal`.
    final base = const TextStyle(fontFamily: 'Archivo', fontSize: 16, color: _ink, leadingDistribution: TextLeadingDistribution.even, decoration: TextDecoration.none);
    final items = <Widget>[_header(), for (final s in sections) _section(s)];
    return ColoredBox(
      color: const Color(0xFFDCDAD9),
      child: DefaultTextStyle(
        style: base,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(48, 48, 48, 80),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 56),
            itemBuilder: (_, i) => Align(alignment: Alignment.topLeft, child: items[i]),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    Widget fact(String k, String v) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: k,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: ' $v'),
        ],
      ),
      style: const TextStyle(fontSize: 14, height: 1.5),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1400),
      child: Container(
        padding: const EdgeInsets.only(bottom: 32),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(width: 2, color: Color.fromRGBO(32, 30, 29, .4))),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Hostelzy · mobile app v1 · all screens', s: 12, w: 600, ls: .1, upper: true, c: _mu),
                    const SizedBox(height: 8),
                    const T('One app. Three roles. Every bed visible.', w: 800, s: 56, lh: .96, ls: -.035),
                    const SizedBox(height: 16),
                    _OverviewLink('Open the clickable prototype →', onTap: onOpenPrototype),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fact('System:', 'Modernist. Archivo, one red, no rounded corners, 2px rules. The grid does the organising.'),
                    const SizedBox(height: 10),
                    fact('Roles:', 'picked once after OTP: tenant, resident, owner. Each gets four tabs and a red action in the middle: Search, Pay rent, Add booking.'),
                    const SizedBox(height: 10),
                    fact('Beds:', 'the same five states everywhere. Free (outline), free soon (dashed), on hold (hatched), taken (grey), selected (red).'),
                    const SizedBox(height: 10),
                    fact('Holds:', 'free for 1 hour (owner confirms), or book by paying the ₹3,000 advance straight to the owner with the Hostelzy deal locked (F04). Owner contact always goes through WhatsApp.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section((String, String?, List<(String, Map<String, String>)>) s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        T(s.$1, w: 800, s: 28),
        if (s.$2 != null) ...[
          const SizedBox(height: 10),
          // max-width: 70ch (70 × the "0" advance of Archivo at 14px).
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 561.54),
            child: T(s.$2!, s: 14, c: _mu),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 28,
          runSpacing: 28,
          children: [
            for (final it in s.$3)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  T(it.$1, s: 12, w: 600, c: _mu),
                  const SizedBox(height: 8),
                  _LivePhone(it.$2),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _LivePhone extends StatefulWidget {
  const _LivePhone(this.props);
  final Map<String, String> props;
  @override
  State<_LivePhone> createState() => _LivePhoneState();
}

class _LivePhoneState extends State<_LivePhone> {
  late final AppState state = AppState(start: widget.props['start'], role: widget.props['role'], theme: widget.props['theme'], mode: widget.props['mode'], sheet: widget.props['sheet'], moveTab: widget.props['moveTab'], moreTab: widget.props['moreTab']);
  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(state: state, child: const HostelzyShell(bare: true));
}

class _OverviewLink extends StatefulWidget {
  const _OverviewLink(this.text, {required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  State<_OverviewLink> createState() => _OverviewLinkState();
}

class _OverviewLinkState extends State<_OverviewLink> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hover = true),
    onExit: (_) => setState(() => hover = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: T(widget.text, w: 600, underline: true, c: hover ? const Color(0xFFEC3013) : const Color(0xFFAE1800)),
    ),
  );
}
