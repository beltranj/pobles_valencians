import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import the services package
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';
import 'package:latlong2/latlong.dart';

class mapScreen extends StatefulWidget {
  @override
  _mapScreenState createState() => _mapScreenState();
}

class _mapScreenState extends State<mapScreen> {
  var geoParser = GeoJsonParser();
  final LayerHitNotifier hitNotifier = ValueNotifier(null);
  List<NamedPolygon> namedPolygons = [];

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
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

          final polygon = Polygon(
            points: points,
            color: Colors.blue.withOpacity(0.5),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
            hitValue: nombre,
          );

          namedPolygons.add(NamedPolygon(nombre, polygon));
        }
      }

      setState(() {});
    } catch (e) {
      print('Error loading GeoJSON: $e');
    }
  }

  void _showMunicipalityName(NamedPolygon namedPolygon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              margin: const EdgeInsets.all(4.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(38.0),
                  topRight: Radius.circular(38.0),
                  bottomLeft: Radius.circular(38.0),
                  bottomRight: Radius.circular(38.0),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10.0),
                    height: 5.0,
                    width: 50.0,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      namedPolygon.name,
                      style: TextStyle(fontSize: 24.0),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text('Visited:'),
                        Checkbox(
                          value: namedPolygon.visited,
                          onChanged: (bool? value) {
                            setState(() {
                              namedPolygon.visited = value ?? false;
                              namedPolygon.polygon = Polygon(
                                points: namedPolygon.polygon.points,
                                color: namedPolygon.visited
                                    ? Colors.green.withOpacity(0.5)
                                    : Colors.blue.withOpacity(0.5),
                                borderColor: namedPolygon.visited
                                    ? Colors.green
                                    : Colors.blue,
                                borderStrokeWidth: 2,
                                hitValue: namedPolygon.name,
                              );
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map Screen'),
      ),
      body: Center(
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(39.1, -0.01),
            initialZoom: 8.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
            ),
            MouseRegion(
              hitTestBehavior: HitTestBehavior.deferToChild,
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  final LayerHitResult? hitResult = hitNotifier.value;
                  if (hitResult != null) {
                    final value = hitResult.hitValues.first;
                    if (value is String) {
                      final namedPolygon = namedPolygons.firstWhere(
                          (element) => element.name == value);
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
    );
  }
}

class NamedPolygon {
  final String name;
  Polygon polygon;
  bool visited = false;

  NamedPolygon(this.name, this.polygon);
}
