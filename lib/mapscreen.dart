import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import the services package

// Import libraries to use Flutter Map
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';
import 'package:latlong2/latlong.dart';

class mapScreen extends StatefulWidget {
  @override
  _mapScreenState createState() => _mapScreenState();
}

class _mapScreenState extends State<mapScreen> {
  var geoParser = GeoJsonParser();
  List<Polygon> data = [];
  final LayerHitNotifier hitNotifier = ValueNotifier(null);
  List<NamedPolygon> namedPolygons = [];

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
  }

  Future<void> _loadGeoJson() async {
    try {
      // Load the GeoJSON file from the assets folder
      final geoJSONfile = await rootBundle.loadString('assets/data.geojson');

      // Parse the GeoJSON data as a string
      final geoJsonData = json.decode(geoJSONfile);

      // Extract the features from the GeoJSON data
      final features = geoJsonData['features'] as List;
    

      for (var municipio in features) {
        final nombre = municipio['properties']['NOMBRE'];
        
        
        final geometry = municipio['geometry'];
        final coordinates = geometry['coordinates'][0] as List;
        // print(coordinates);

        // if( geometry['type'] == 'MultiPolygon'){

        //   final coordinates = geometry['coordinates'][0] as List;
        //   // print(coordinates);

        //   final points = coordinates.map<List<LatLng>>((e) {
        //     if (e is List && e.length == 2) {
        //       return e.map<LatLng>((e) => LatLng(e[1], e[0])).toList();
        //     } else {
        //       throw Exception('Invalid coordinate format');
        //     }
        //   }).toList();
        //   print(points);

        //   final polygon = Polygon(
        //     points: points,
        //     color: Colors.blue.withOpacity(0.5),
        //     borderColor: Colors.blue,
        //     borderStrokeWidth: 2,
        //   );

        //   namedPolygons.add(NamedPolygon(nombre, polygon));
        // }

        if(geometry['type'] == 'Polygon'){
          final coordinates = geometry['coordinates'][0] as List;
          // print(coordinates);
          final points = coordinates.map<LatLng>((e) {
            if (e is List && e.length == 2) {
              return LatLng(e[1], e[0]);
            } else {
              throw Exception('Invalid coordinate format');
            }
          }).toList();
          // print(points);
          final polygon = Polygon(
            points: points,
            color: Colors.blue.withOpacity(0.5),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
            hitValue: nombre,
          );

          namedPolygons.add(NamedPolygon(nombre, polygon));
        }
      //  final points = coordinates.map<LatLng>((e) {
      //   if (e is List && e.length == 2) {
      //     return LatLng(e[1], e[0]);
      //   } else {
      //     throw Exception('Invalid coordinate format');
      //   }
      // }).toList();
      //   print(points);
        
      //   final polygon = Polygon(
      //     points: points,
      //     color: Colors.blue.withOpacity(0.5),
      //     borderColor: Colors.blue,
      //     borderStrokeWidth: 2,
      //   );

        // namedPolygons.add(NamedPolygon(nombre, polygon));

}

      // // Set the data variable to the polygons
      // for (var i = 0; i < geoParser.polygons.length; i++) {
      //   namedPolygons.add(NamedPolygon(geoParser.polygons[i].properties, geoParser.polygons[i]));
      // }

      setState(() {
        // data = namedPolygons.map((namedPolygon) => namedPolygon.polygon).toList();
      });
    } catch (e) {
      print('Error loading GeoJSON: $e');
    }

  }

void _showMunicipalityName(String name) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Text(
            name,
            style: TextStyle(fontSize: 24.0),
          ),
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
                      _showMunicipalityName(value);
                      print(value);
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

class NamedPolygon{
  final String name;
  final Polygon polygon;
  bool visited = false;

  NamedPolygon(this.name, this.polygon);
}
