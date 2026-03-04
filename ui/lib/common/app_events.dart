import 'dart:async';

class AppEvents {
  // Broadcast stream para eventos de importação de trip
  static final StreamController<Map<String, dynamic>> _tripImportedController = StreamController.broadcast();
  // Broadcast stream para eventos gerais de alteração nas trips (import, delete, edit)
  static final StreamController<void> _tripsChangedController = StreamController.broadcast();

  static Stream<Map<String, dynamic>> get onTripImported => _tripImportedController.stream;
  static Stream<void> get onTripsChanged => _tripsChangedController.stream;

  static void emitTripImported(Map<String, dynamic> trip) {
    try {
      _tripImportedController.add(trip);
    } catch (_) {}
  }

  static void emitTripsChanged() {
    try {
      _tripsChangedController.add(null);
    } catch (_) {}
  }

  static void dispose() {
    _tripImportedController.close();
    _tripsChangedController.close();
  }
}
