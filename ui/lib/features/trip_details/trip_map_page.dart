import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../common/app_colors.dart';
import '../../common/constants/app_constants.dart';
import '../../services/itinerary_items_service.dart';
import '../../services/api_service.dart';
import '../../services/subscription_service.dart';
import '../../shared/widgets/upgrade_dialog.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../../shared/widgets/snackbar_helper.dart';
import 'dart:math' show max;

class TripMapPage extends StatefulWidget {
  final String tripId;
  final int dayNumber;
  final List<ItineraryItem> activities;

  const TripMapPage({
    super.key,
    required this.tripId,
    required this.dayNumber,
    required this.activities,
  });

  @override
  State<TripMapPage> createState() => _TripMapPageState();
}

class _TripMapPageState extends State<TripMapPage> {
  GoogleMapController? _mapController;
  final ApiService _apiService = ApiService();

  List<ItineraryItem> _allActivities = [];
  bool _isLoading = true;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<RouteSegment> _routeSegments = [];
  int? _selectedActivityIndex;

  @override
  void initState() {
    super.initState();
    _allActivities = widget.activities;
    _isLoading = false;
    _createMarkersAndRoutes();
  }

  void _createMarkersAndRoutes() async {
    print('Creating markers and routes for ${_allActivities.length} activities');

    final Set<Marker> markers = {};
    final List<LatLng> points = [];

    for (int i = 0; i < _allActivities.length; i++) {
      final activity = _allActivities[i];

      if (activity.place?.latitude != null && activity.place?.longitude != null) {
        final position = LatLng(
          activity.place!.latitude!,
          activity.place!.longitude!,
        );
        points.add(position);

        print('Activity $i: ${activity.title} at $position');

        // Criar marcador customizado com número em círculo branco com borda
        final icon = await _createNumberMarkerIcon(i + 1);
        final lat = activity.place!.latitude!;
        final lng = activity.place!.longitude!;
        final title = activity.title;
        markers.add(
          Marker(
            markerId: MarkerId(activity.id),
            position: position,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(
              title: '${i + 1}. $title',
              snippet: 'trip_details.tap_to_open_maps'.tr(),
              onTap: () => _openInGoogleMaps(lat, lng, title),
            ),
          ),
        );
      }
    }

    print('Created ${markers.length} activity markers');

    setState(() {
      _markers = markers;
    });

    // Animar câmera para mostrar todos os pontos
    if (points.isNotEmpty && _mapController != null) {
      _fitMapToRoute(points);
    }

    // Buscar rotas entre os pontos
    if (points.length >= 2) {
      print('Fetching routes for ${points.length} points');
      _fetchRoutes(points);
    } else {
      print('Not enough points to create routes');
    }
  }

