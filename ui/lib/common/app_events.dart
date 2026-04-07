import 'dart:async';

class AppEvents {
  // Broadcast stream para eventos de importação de trip
  static final StreamController<Map<String, dynamic>> _tripImportedController =
      StreamController.broadcast();
  // Broadcast stream para eventos gerais de alteração nas trips (import, delete, edit)
  static final StreamController<void> _tripsChangedController =
      StreamController.broadcast();
  // Broadcast stream para eventos de alteração na subscrição (upgrade/downgrade)
  static final StreamController<void> _subscriptionChangedController =
      StreamController.broadcast();
  // Broadcast stream para alterações no rascunho da nova viagem
  static final StreamController<void> _draftChangedController =
      StreamController.broadcast();

  static Stream<Map<String, dynamic>> get onTripImported =>
      _tripImportedController.stream;
  static Stream<void> get onTripsChanged => _tripsChangedController.stream;
  static Stream<void> get onSubscriptionChanged =>
      _subscriptionChangedController.stream;
  static Stream<void> get onDraftChanged => _draftChangedController.stream;

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

  static void emitSubscriptionChanged() {
    try {
      _subscriptionChangedController.add(null);
    } catch (_) {}
  }

  static void emitDraftChanged() {
    try {
      _draftChangedController.add(null);
    } catch (_) {}
  }

  static void dispose() {
    _tripImportedController.close();
    _tripsChangedController.close();
    _subscriptionChangedController.close();
    _draftChangedController.close();
  }
}
