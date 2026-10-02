// F17-C: where the map tiles come from. One place to swap providers.
//
// OpenStreetMap's public tiles are fine for testing but are NOT for heavy
// production traffic (https://operations.osmfoundation.org/policies/tiles/).
// Before launch, switch to a keyed provider (MapTiler, Stadia, or Google Maps
// via google_maps_flutter) once the founder adds an API key: change the URL
// and attribution here, and put the key in config, never in the code.

/// Tile URL template ({z}/{x}/{y}).
const mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Sent with every tile request, as the OSM tile policy requires.
const mapUserAgent = 'app.hostelzy.hostelzy';

/// Shown on the map, as the tile licence requires.
const mapAttribution = '© OpenStreetMap contributors';