  Future<void> _fetchRoutes(List<LatLng> points) async {
    try {
      setState(() => _isLoading = true);

      // Preparar os pontos para enviar à API com seus modos de transporte
      final pointsData = _allActivities
          .where((a) => a.place?.latitude != null && a.place?.longitude != null)
          .map((a) => {
        'lat': a.place!.latitude!,
        'lng': a.place!.longitude!,
        'name': a.title,
        'transportMode': a.transportMode ?? 'walking', // Include transport mode
      })
          .toList();

      print('Sending ${pointsData.length} points to API');
      for (var i = 0; i < pointsData.length; i++) {
        print('Point $i: ${pointsData[i]["name"]} - ${pointsData[i]["transportMode"]}');
      }

      if (pointsData.length < 2) {
        setState(() => _isLoading = false);
        return;
      }

      // Chamar API do backend para obter rotas com modos de transporte específicos
      final language = context.locale.languageCode;
      final response = await _apiService.post('/routes/multi-segment', body: {
        'points': pointsData,
        'language': language,
      });

      print('API Response received');
      print('Response type: ${response.runtimeType}');
      print('Response: $response');

      if (response != null && response['routes'] != null) {
        final routes = response['routes'] as List;
        print('Number of routes: ${routes.length}');

        final Set<Polyline> polylines = {};
        final Set<Marker> transportMarkers = {};
        final List<RouteSegment> segments = [];

        for (var route in routes) {
          final mode = route['mode'] as String;
          print('Route mode: $mode');
          final polylineData = route['polyline'];

          // Se temos polyline, decodificar e adicionar
          if (polylineData != null && polylineData['points'] != null) {
            final decodedPoints = _decodePolyline(polylineData['points']);
            final transportColor = _getTransportColor(mode);

            // Polylines com cores diferentes por tipo de transporte (gama verde)
            polylines.add(
              Polyline(
                polylineId: PolylineId('route_${route['segmentIndex']}'),
                points: decodedPoints,
                color: transportColor,
                width: 5,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            );

            // Adicionar marcador de transporte no meio da rota com ícone personalizado
            if (decodedPoints.length > 1) {
              final midPoint = decodedPoints[decodedPoints.length ~/ 2];

              // Escolher ícone baseado no modo de transporte
              IconData iconData;
              final modeLower = mode.toLowerCase();

              if (modeLower == 'bicycling') {
                iconData = Icons.directions_bike;
              } else if (modeLower == 'transit') {
                // Verificar o tipo específico de transit se disponível
                final transitDetails = route['transit_details'];
                if (transitDetails != null && transitDetails['line'] != null) {
                  final vehicleType = transitDetails['line']['vehicle']?['type']?.toString().toLowerCase() ?? 'transit';

                  if (vehicleType.contains('subway') || vehicleType.contains('metro')) {
                    iconData = Icons.subway;
                  } else if (vehicleType.contains('rail') || vehicleType.contains('train')) {
                    iconData = Icons.train;
                  } else if (vehicleType.contains('bus')) {
                    iconData = Icons.directions_bus;
                  } else {
                    iconData = Icons.directions_transit;
                  }
                } else {
                  iconData = Icons.directions_transit;
                }
              } else if (modeLower == 'driving') {
                iconData = Icons.directions_car;
              } else {
                iconData = Icons.directions_walk;
              }

              // Criar ícone customizado com a cor do transporte
              final icon = await _createTransportMarkerIcon(iconData, transportColor);

              print('Creating transport marker at $midPoint with mode $mode');

              transportMarkers.add(
                Marker(
                  markerId: MarkerId('transport_${route['segmentIndex']}'),
                  position: midPoint,
                  icon: icon,
                  anchor: const Offset(0.5, 0.5),
                  zIndex: 2,
                  onTap: () {
                    print('Transport marker tapped for segment ${route['segmentIndex']}');
                    // Get the activity index for this transport segment
                    final segmentIndex = route['segmentIndex'] as int;
                    if (segmentIndex < _allActivities.length) {
                      _showTransportModeDialog(segmentIndex, mode);
                    }
                  },
                ),
              );
            }
          }

          // Adicionar segmento de rota
          segments.add(
            RouteSegment(
              type: _getTransportType(mode),
              duration: route['duration']?['text'] ?? 'Unknown',
              distance: route['distance']?['text'] ?? 'Unknown',
              instructions: 'Go to ${route['destination']['name']}',
            ),
          );
        }

        if (mounted) {
          setState(() {
            _polylines = polylines;
            // Keep all activity markers (those with activity IDs) and add transport markers
            final activityMarkers = _markers.where((m) =>
                _allActivities.any((a) => a.id == m.markerId.value)
            ).toSet();
            _markers = {...activityMarkers, ...transportMarkers};
            _routeSegments = segments;
            _isLoading = false;
          });
          print('Updated map with ${polylines.length} polylines, ${_markers.length} total markers (${transportMarkers.length} transport)');
        }
      } else {
        // Fallback: criar linhas simples se a API falhar
        print('No routes from API, creating simple lines');
        final Set<Polyline> polylines = {};
        final List<RouteSegment> segments = [];

        for (int i = 0; i < points.length - 1; i++) {
          final transportMode = i < _allActivities.length - 1 
              ? (_allActivities[i + 1].transportMode ?? 'walking') 
              : 'walking';
          polylines.add(
            Polyline(
              polylineId: PolylineId('route_$i'),
              points: [points[i], points[i + 1]],
              color: _getTransportColor(transportMode),
              width: 5,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          );

          segments.add(
            RouteSegment(
              type: TransportType.walking,
              duration: 'Unknown',
              distance: 'Unknown',
              instructions: 'Go to ${_allActivities[i + 1].title}',
            ),
          );
        }

        if (mounted) {
          setState(() {
            _polylines = polylines;
            _routeSegments = segments;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching routes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  TransportType _getTransportType(String mode) {
    switch (mode.toLowerCase()) {
      case 'walking':
        return TransportType.walking;
      case 'bicycling':
        return TransportType.bicycling;
      case 'transit':
        return TransportType.transit;
      case 'subway':
      case 'metro':
        return TransportType.subway;
      case 'train':
      case 'rail':
        return TransportType.train;
      case 'bus':
        return TransportType.bus;
      case 'driving':
        return TransportType.driving;
      default:
        return TransportType.walking;
    }
  }

  // Diferentes tonalidades de verde para cada tipo de transporte
  Color _getTransportColor(String transportMode) {
    final mode = transportMode.toLowerCase();
    switch (mode) {
      case 'walking':
        return const Color(0xFF4CAF50); // Verde médio - caminhada
      case 'driving':
        return const Color(0xFF1B5E20); // Verde escuro - carro
      case 'transit':
      case 'subway':
      case 'train':
      case 'bus':
        return const Color(0xFF66BB6A); // Verde claro - transporte público
      case 'bicycling':
        return const Color(0xFF81C784); // Verde mais claro - bicicleta
      default:
        return const Color(0xFF4CAF50); // Default verde médio
    }
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (points.isEmpty) return;

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

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  // Abrir Google Maps ao clicar num marker
  Future<void> _openInGoogleMaps(double lat, double lng, String label) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    
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
    }
  }

  // Show dialog to change transport mode
  Future<void> _showTransportModeDialog(int activityIndex, String currentMode) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final modes = [
      {'value': 'walking', 'label': 'Walking', 'icon': Icons.directions_walk},
      {'value': 'driving', 'label': 'Driving', 'icon': Icons.directions_car},
      {'value': 'transit', 'label': 'Transit', 'icon': Icons.directions_transit},
      {'value': 'bicycling', 'label': 'Bicycling', 'icon': Icons.directions_bike},
    ];

    final selectedMode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: Text(
          AppConstants.transportMode.tr(),
          style: TextStyle(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: modes.map((mode) {
            final isSelected = mode['value'] == currentMode;
            return ListTile(
              leading: Icon(
                mode['icon'] as IconData,
                color: isSelected ? AppColors.primary : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              title: Text(
                mode['label'] as String,
                style: TextStyle(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected ? Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () => Navigator.pop(context, mode['value']),
            );
          }).toList(),
        ),
      ),
    );

    if (selectedMode != null && selectedMode != currentMode) {
      await _updateTransportMode(activityIndex, selectedMode);
    }
  }

  // Update transport mode for an activity
  Future<void> _updateTransportMode(int activityIndex, String newMode) async {
    try {
      final activity = _allActivities[activityIndex];

      print('Updating transport mode for ${activity.title} to $newMode');

      await _apiService.put(
        '/itinerary-items/${activity.id}',
        body: {'transportMode': newMode},
      );

      print('Transport mode saved to backend');

      // Atualizar a lista local com o novo transportMode
      // Como ItineraryItem e imutavel, recriamos o item com o novo modo
      _allActivities[activityIndex] = activity.copyWith(transportMode: newMode);

      if (mounted) {
        SnackBarHelper.showSuccess(context, '${AppConstants.transportModeUpdated.tr()} $newMode');

        // Recriar marcadores e rotas com os dados atualizados
        _createMarkersAndRoutes();
      }
    } catch (e) {
      print('Error updating transport mode: $e');
      if (mounted) {
        SnackBarHelper.showError(context, '${AppConstants.errorUpdatingTransport.tr()}: $e');
      }
    }
  }

  // Criar ícone customizado para marcadores de transporte com cor específica
  Future<BitmapDescriptor> _createTransportMarkerIcon(IconData iconData, Color transportColor) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    
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
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 32,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: transportColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // Criar ícone customizado para marcadores de lugares com números
  Future<BitmapDescriptor> _createNumberMarkerIcon(int number, {double size = 80}) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = AppColors.primaryDark;

    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2,
      paint,
    );

    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size * 3 / 80).clamp(1.5, 3.0);
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      borderPaint,
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: number.toString(),
      style: TextStyle(
        fontSize: size * 0.5,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  String _getTransportLabel(String? mode) {
    switch (mode) {
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

  Future<void> _downloadItinerary() async {
    // Check PDF export permission
    final subStatus = await SubscriptionService().getStatus();
    if (!subStatus.limits.canExportPdf) {
      if (mounted) {
        showUpgradeDialog(
          context: context,
          feature: AppConstants.pdfLockedTitle.tr(),
          description: AppConstants.pdfLockedDesc.tr(),
        );
      }
      return;
    }

    if (_allActivities.isEmpty) {
      SnackBarHelper.showWarning(context, 'trip_details.pdf.no_activities_available'.tr());
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
          if (marker.position.latitude < minLat) minLat = marker.position.latitude;
          if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
          if (marker.position.longitude < minLng) minLng = marker.position.longitude;
          if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
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
        
        // Ajustar câmara para mostrar todos os pontos (movimento imediato)
        final latDiff = maxLat - minLat;
        final lngDiff = maxLng - minLng;
        final span = max(latDiff, lngDiff);

        // 1. Mover câmara PRIMEIRO com os bounds reais + padding generoso
        //    O padding (px) garante que os marcadores nas extremidades não ficam cortados
        if (latDiff < 0.0001 && lngDiff < 0.0001) {
          await _mapController!.moveCamera(
            CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 15),
          );
        } else {
          final bounds = LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          );
          await _mapController!.moveCamera(
            CameraUpdate.newLatLngBounds(bounds, 100),
          );
        }

        // 2. Substituir marcadores por versões menores para o PDF
        //    (tamanho escala linearmente com o span; mín. 40 px para continuar legível)
        //    Os ícones de transporte são omitidos – as polylines coloridas já os representam
        final markerSize = (80.0 - (span - 0.1) * 20.0).clamp(40.0, 80.0);
        final originalMarkers = Set<Marker>.from(_markers);
        final pdfMarkers = <Marker>{};
        for (int i = 0; i < _allActivities.length; i++) {
          final activity = _allActivities[i];
          if (activity.place?.latitude != null && activity.place?.longitude != null) {
            final icon = await _createNumberMarkerIcon(i + 1, size: markerSize);
            pdfMarkers.add(Marker(
              markerId: MarkerId(activity.id),
              position: LatLng(activity.place!.latitude!, activity.place!.longitude!),
              icon: icon,
              anchor: const Offset(0.5, 0.5),
            ));
          }
        }
        if (mounted) setState(() => _markers = pdfMarkers);

        // 3. Aguardar câmara + tiles + novos marcadores renderizarem
        await Future.delayed(const Duration(milliseconds: 1800));

        mapSnapshot = await _mapController!.takeSnapshot();

        // 4. Restaurar marcadores originais
        if (mounted) setState(() => _markers = originalMarkers);
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
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '${'trip_details.itinerary'.tr()} - ${'common.day'.tr()} ${widget.dayNumber}',
                                style: pw.TextStyle(
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                '${_allActivities.length} ${'trip_details.activities'.tr().toLowerCase()}',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  color: PdfColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Mapa
                  pw.Expanded(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                        border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0'), width: 2),
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
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
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
      
      // Páginas do roteiro
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
                    '${'trip_details.itinerary'.tr()} - ${'common.day'.tr()} ${widget.dayNumber}',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${_allActivities.length} ${'trip_details.activities'.tr().toLowerCase()}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
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
            return _allActivities.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              
              // Obter informação de transporte para a PRÓXIMA atividade
              final nextItem = index < _allActivities.length - 1 ? _allActivities[index + 1] : null;
              
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0'), width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Número e título
                    pw.Row(
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
                                item.title,
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (item.place?.address != null) ...[
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  item.place!.address!,
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
                    pw.SizedBox(height: 12),
                    // Detalhes (horário, duração)
                    pw.Row(
                      children: [
                        if (item.startTime != null) ...[
                          pw.Text(
                            '⏰ ${item.startTime!.substring(0, 5)}',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey800,
                            ),
                          ),
                          pw.SizedBox(width: 16),
                        ],
                        if (item.durationMinutes != null) ...[
                          pw.Text(
                            '⌛ ${item.durationMinutes} min',
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Descrição (se existir)
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Text(
                        item.description!,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                    // Badge de transporte para a PRÓXIMA atividade (no fundo do card atual)
                    if (nextItem != null && nextItem.travelTimeFromPreviousText != null) ...[
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#E8F5E9'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(color: PdfColor.fromHex('#4CAF50'), width: 1),
                        ),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text(
                              '→ ${_getTransportLabel(nextItem.transportMode)} - ${nextItem.travelTimeFromPreviousText}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColor.fromHex('#2E7D32'),
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            if (nextItem.distanceFromPreviousText != null) ...[
                              pw.Text(
                                ' (${nextItem.distanceFromPreviousText})',
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  color: PdfColor.fromHex('#2E7D32'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
        filename: '${'trip_details.pdf.filename_route'.tr()}_${widget.dayNumber}.pdf',
      );
    } catch (e) {
      // Fechar loading
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        SnackBarHelper.showError(context, '${'trip_details.pdf.error_generating_pdf'.tr()}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Stack(
        children: [
          // Mapa
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _allActivities.isNotEmpty && _allActivities.first.place != null
                  ? LatLng(
                _allActivities.first.place!.latitude ?? 0,
                _allActivities.first.place!.longitude ?? 0,
              )
                  : const LatLng(0, 0),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false, // Disable showing user's current location
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_allActivities.isNotEmpty) {
                final points = _allActivities
                    .where((a) => a.place?.latitude != null && a.place?.longitude != null)
                    .map((a) => LatLng(a.place!.latitude!, a.place!.longitude!))
                    .toList();
                if (points.isNotEmpty) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _fitMapToRoute(points);
                  });
                }
              }
            },
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Day ${widget.dayNumber} Route',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Botão de download
                    GestureDetector(
                      onTap: _downloadItinerary,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.download,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Painel inferior com lista de atividades e rotas
          if (!_isLoading && _allActivities.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.3,
              minChildSize: 0.15,
              maxChildSize: 0.7,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.grey800 : AppColors.grey300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Título
                      Text(
                        AppConstants.yourRoute.tr(),
                        style: TextStyle(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_allActivities.length} ${AppConstants.activities.tr().toLowerCase()}',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Lista de atividades com rotas
                      ..._buildActivityList(isDark),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _buildActivityList(bool isDark) {
    final List<Widget> widgets = [];

    for (int i = 0; i < _allActivities.length; i++) {
      final activity = _allActivities[i];

      // Atividade
      widgets.add(
        _ActivityItem(
          activity: activity,
          number: i + 1,
          isDark: isDark,
          isSelected: _selectedActivityIndex == i,
          onTap: () {
            if (activity.place?.latitude != null && activity.place?.longitude != null) {
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(activity.place!.latitude!, activity.place!.longitude!),
                  15,
                ),
              );
              setState(() {
                _selectedActivityIndex = i;
              });
            }
          },
        ),
      );

      // Rota entre atividades
      if (i < _allActivities.length - 1 && i < _routeSegments.length) {
        widgets.add(
          _RouteSegmentItem(
            segment: _routeSegments[i],
            isDark: isDark,
          ),
        );
      }
    }

    return widgets;
  }
}

class _ActivityItem extends StatelessWidget {
  final ItineraryItem activity;
  final int number;
  final bool isDark;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActivityItem({
    required this.activity,
    required this.number,
    required this.isDark,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : (isDark ? AppColors.grey800 : AppColors.grey100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (activity.startTime != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      activity.startTime!,
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSegmentItem extends StatelessWidget {
  final RouteSegment segment;
  final bool isDark;

  const _RouteSegmentItem({
    required this.segment,
    required this.isDark,
  });

  IconData _getTransportIcon() {
    switch (segment.type) {
      case TransportType.walking:
        return Icons.directions_walk;
      case TransportType.transit:
        return Icons.directions_transit;
      case TransportType.subway:
        return Icons.subway;
      case TransportType.train:
        return Icons.train;
      case TransportType.bus:
        return Icons.directions_bus;
      case TransportType.driving:
        return Icons.directions_car;
      case TransportType.bicycling:
        return Icons.directions_bike;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.grey900 : AppColors.grey200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getTransportIcon(),
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              segment.instructions,
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '${segment.duration} • ${segment.distance}',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

enum TransportType {
  walking,
  transit,
  subway,
  train,
  bus,
  driving,
  bicycling,
}

class RouteSegment {
  final TransportType type;
  final String duration;
  final String distance;
  final String instructions;

  RouteSegment({
    required this.type,
    required this.duration,
    required this.distance,
    required this.instructions,
  });
}
