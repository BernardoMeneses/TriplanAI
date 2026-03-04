import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _notificationsEnabledKey = 'notifications_enabled';
  bool _isInitialized = false;

  /// Inicializa o serviço de notificações
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Inicializar timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Lisbon'));

    // Configurações para Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configurações para iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// Callback quando a notificação é clicada
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notificação clicada: ${response.payload}');
    }
    // Aqui pode navegar para a página da viagem usando o payload (trip_id)
  }

  /// Pedir permissões para notificações (iOS e Android 13+)
  Future<bool> requestPermissions() async {
    if (!_isInitialized) await initialize();

    // Pedir permissões para iOS
    final iosImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    
    if (iosImplementation != null) {
      final bool? result = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? false;
    }

    // Pedir permissões para Android 13+ (API 33+)
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      // Request POST_NOTIFICATIONS permission for Android 13+
      final bool? result = await androidImplementation.requestNotificationsPermission();
      return result ?? true;
    }

    return true;
  }

  /// Verifica se as notificações estão ativas
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true; // Por padrão ativo
  }

  /// Ativa/desativa notificações
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);

    if (!enabled) {
      // Se desativar, cancela todas as notificações agendadas
      await cancelAllNotifications();
    }
  }

  /// Agenda notificação 1 dia antes da viagem
  Future<void> scheduleTripNotification({
    required int tripId,
    required String destination,
    required DateTime startDate,
  }) async {
    if (!_isInitialized) await initialize();

    // Verificar se notificações estão ativas
    final enabled = await areNotificationsEnabled();
    if (!enabled) return;

    // Calcular data da notificação (1 dia antes às 9:00 da manhã)
    final notificationDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day - 1,
      9, // 9:00 AM
      0,
    );

    // Não agendar se a data já passou
    if (notificationDate.isBefore(DateTime.now())) {
      if (kDebugMode) {
        print('Data da notificação já passou: $notificationDate');
      }
      return;
    }

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      notificationDate,
      tz.local,
    );

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'trip_reminders',
      'Lembretes de Viagem',
      channelDescription: 'Notificações para lembrar de viagens próximas',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      tripId, // ID único baseado no trip_id
      'Viagem Amanhã! ✈️',
      'A sua viagem a $destination irá começar amanhã',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'trip_$tripId', // Para identificar a viagem quando clicar
    );

    if (kDebugMode) {
      print('Notificação agendada para $scheduledDate - Viagem: $destination');
    }
  }

  /// Cancela notificação de uma viagem específica
  Future<void> cancelTripNotification(int tripId) async {
    await _flutterLocalNotificationsPlugin.cancel(tripId);
    if (kDebugMode) {
      print('Notificação cancelada para viagem ID: $tripId');
    }
  }

  /// Cancela todas as notificações
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    if (kDebugMode) {
      print('Todas as notificações foram canceladas');
    }
  }

  /// Obtém lista de notificações pendentes
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// Mostra notificação imediata (para testes)
  Future<void> showTestNotification() async {
    if (!_isInitialized) await initialize();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Testes',
      channelDescription: 'Canal para testes de notificações',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Teste de Notificação',
      'As notificações estão a funcionar! 🎉',
      details,
    );
  }
}
