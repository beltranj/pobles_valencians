import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  var geoParser = GeoJsonParser();
  final LayerHitNotifier hitNotifier = ValueNotifier(null);
  List<NamedPolygon> namedPolygons = [];
  SharedPreferences? prefs;
  MapController mapController = MapController();
  TextEditingController searchController = TextEditingController();
  List<NamedPolygon> searchResults = [];
  FocusNode searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadGeoJson();
  }

  Future<void> _loadPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  Future<void> _loadGeoJson() async {
    try {
      final geoJSONfile = await rootBundle.loadString('assets/data.geojson');
      final geoJsonData = json.decode(geoJSONfile);
      final features = geoJsonData['features'] as List;

      for (var municipio in features) {
        final nombre = municipio['properties']['NOMBRE'];
        final geometry = municipio['geometry'];
        final coordinates = geometry['coordinates'][0] as List;

        if (geometry['type'] == 'Polygon') {
          final points = coordinates.map<LatLng>((e) {
            if (e is List && e.length == 2) {
              return LatLng(e[1], e[0]);
            } else {
              throw Exception('Invalid coordinate format');
            }
          }).toList();

          final visited = prefs?.getBool(nombre) ?? false;

          final polygon = Polygon(
            points: points,
            color: visited
                ? CupertinoColors.activeGreen.withOpacity(0.5)
                : CupertinoColors.systemGrey4.withOpacity(0.3),
            borderColor: visited
                ? CupertinoColors.activeGreen
                : CupertinoColors.systemGrey2,
            borderStrokeWidth: 1.5,
            hitValue: nombre,
          );

          namedPolygons.add(NamedPolygon(nombre, polygon, visited));
        }
        else if (geometry["type"] == "MultiPolygon"){
          final coordinates = geometry['coordinates'] as List;

          for (var coord in coordinates){
            final points = coord[0].map<LatLng>((e) {
              if (e is List && e.length == 2) {
                return LatLng(e[1], e[0]);
              } else {
                throw Exception('Invalid coordinate format');
              }
            }).toList();

            final visited = prefs?.getBool(nombre) ?? false;

            final polygon = Polygon(
              points: points,
              color: visited
                  ? CupertinoColors.activeGreen.withOpacity(0.5)
                  : CupertinoColors.systemGrey4.withOpacity(0.3),
              borderColor: visited
                  ? CupertinoColors.activeGreen
                  : CupertinoColors.systemGrey2,
              borderStrokeWidth: 1.5,
              hitValue: nombre,
            );

            namedPolygons.add(NamedPolygon(nombre, polygon, visited));
          }
        }
      }

      setState(() {});
    } catch (e) {
      // print('Error loading GeoJSON: $e');
    }
  }

  void _showMunicipalityName(NamedPolygon namedPolygon) {
    mapController.move(namedPolygon.polygon.points.first, 12.0);
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(namedPolygon.name, style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
          actions: [
            CupertinoActionSheetAction(
              child: Text('Visitat? ${namedPolygon.visited ? "Si" : "No"}'),
              onPressed: () {},
            ),
            CupertinoActionSheetAction(
              child: const Text('Marca/desmarca com a visitat'),
              onPressed: () {
                setState(() {
                  for (var polygon in namedPolygons) {
                    if (polygon.name == namedPolygon.name) {
                      polygon.visited = !polygon.visited;
                    polygon.polygon = Polygon(
                      points: polygon.polygon.points,
                      color: polygon.visited
                  ? CupertinoColors.activeGreen.withOpacity(0.5)
                  : CupertinoColors.systemGrey4.withOpacity(0.3),
              borderColor: polygon.visited
                  ? CupertinoColors.activeGreen
                  : CupertinoColors.systemGrey2,
                      borderStrokeWidth: 1.5,
                      hitValue: polygon.name,
                    );
                    prefs?.setBool(polygon.name, polygon.visited);
                    }
                  }
                });
                Navigator.of(context).pop();
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel·lar'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  void _selectMunicipality(NamedPolygon namedPolygon) {
    setState(() {
      namedPolygon.visited = true;
      namedPolygon.polygon = Polygon(
        points: namedPolygon.polygon.points,
        color: CupertinoColors.activeGreen.withOpacity(0.3),
        borderColor: CupertinoColors.activeGreen,
        borderStrokeWidth: 1.5,
        hitValue: namedPolygon.name,
      );
      prefs?.setBool(namedPolygon.name, namedPolygon.visited);
    });
    mapController.move(
        namedPolygon.polygon.points.first, 12.0); // Adjust zoom level as needed
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                searchResults = [];
              });
            },
            child: FlutterMap(
              mapController: mapController,
              options: const MapOptions(
                initialCenter: LatLng(39.45, -0.5),
                initialZoom: 8.0,
              ),
              children: [
                // TileLayer(
                //   urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                //   subdomains: const ['a', 'b', 'c'],
                // ),
                MouseRegion(
                  hitTestBehavior: HitTestBehavior.deferToChild,
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      final LayerHitResult? hitResult = hitNotifier.value;
                      if (hitResult != null) {
                        final value = hitResult.hitValues.first;
                        if (value is String) {
                          final namedPolygon = namedPolygons
                              .firstWhere((element) => element.name == value);
                          _showMunicipalityName(namedPolygon);
                        }
                      }
                    },
                    child: PolygonLayer(
                      polygons: namedPolygons.map((e) => e.polygon).toList(),
                      hitNotifier: hitNotifier,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 60.0, // Position it near the top of the screen
            left: 16.0,
            right: 16.0,
            child: CupertinoSearchTextField(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(12.0),
              ),
              placeholder: "Busca un municipi",
              controller: searchController,
              focusNode: searchFocusNode,
              onChanged: (query) {
                setState(() {
                  if (query.isEmpty) {
                    searchResults = [];
                    FocusScope.of(context).unfocus();
                  } else {
                    searchResults = namedPolygons
                        .where((element) => element.name
                            .toLowerCase()
                            .contains(query.toLowerCase()))
                        .toList();
                  }
                });
              },
              onSubmitted: (query) {
                if (searchResults.isNotEmpty) {
                  _selectMunicipality(searchResults.first);
                }
              },
              onSuffixTap: () {
                searchController.clear();
                setState(() {
                  searchResults = [];
                });
                FocusScope.of(context)
                    .unfocus(); // Close the keyboard when the close button is clicked
              },
            ),
          ),
          if (searchResults.isNotEmpty)
            Positioned(
              top: 100.0, // Position it just below the search bar
              left: 10.0,
              right: 10.0,
              child: Container(
                margin: const EdgeInsets.all(8.0), // Add margins
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius:
                      BorderRadius.circular(12.0), // Add rounded corners
                  boxShadow: const [
                     BoxShadow(
                      color: CupertinoColors.systemGrey,
                      blurRadius: 10.0,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: CupertinoScrollbar(
                    child: CupertinoListSection.insetGrouped(
                      decoration: const BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                      ),
                      children: List.generate(searchResults.length, (index) {
                        final item = searchResults[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4,
                            ),
                          ),
                          child: CupertinoListTile(
                            title: Text(item.name),
                            onTap: () {
                              _showMunicipalityName(item);
                              searchController.clear();
                              setState(() {
                                searchResults = [];
                              });
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NamedPolygon {
  final String name;
  Polygon polygon;
  bool visited;

  NamedPolygon(this.name, this.polygon, this.visited);
}
