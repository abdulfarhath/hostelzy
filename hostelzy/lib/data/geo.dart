import 'dart:math' as math;

import '../data.dart';

// ------------------------------------------------------------ F17 real map

/// Map positions (latitude, longitude) of the sample hostels and landmarks.
const hostelLatLng = <String, (double, double)>{
  'anjani': (17.4483, 78.3915),
  'saisri': (17.4590, 78.3650),
  'nest42': (17.4405, 78.3485),
  'greenview': (17.4640, 78.3560),
  'orchid': (17.4935, 78.3995),
  'lakshmi': (17.4375, 78.4480),
};

const landmarkLatLng = <String, (double, double)>{
  'Hitec City': (17.4474, 78.3762),
  'Gachibowli': (17.4401, 78.3489),
  'Ameerpet': (17.4374, 78.4487),
  'JNTU': (17.4933, 78.3915),
};

const areaLatLng = <String, (double, double)>{
  'Madhapur': (17.4483, 78.3915),
  'Kondapur': (17.4615, 78.3600),
  'Hitec City': (17.4474, 78.3762),
  'Ameerpet': (17.4374, 78.4487),
  'SR Nagar': (17.4410, 78.4410),
  'Gachibowli': (17.4401, 78.3489),
  'KPHB': (17.4935, 78.3995),
  'Kukatpally': (17.4849, 78.4138),
  'Jubilee Hills': (17.4326, 78.4071),
  'Begumpet': (17.4447, 78.4664),
};

/// F18 map: areas tenants can pick (design "Areas"); empty ones show "Soon".
const mapAreas = ['Ameerpet', 'SR Nagar', 'Madhapur', 'Hitec City', 'Kondapur', 'Gachibowli', 'KPHB', 'Kukatpally', 'Jubilee Hills', 'Begumpet'];

/// Search this area: hostels within this many km of the map's centre.
const searchRadiusKm = 3.0;

(double, double) posOf(Hostel h) => livePos[h.id] ?? hostelLatLng[h.id] ?? areaLatLng[h.area] ?? landmarkLatLng['Hitec City']!;

/// Straight-line distance in km (haversine). Travel time comes later.
double kmBetween((double, double) a, (double, double) b) {
  const r = 6371.0, d = 3.141592653589793 / 180;
  final dLat = (b.$1 - a.$1) * d, dLng = (b.$2 - a.$2) * d;
  final x = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(a.$1 * d) * math.cos(b.$1 * d) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(x));
}

double kmTo(Hostel h, String landmark) => kmBetween(posOf(h), landmarkLatLng[landmark]!);

/// "1.2 km"
String kmLabel(double km) => '${km.toStringAsFixed(1)} km';
