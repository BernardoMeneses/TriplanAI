import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../common/app_colors.dart';
import '../../common/constants/app_constants.dart';
import '../../shared/widgets/snackbar_helper.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class NavigationPage extends StatefulWidget {
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final bool isFlightMode;
  // Optional origin point (previous itinerary item)
  final String? originName;
  final double? originLat;
  final double? originLng;
  // Transport mode from backend calculation
  final String? transportMode; // walking, driving, transit
  // Itinerary item ID to save transport mode
  final String? itineraryItemId;

  const NavigationPage({
    super.key,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    this.isFlightMode = false,
    this.originName,
    this.originLat,
    this.originLng,
    this.transportMode,
    this.itineraryItemId,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  GoogleMapController? _mapController;
  final ApiService _apiService = ApiService();

  Position? _currentPosition;
  bool _isLoading = true;
  String? _error;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Informação da rota
  String _travelMode = 'walking'; // Will be overridden in initState
  int? _durationMinutes;
  String? _durationText;
  String? _distanceText;
  List<RouteStep> _steps = [];

  // Informação de voo
  bool _isFlightMode = false;
  AirportInfo? _departureAirport;
  AirportInfo? _arrivalAirport;
  int? _flightDurationMinutes;
  String? _totalFlightDistance;

  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _isFlightMode = widget.isFlightMode;
    // Use transport mode from backend if available
    if (widget.transportMode != null) {
      _travelMode = widget.transportMode!;
    }
    _initializeNavigation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _closeNavigation() {
    // Return the current travel mode so day_details can update
    Navigator.pop(context, _travelMode);
  }

  Future<void> _initializeNavigation() async {
    setState(() => _isLoading = true);

    try {
      // Use provided origin if available, otherwise get current position
      if (widget.originLat != null && widget.originLng != null) {
        // Use previous itinerary point as origin
        _currentPosition = Position(
          latitude: widget.originLat!,
          longitude: widget.originLng!,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      } else {
        // Obter posição atual do utilizador
        _currentPosition = await LocationService.getCurrentPosition();

        if (_currentPosition == null) {
          setState(() {
            _error =
                'Could not get your location. Please enable location services.';
            _isLoading = false;
          });
          return;
        }
      }

      if (_isFlightMode) {
        // Para voos, procurar aeroportos
        await _initializeFlightMode();
      } else {
        // Criar marcadores
        await _createMarkers();

        // Calcular rota
        await _calculateRoute();
      }

      // Iniciar tracking da posição apenas se estivermos usando localização atual
      if (widget.originLat == null && widget.originLng == null) {
        _startPositionTracking();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeFlightMode() async {
    if (_currentPosition == null) return;

    try {
      // Procurar aeroporto mais próximo da posição atual
      final departureResponse = await _apiService.get(
        '/maps/nearby',
        queryParams: {
          'lat': _currentPosition!.latitude.toString(),
          'lng': _currentPosition!.longitude.toString(),
          'type': 'airport',
          'radius': '100000', // 100km
        },
      );

      // Procurar aeroporto mais próximo do destino
      final arrivalResponse = await _apiService.get(
        '/maps/nearby',
        queryParams: {
          'lat': widget.destinationLat.toString(),
          'lng': widget.destinationLng.toString(),
          'type': 'airport',
          'radius': '100000', // 100km
        },
      );

      if (departureResponse != null && (departureResponse as List).isNotEmpty) {
        final airport = departureResponse[0];
        _departureAirport = AirportInfo(
          name: airport['name'] ?? AppConstants.departureAirport.tr(),
          code: _extractAirportCode(airport['name'] ?? ''),
          latitude: airport['location']?['lat'] ?? _currentPosition!.latitude,
          longitude: airport['location']?['lng'] ?? _currentPosition!.longitude,
        );
      } else {
        // Fallback: aeroporto genérico
        _departureAirport = AirportInfo(
          name: AppConstants.nearestAirport.tr(),
          code: 'DEP',
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );
      }

      if (arrivalResponse != null && (arrivalResponse as List).isNotEmpty) {
        final airport = arrivalResponse[0];
        _arrivalAirport = AirportInfo(
          name: airport['name'] ?? AppConstants.arrivalAirport.tr(),
          code: _extractAirportCode(airport['name'] ?? ''),
          latitude: airport['location']?['lat'] ?? widget.destinationLat,
          longitude: airport['location']?['lng'] ?? widget.destinationLng,
        );
      } else {
        // Fallback: aeroporto genérico
        _arrivalAirport = AirportInfo(
          name: AppConstants.destinationAirport.tr(),
          code: 'ARR',
          latitude: widget.destinationLat,
          longitude: widget.destinationLng,
        );
      }

      // Calcular distância total do voo
      final flightDistance = LocationService.calculateDistance(
        _departureAirport!.latitude,
        _departureAirport!.longitude,
        _arrivalAirport!.latitude,
        _arrivalAirport!.longitude,
      );

      _totalFlightDistance = '${(flightDistance / 1000).round()} km';

      // Estimar tempo de voo (~800km/h)
      final flightHours = flightDistance / 1000 / 800;
      _flightDurationMinutes = (flightHours * 60).round();

      // Criar marcadores para voo
      _createFlightMarkers();

      // Calcular rota até ao aeroporto de partida
      _travelMode = 'driving';
      await _calculateRouteToAirport();
    } catch (e) {
      print('Error initializing flight mode: $e');
      // Fallback para modo terrestre
      _isFlightMode = false;
      _createMarkers();
      await _calculateRoute();
    }
  }

  String _extractAirportCode(String airportName) {
    // Tentar extrair código do aeroporto do nome (ex: "Aeroporto Francisco Sá Carneiro (OPO)")
    final regex = RegExp(r'\(([A-Z]{3})\)');
    final match = regex.firstMatch(airportName);
    if (match != null) {
      return match.group(1)!;
    }
    // Gerar código baseado nas primeiras 3 letras
    final words = airportName.split(' ').where((w) => w.length > 2).toList();
    if (words.isNotEmpty) {
      return words.take(3).map((w) => w[0].toUpperCase()).join();
    }
    return 'APT';
  }

  void _createFlightMarkers() {
    final markers = <Marker>{};

    // Marcador da posição atual
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: AppConstants.yourLocation.tr()),
        ),
      );
    }

    // Marcador do aeroporto de partida
    if (_departureAirport != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('departure_airport'),
          position: LatLng(
            _departureAirport!.latitude,
            _departureAirport!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: _departureAirport!.code,
            snippet: _departureAirport!.name,
          ),
        ),
      );
    }

    // Marcador do aeroporto de chegada
    if (_arrivalAirport != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('arrival_airport'),
          position: LatLng(
            _arrivalAirport!.latitude,
            _arrivalAirport!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
          infoWindow: InfoWindow(
            title: _arrivalAirport!.code,
            snippet: _arrivalAirport!.name,
          ),
        ),
      );
    }

    // Marcador do destino final
    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destinationLat, widget.destinationLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.destinationName),
      ),
    );

    setState(() => _markers = markers);
  }

  Future<void> _calculateRouteToAirport() async {
    if (_currentPosition == null || _departureAirport == null) return;

    try {
      final language = context.locale.languageCode;
      final response = await _apiService.post(
        '/routes/calculate',
        body: {
          'origin': {
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
          },
          'destination': {
            'latitude': _departureAirport!.latitude,
            'longitude': _departureAirport!.longitude,
          },
          'travelMode': _travelMode,
          'language': language,
        },
      );

      if (response != null) {
        final durationSeconds = response['duration'] ?? 0;
        _durationMinutes = (durationSeconds / 60).round();
        _durationText = response['durationText'] ?? '$_durationMinutes min';
        _distanceText = response['distanceText'] ?? '';

        // Parse steps
        if (response['steps'] != null) {
          _steps = (response['steps'] as List)
              .map((s) => RouteStep.fromJson(s))
              .toList();
        }

        // Desenhar polylines
        if (response['polyline'] != null) {
          final decodedPoints = _decodePolyline(response['polyline']);
          final polylines = <Polyline>{};

          // Rota terrestre até ao aeroporto
          polylines.add(
            Polyline(
              polylineId: const PolylineId('route_to_airport'),
              points: decodedPoints,
              color: _getTransportColor(_travelMode),
              width: 5,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          );

          // Linha do voo (tracejada visualmente com cor diferente)
          if (_departureAirport != null && _arrivalAirport != null) {
            polylines.add(
              Polyline(
                polylineId: const PolylineId('flight_path'),
                points: [
                  LatLng(
                    _departureAirport!.latitude,
                    _departureAirport!.longitude,
                  ),
                  LatLng(_arrivalAirport!.latitude, _arrivalAirport!.longitude),
                ],
                color: Colors.orange,
                width: 3,
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              ),
            );
          }

          setState(() => _polylines = polylines);

          // Ajustar câmera para mostrar tudo
          _fitMapToFlightRoute();
        }
      }
    } catch (e) {
      print('Error calculating route to airport: $e');
    }
  }

  void _fitMapToFlightRoute() {
    if (_mapController == null || _currentPosition == null) return;

    final points = <LatLng>[
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
    ];

    if (_departureAirport != null) {
      points.add(
        LatLng(_departureAirport!.latitude, _departureAirport!.longitude),
      );
    }
    if (_arrivalAirport != null) {
      points.add(LatLng(_arrivalAirport!.latitude, _arrivalAirport!.longitude));
    }
    points.add(LatLng(widget.destinationLat, widget.destinationLng));

    _fitMapToRoute(points);
  }

  Future<void> _createMarkers() async {
    final markers = <Marker>{};

    // Preservar o marcador de transporte se existir
    final transportMarker = _markers
        .where((m) => m.markerId.value == 'transport')
        .firstOrNull;

    // Criar ícones customizados com números
    final originIcon = await _createNumberMarkerIcon(1);
    final destinationIcon = await _createNumberMarkerIcon(2);

    // Marcador da posição de origem (localização atual ou ponto anterior)
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: originIcon,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: widget.originName ?? AppConstants.yourLocation.tr(),
            snippet: 'trip_details.tap_to_open_maps'.tr(),
            onTap: () => _openInGoogleMaps(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              widget.originName ?? AppConstants.yourLocation.tr(),
            ),
          ),
        ),
      );
    }

    // Marcador do destino
    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destinationLat, widget.destinationLng),
        icon: destinationIcon,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: widget.destinationName,
          snippet: 'trip_details.tap_to_open_maps'.tr(),
          onTap: () => _openInGoogleMaps(
            widget.destinationLat,
            widget.destinationLng,
            widget.destinationName,
          ),
        ),
      ),
    );

    // Adicionar de volta o marcador de transporte se existia
    if (transportMarker != null) {
      markers.add(transportMarker);
    }

    setState(() => _markers = markers);
  }

  Future<BitmapDescriptor> _createNumberMarkerIcon(int number) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = AppColors.primaryDark;

    // Desenhar círculo
    const size = 80.0;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    // Desenhar borda
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 2,
      borderPaint,
    );

    // Desenhar número
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: number.toString(),
      style: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createTransportMarkerIcon(String mode) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final transportColor = _getTransportColor(mode);

    // Fundo branco circular
    const size = 60.0;
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      backgroundPaint,
    );

    // Borda com cor do transporte
    final borderPaint = Paint()
      ..color = transportColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 2,
      borderPaint,
    );

    // Desenhar ícone com cor do transporte
    final icon = _getTravelModeIcon(mode);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 32,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: transportColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _calculateRoute() async {
    if (_currentPosition == null) return;

    try {
      final language = context.locale.languageCode;
      final response = await _apiService.post(
        '/routes/calculate',
        body: {
          'origin': {
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
          },
          'destination': {
            'latitude': widget.destinationLat,
            'longitude': widget.destinationLng,
          },
          'travelMode': _travelMode,
          'language': language,
        },
      );

      if (response != null && response['error'] != null) {
        // Exibir mensagem amigável ao usuário
        if (mounted) {
          SnackBarHelper.showWarning(context, response['error']);
        }
        setState(() {
          _durationMinutes = null;
          _durationText = null;
          _distanceText = null;
          _steps = [];
          _polylines = {};
        });
        return;
      }

      if (response != null) {
        final durationSeconds = response['duration'] ?? 0;
        _durationMinutes = response['duration'] != null
            ? (durationSeconds / 60).round()
            : null;
        _durationText =
            response['durationText'] ??
            (_durationMinutes != null ? '$_durationMinutes min' : null);
        _distanceText = response['distanceText'] ?? '';

        // Parse steps
        if (response['steps'] != null) {
          _steps = (response['steps'] as List)
              .map((s) => RouteStep.fromJson(s))
              .toList();
        }

        // Desenhar polyline
        if (response['polyline'] != null) {
          final decodedPoints = _decodePolyline(response['polyline']);

          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: decodedPoints,
                color: _getTransportColor(_travelMode),
                width: 5,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            };
          });

          // Adicionar marcador de transporte no meio da rota
          if (decodedPoints.length > 1) {
            final midPoint = decodedPoints[decodedPoints.length ~/ 2];
            final transportIcon = await _createTransportMarkerIcon(_travelMode);

            setState(() {
              // Remover marcador de transporte antigo e adicionar o novo
              final updatedMarkers = _markers
                  .where((m) => m.markerId.value != 'transport')
                  .toSet();
              updatedMarkers.add(
                Marker(
                  markerId: const MarkerId('transport'),
                  position: midPoint,
                  icon: transportIcon,
                  anchor: const Offset(0.5, 0.5),
                ),
              );
              _markers = updatedMarkers;
            });
          }

          // Ajustar câmera para mostrar toda a rota
          _fitMapToRoute(decodedPoints);
        }
      }
    } catch (e) {
      print('Error calculating route: $e');
    }
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  // Diferentes tonalidades de verde para cada tipo de transporte
  Color _getTransportColor(String transportMode) {
    switch (transportMode) {
      case 'walking':
        return const Color(0xFF4CAF50); // Verde médio - caminhada
      case 'driving':
        return const Color(0xFF1B5E20); // Verde escuro - carro
      case 'transit':
        return const Color(0xFF66BB6A); // Verde claro - transporte público
      case 'bicycling':
        return const Color(0xFF81C784); // Verde mais claro - bicicleta
      default:
        return AppColors.primary; // Default teal
    }
  }

  // Etiqueta do tipo de transporte
  String _getTransportLabel(String transportMode) {
    switch (transportMode) {
      case 'walking':
        return 'trip_details.transport.walking'.tr();
      case 'driving':
        return 'trip_details.transport.driving'.tr();
      case 'transit':
        return 'trip_details.transport.transit'.tr();
      case 'bicycling':
        return 'trip_details.transport.bicycling'.tr();
      default:
        return 'trip_details.transport.walking'.tr();
    }
  }

  // Gerar e compartilhar rota em PDF
  Future<void> _downloadRoute() async {
    if (_steps.isEmpty && !_isFlightMode) {
      SnackBarHelper.showWarning(
        context,
        'trip_details.pdf.no_route_available'.tr(),
      );
      return;
    }

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      // Capturar screenshot do mapa
      Uint8List? mapSnapshot;
      if (_mapController != null && _markers.isNotEmpty) {
        // Calcular bounds para mostrar todos os marcadores
        double minLat = double.infinity;
        double maxLat = -double.infinity;
        double minLng = double.infinity;
        double maxLng = -double.infinity;

        for (final marker in _markers) {
          if (marker.position.latitude < minLat)
            minLat = marker.position.latitude;
          if (marker.position.latitude > maxLat)
            maxLat = marker.position.latitude;
          if (marker.position.longitude < minLng)
            minLng = marker.position.longitude;
          if (marker.position.longitude > maxLng)
            maxLng = marker.position.longitude;
        }

        // Também incluir pontos da polyline
        for (final polyline in _polylines) {
          for (final point in polyline.points) {
            if (point.latitude < minLat) minLat = point.latitude;
            if (point.latitude > maxLat) maxLat = point.latitude;
            if (point.longitude < minLng) minLng = point.longitude;
            if (point.longitude > maxLng) maxLng = point.longitude;
          }
        }

        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        // Ajustar câmara para mostrar todos os pontos
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 60),
        );

        // Aguardar a animação terminar
        await Future.delayed(const Duration(milliseconds: 800));

        mapSnapshot = await _mapController!.takeSnapshot();
      }

      final pdf = pw.Document();

      // Página do mapa (se disponível)
      if (mapSnapshot != null) {
        final mapImage = pw.MemoryImage(mapSnapshot);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Cabeçalho
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    margin: const pw.EdgeInsets.only(bottom: 24),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#7ED9C8'),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(12),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'trip_details.directions'.tr(),
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          widget.destinationName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            color: PdfColors.white,
                          ),
                        ),
                        if (_distanceText != null && _durationText != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '$_distanceText • $_durationText',
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Mapa
                  pw.Expanded(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(12),
                        ),
                        border: pw.Border.all(
                          color: PdfColor.fromHex('#E0E0E0'),
                          width: 2,
                        ),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 12,
                        verticalRadius: 12,
                        child: pw.Image(mapImage, fit: pw.BoxFit.cover),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  // Rodapé
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 12),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey300, width: 1),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'trip_details.pdf.generated_by'.tr(),
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      // Páginas das direções
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              margin: const pw.EdgeInsets.only(bottom: 24),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#7ED9C8'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'trip_details.directions'.tr(),
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    widget.destinationName,
                    style: pw.TextStyle(fontSize: 18, color: PdfColors.white),
                  ),
                  if (_distanceText != null && _durationText != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '$_distanceText • $_durationText',
                      style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                    ),
                  ],
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${'trip_details.pdf.transport_type'.tr()} ${_getTransportLabel(_travelMode)}',
                    style: pw.TextStyle(
                      fontSize: 13,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 12),
              margin: const pw.EdgeInsets.only(top: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'trip_details.pdf.generated_by'.tr(),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    '${context.pageNumber}/${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return _steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColor.fromHex('#E0E0E0'),
                    width: 1,
                  ),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 32,
                      height: 32,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#7ED9C8'),
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '${index + 1}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            step.instruction,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (step.distanceText.isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Text(
                              step.distanceText,
                              style: const pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        ),
      );

      // Fechar loading
      if (mounted) Navigator.pop(context);

      // Compartilhar PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            '${'trip_details.pdf.filename_directions'.tr()}_${widget.destinationName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      // Fechar loading
      if (mounted) Navigator.pop(context);

      if (mounted) {
        SnackBarHelper.showError(
          context,
          '${'trip_details.pdf.error_generating_pdf'.tr()}: $e',
        );
      }
    }
  }

  void _startPositionTracking() {
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) async {
          _currentPosition = position;
          await _createMarkers();
        });
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  void _changeTravelMode(String mode) async {
    setState(() {
      _travelMode = mode;
      _isLoading = true;
    });

    // Save transport mode to backend if we have an itinerary item ID
    if (widget.itineraryItemId != null) {
      try {
        await _apiService.put(
          '/itinerary-items/${widget.itineraryItemId}',
          body: {'transportMode': mode},
        );
        print('Transport mode saved: $mode');

        // Show success feedback
        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            AppConstants.transportModeUpdated.tr(),
          );
        }
      } catch (e) {
        print('Error saving transport mode: $e');
      }
    }

    await _createMarkers();
    await _calculateRoute();
    setState(() => _isLoading = false);
  }

  IconData _getTravelModeIcon(String mode) {
    switch (mode) {
      case 'walking':
        return Icons.directions_walk;
      case 'transit':
        return Icons.directions_transit;
      case 'bicycling':
        return Icons.directions_bike;
      case 'flight':
        return Icons.flight;
      case 'driving':
      default:
        return Icons.directions_car;
    }
  }

  IconData _getStepIcon(String travelMode) {
    final mode = travelMode.toLowerCase();
    switch (mode) {
      case 'walking':
        return Icons.directions_walk;
      case 'transit':
      case 'subway':
      case 'train':
      case 'tram':
        return Icons.directions_transit;
      case 'bus':
        return Icons.directions_bus;
      case 'bicycling':
        return Icons.directions_bike;
      case 'ferry':
        return Icons.directions_boat;
      case 'driving':
      default:
        return Icons.turn_right; // Use turn icon for driving steps
    }
  }

  String _formatTravelTime(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${mins}min';
  }

  // Abrir Google Maps ao clicar num marker
  Future<void> _openInGoogleMaps(double lat, double lng, String label) async {
    // Preferir pesquisar pelo nome/endereço (label). Se não houver label, usar coordenadas.
    final query = (label.trim().isNotEmpty)
        ? Uri.encodeComponent(label)
        : '$lat,$lng';
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          SnackBarHelper.showError(context, AppConstants.couldNotOpenMaps.tr());
        }
      }
    } catch (e) {
      print('Error opening Google Maps: $e');
      if (mounted) {
        SnackBarHelper.showError(
          context,
          '${AppConstants.errorOpeningMaps.tr()}: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        _closeNavigation();
        return false; // We handle the pop ourselves
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            onPressed: _closeNavigation,
          ),
          title: Text(
            AppConstants.directions.tr(),
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.download,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              onPressed: _downloadRoute,
            ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: isDark ? AppColors.grey800 : Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _initializeNavigation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(AppConstants.retry.tr()),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  // Mapa
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        widget.destinationLat,
                        widget.destinationLng,
                      ),
                      zoom: 14,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (_currentPosition != null) {
                        _fitMapToRoute([
                          LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          LatLng(widget.destinationLat, widget.destinationLng),
                        ]);
                      }
                    },
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled:
                        false, // Don't show user's current location
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),

                  // Loading overlay
                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                  // Painel inferior com informações (Draggable)
                  DraggableScrollableSheet(
                    initialChildSize: 0.35,
                    minChildSize: 0.15,
                    maxChildSize: 0.75,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          children: [
                            // Handle
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 8,
                                ),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.grey800
                                      : AppColors.grey200,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),

                            // Seletores de modo de transporte
                            if (!_isFlightMode)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildModeButton(
                                      'walking',
                                      Icons.directions_walk,
                                      isDark,
                                    ),
                                    _buildModeButton(
                                      'driving',
                                      Icons.directions_car,
                                      isDark,
                                    ),
                                    _buildModeButton(
                                      'transit',
                                      Icons.directions_transit,
                                      isDark,
                                    ),
                                    _buildModeButton(
                                      'bicycling',
                                      Icons.directions_bike,
                                      isDark,
                                    ),
                                  ],
                                ),
                              ),

                            // Informação de voo
                            if (_isFlightMode &&
                                _departureAirport != null &&
                                _arrivalAirport != null) ...[
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Rota do voo
                                      Row(
                                        children: [
                                          // Aeroporto de partida
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange
                                                        .withOpacity(0.2),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.flight_takeoff,
                                                    color: Colors.orange,
                                                    size: 24,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  _departureAirport!.code,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppColors
                                                              .textPrimaryDark
                                                        : AppColors
                                                              .textPrimaryLight,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  _departureAirport!.name,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppColors
                                                              .textSecondaryDark
                                                        : AppColors
                                                              .textSecondaryLight,
                                                    fontSize: 11,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Linha do voo
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Container(
                                                        height: 2,
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Colors.orange
                                                                  .withOpacity(
                                                                    0.3,
                                                                  ),
                                                              Colors.orange,
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons.flight,
                                                      color: Colors.orange,
                                                      size: 20,
                                                    ),
                                                    Expanded(
                                                      child: Container(
                                                        height: 2,
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Colors.orange,
                                                              Colors.orange
                                                                  .withOpacity(
                                                                    0.3,
                                                                  ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatTravelTime(
                                                    _flightDurationMinutes ?? 0,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.orange,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  _totalFlightDistance ?? '',
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppColors
                                                              .textSecondaryDark
                                                        : AppColors
                                                              .textSecondaryLight,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Aeroporto de chegada
                                          Expanded(
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.purple
                                                        .withOpacity(0.2),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.flight_land,
                                                    color: Colors.purple,
                                                    size: 24,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  _arrivalAirport!.code,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppColors
                                                              .textPrimaryDark
                                                        : AppColors
                                                              .textPrimaryLight,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  _arrivalAirport!.name,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppColors
                                                              .textSecondaryDark
                                                        : AppColors
                                                              .textSecondaryLight,
                                                    fontSize: 11,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Rota até ao aeroporto
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getTravelModeIcon(_travelMode),
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${'trip_details.pdf.to'.tr()} ${_departureAirport!.name}',
                                            style: TextStyle(
                                              color: isDark
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimaryLight,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (_durationText != null &&
                                              _distanceText != null)
                                            Text(
                                              '$_durationText • $_distanceText',
                                              style: TextStyle(
                                                color: isDark
                                                    ? AppColors
                                                          .textSecondaryDark
                                                    : AppColors
                                                          .textSecondaryLight,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (_durationMinutes != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Text(
                                          _formatTravelTime(_durationMinutes!),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // Destino e tempo (modo normal)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getTravelModeIcon(_travelMode),
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.destinationName,
                                            style: TextStyle(
                                              color: isDark
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimaryLight,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (_durationText != null &&
                                              _distanceText != null)
                                            Text(
                                              '$_durationText • $_distanceText',
                                              style: TextStyle(
                                                color: isDark
                                                    ? AppColors
                                                          .textSecondaryDark
                                                    : AppColors
                                                          .textSecondaryLight,
                                                fontSize: 14,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (_durationMinutes != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          _formatTravelTime(_durationMinutes!),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],

                            // Lista de passos
                            if (_steps.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  children: _steps.map((step) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                _getStepIcon(step.travelMode),
                                                color: AppColors.primary,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  step.instruction,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppColors
                                                              .textPrimaryDark
                                                        : AppColors
                                                              .textPrimaryLight,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${step.distanceText} • ${step.durationText}',
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppColors
                                                              .textSecondaryDark
                                                        : AppColors
                                                              .textSecondaryLight,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    },
                  ),

                  // Botão de centralizar
                  Positioned(
                    right: 16,
                    bottom: 320,
                    child: FloatingActionButton.small(
                      onPressed: () {
                        if (_currentPosition != null &&
                            _mapController != null) {
                          _mapController!.animateCamera(
                            CameraUpdate.newLatLng(
                              LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                            ),
                          );
                        }
                      },
                      backgroundColor: isDark
                          ? AppColors.surfaceDark
                          : Colors.white,
                      child: Icon(Icons.my_location, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildModeButton(String mode, IconData icon, bool isDark) {
    final isSelected = _travelMode == mode;
    return GestureDetector(
      onTap: () => _changeTravelMode(mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.grey800 : AppColors.grey100),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected
              ? Colors.white
              : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          size: 24,
        ),
      ),
    );
  }
}

class RouteStep {
  final String instruction;
  final String distanceText;
  final String durationText;
  final int distance;
  final int duration;
  final String travelMode;

  RouteStep({
    required this.instruction,
    required this.distanceText,
    required this.durationText,
    required this.distance,
    required this.duration,
    this.travelMode = 'walking',
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      instruction: json['instruction'] ?? '',
      distanceText: json['distanceText'] ?? '',
      durationText: json['durationText'] ?? '',
      distance: json['distance'] ?? 0,
      duration: json['duration'] ?? 0,
      travelMode: json['travelMode'] ?? json['travel_mode'] ?? 'walking',
    );
  }
}

class AirportInfo {
  final String name;
  final String code;
  final double latitude;
  final double longitude;

  AirportInfo({
    required this.name,
    required this.code,
    required this.latitude,
    required this.longitude,
  });
}
