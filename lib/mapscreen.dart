import 'dart:convert';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_geojson/flutter_map_geojson.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

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
  LatLng initialCenter = const LatLng(39.45, -0.5); // initial center of the map
  double initialZoom = 7.8; // initial zoom level
  double actualZoom = 0.0;


  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadGeoJsonInIsolate();
  }

  Future<void> _loadPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  Future<void> _loadGeoJsonInIsolate() async {
    try {
      final geoJSONfile = await rootBundle.loadString('assets/data.geojson');
      final geoJsonData = json.decode(geoJSONfile);
      final features = geoJsonData['features'] as List;

      // Procesar en un isolate separado
      List<NamedPolygon> polygons = await compute(_processGeoJson, features);
      setState(() {
        namedPolygons = polygons;
      });
    } catch (e) {
      // print('Error loading GeoJSON: $e');
    }
  }

  List<NamedPolygon> _processGeoJson(List features) {
    List<NamedPolygon> polygons = [];
    

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
              ? const Color.fromARGB(255, 93, 204, 121)
              : CupertinoColors.systemGrey4,
          borderColor: visited
              ? CupertinoColors.activeGreen
              : CupertinoColors.systemGrey2,
          borderStrokeWidth: 1.5,
          hitValue: nombre,
        );

        polygons.add(NamedPolygon(nombre, polygon, visited));
      } else if (geometry["type"] == "MultiPolygon") {
        final coordinates = geometry['coordinates'] as List;

        for (var coord in coordinates) {
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
                ? const Color.fromARGB(255, 93, 204, 121)
                : CupertinoColors.systemGrey4,
            borderColor: visited
                ? CupertinoColors.activeGreen
                : CupertinoColors.systemGrey2,
            borderStrokeWidth: 1.5,
            hitValue: nombre,
          );

          polygons.add(NamedPolygon(nombre, polygon, visited));
        }
      }
    }

    return polygons;

  }

  void _showMunicipalityName(NamedPolygon namedPolygon) {
    mapController.move(namedPolygon.polygon.points.first, 10.0);
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(namedPolygon.name,
              style:
                  const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
          message: namedPolygon.visited
              ? const Text('Ja has visitat aquest municipi')
              : const Text('Marca aquest municipi com a visitat'),
          actions: [
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
                            ? const Color.fromARGB(255, 93, 204, 121)
                            : CupertinoColors.systemGrey4,
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
        color: const Color.fromARGB(255, 93, 204, 121),
        borderColor: CupertinoColors.activeGreen,
        borderStrokeWidth: 1.5,
        hitValue: namedPolygon.name,
      );
      prefs?.setBool(namedPolygon.name, namedPolygon.visited);
    });
    mapController.move(namedPolygon.polygon.points.first, 8.0);
  }

  void _centerMap() {
    mapController.move(initialCenter, initialZoom);
  }

  void _showAboutDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text("Sobre l'aplicació"),
          content: const Text(
              'Esta aplicació mostra un mapa amb els municipis de la Comunitat Valenciana. Pots buscar un municipi i marcar-lo com a visitat.\n Idea de @enmaaarc i @polfmarti \n Desenvolupat per @beltrnjordi'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Tancar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showConfigDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Configuració de l\'aplicació'),
          content: const Text(
              'Des d\' aquí pots restaurar el mapa per marcar tots els municipis com a no visitats o enviar suggeriments.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Restaurar el mapa'),
              onPressed: () {
                Navigator.of(context).pop();
                _confirmResetMap();
              },
            ),
            CupertinoDialogAction(
              child: const Text('Enviar suggeriments'),
              onPressed: () {
                Navigator.of(context).pop();
                _sendSuggestions();
              },
            ),
            CupertinoDialogAction(
              child: const Text('Tancar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmResetMap() {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Confirmació'),
          content: const Text('Estàs segur que vols restaurar el mapa?'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Sí', style: TextStyle(color: CupertinoColors.destructiveRed)),
              onPressed: () {
                Navigator.of(context).pop();
                _resetMap();
              },
            ),
            CupertinoDialogAction(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _resetMap() {
    setState(() {
      for (var polygon in namedPolygons) {
        polygon.visited = false;
        polygon.polygon = Polygon(
          points: polygon.polygon.points,
          color: CupertinoColors.systemGrey4,
          borderColor: CupertinoColors.systemGrey2,
          borderStrokeWidth: 1.5,
          hitValue: polygon.name,
        );
      }
      prefs?.clear();
    });
  }

  void _sendSuggestions() {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Enviar suggeriments'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pots enviar suggeriments a través de X o Instagram (@beltrnjordi) o a través del següent formulari de Google)',
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
                child: const Text('Obrir Google Forms'),
                onPressed: () =>
                    launchUrl(Uri.parse('https://forms.gle/WQnGJHMmkmzz9iaf9')),
              ),
            CupertinoDialogAction(
              child: const Text('Tancar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
              
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGrey6,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showConfigDialog,
          child: const Icon(CupertinoIcons.settings),
        ),
        middle: const Text('Municipis de la Comunitat Valenciana', style: TextStyle(fontSize: 15)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showAboutDialog,
          child: const Icon(CupertinoIcons.info),
        ),
      ),
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
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialZoom,
              ),
              children: [
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
            top: screenHeight * 0.03,
            left: screenWidth * 0.05,
            right: screenWidth * 0.05,
            child: CupertinoSearchTextField(
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: const [
                  BoxShadow(
                    color: CupertinoColors.systemGrey6,
                    blurRadius: 10.0,
                    offset: Offset(0, 5),
                  ),
                ],
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
                    final uniqueNames = <String>{};
                    searchResults = namedPolygons.where((element) {
                      final isUnique =
                          uniqueNames.add(element.name.toLowerCase());
                      return element.name
                              .toLowerCase()
                              .contains(query.toLowerCase()) &&
                          isUnique;
                    }).toList();
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
                FocusScope.of(context).unfocus();
              },
            ),
          ),
          if (searchResults.isNotEmpty)
            Positioned(
              top: screenHeight * 0.1, // Ajuste para dejar espacio entre la barra de búsqueda y la lista
              left: screenWidth * 0.05,
              right: screenWidth * 0.05,
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: const [
                    BoxShadow(
                      color: CupertinoColors.systemBackground,
                      blurRadius: 10.0,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),

                // Lista de resultados de búsqueda
                child: CupertinoScrollbar(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final item = searchResults[index];
                      return GestureDetector(
                        onTap: () {
                          _showMunicipalityName(item);
                          searchController.clear();
                          setState(() {
                            searchResults = [];
                          });
                          FocusScope.of(context).unfocus();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground,
                            border: Border.all(
                              color: CupertinoColors.systemGrey4,
                    
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(12.0),
                            // boxShadow: const [
                            //    BoxShadow(
                            //     color: CupertinoColors.systemGrey4,
                            //     blurRadius: 5,
                            //     offset: Offset(0, 2),
                            //   ),
                            // ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.location_solid,
                                size: 24.0,
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 16.0),
                                ),
                              ),
                              const Icon(
                                CupertinoIcons.forward,
                                color: CupertinoColors.systemGrey,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Botón para centrar el mapa
          Positioned(
            bottom: 20.0,
            right: 20.0,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.all(12.0),
              borderRadius: BorderRadius.circular(30.0),
              onPressed: _centerMap,
              child: const Icon(
                CupertinoIcons.location_fill,
              ),
            ),
          ),

          Positioned(
            bottom: 80.0,
            right: 20.0,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.all(12.0),
              borderRadius: BorderRadius.circular(30.0),
              onPressed: _zoomOut,
              child: const Icon(
                CupertinoIcons.zoom_out,
              ),
            ),
          ),
            
          Positioned(
            bottom: 140.0,
            right: 20.0,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.all(12.0),
              borderRadius: BorderRadius.circular(30.0),
              onPressed: _zoomIn,
              child: const Icon(
                CupertinoIcons.zoom_in,
              ),
            ),
          ),
        ],
      ),
    );
  }

void _zoomIn() {
    mapController.move(initialCenter, initialZoom + 2);
  }

  void _zoomOut() {
    mapController.move(initialCenter, initialZoom );
  }
}

class NamedPolygon {
  final String name;
  Polygon polygon;
  bool visited;

  NamedPolygon(this.name, this.polygon, this.visited);
}
