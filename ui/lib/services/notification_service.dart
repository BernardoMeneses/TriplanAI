import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:easy_localization/easy_localization.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _notificationsEnabledKey = 'notifications_enabled';
  bool _isInitialized = false;

  /// Converte um UUID string num int estável para usar como notification ID
  static int tripIdToNotificationId(String tripId) {
    return tripId.hashCode & 0x7FFFFFFF; // garante positivo
  }

  /// Inicializa o serviço de notificações
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Inicializar timezone data
    tzdata.initializeTimeZones();

    // Detetar timezone do dispositivo
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      if (kDebugMode) {
        print('🕐 Timezone detetada: $timeZoneName');
      }
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Lisbon'));
      if (kDebugMode) {
        print('🕐 Fallback timezone: Europe/Lisbon');
      }
    }

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
  }

  /// Pedir permissões para notificações (iOS e Android 13+)
  Future<bool> requestPermissions() async {
    if (!_isInitialized) await initialize();

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

    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final bool? result = await androidImplementation.requestNotificationsPermission();
      return result ?? true;
    }

    return true;
  }

  /// Verifica se as notificações estão ativas
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  /// Ativa/desativa notificações
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);

    if (!enabled) {
      await cancelAllNotifications();
    }
  }

  /// Agenda notificações para uma viagem:
  /// - 1 dia antes às 09:00 ("Viagem Amanhã!")
  /// - No próprio dia às 08:00 ("A aventura começa hoje!")
  Future<void> scheduleTripNotifications({
    required String tripId,
    required String destination,
    required DateTime startDate,
  }) async {
    if (!_isInitialized) await initialize();

    final enabled = await areNotificationsEnabled();
    if (!enabled) return;

    final baseId = tripIdToNotificationId(tripId);
    final now = tz.TZDateTime.now(tz.local);

    // ── Notificação 1: Dia anterior às 09:00 ──
    final scheduledDayBefore = tz.TZDateTime(
      tz.local,
      startDate.year,
      startDate.month,
      startDate.day - 1,
      9, 0,
    );

    if (scheduledDayBefore.isAfter(now)) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        baseId,
        'notification_messages.day_before_title'.tr(),
        'notification_messages.day_before_body'.tr(namedArgs: {'destination': destination}),
        scheduledDayBefore,
        _buildNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'trip_$tripId',
      );

      if (kDebugMode) {
        print('📅 Notificação dia anterior agendada: $scheduledDayBefore - $destination');
      }
    } else if (kDebugMode) {
      print('⏭️ Notificação dia anterior ignorada (já passou): $scheduledDayBefore');
    }

    // ── Notificação 2: No próprio dia às 08:00 ──
    final scheduledTripDay = tz.TZDateTime(
      tz.local,
      startDate.year,
      startDate.month,
      startDate.day,
      8, 0,
    );

    if (scheduledTripDay.isAfter(now)) {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        baseId + 1,
        'notification_messages.trip_day_title'.tr(),
        'notification_messages.trip_day_body'.tr(namedArgs: {'destination': destination}),
        scheduledTripDay,
        _buildNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'trip_$tripId',
      );

      if (kDebugMode) {
        print('🌅 Notificação dia da viagem agendada: $scheduledTripDay - $destination');
      }
    } else if (kDebugMode) {
      print('⏭️ Notificação dia da viagem ignorada (já passou): $scheduledTripDay');
    }
  }

  /// Constrói detalhes de notificação com textos traduzidos
  NotificationDetails _buildNotificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'trip_reminders',
        'notification_messages.channel_name'.tr(),
        channelDescription: 'notification_messages.channel_description'.tr(),
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Cancela todas as notificações de uma viagem (dia anterior + próprio dia)
  Future<void> cancelTripNotifications(String tripId) async {
    final baseId = tripIdToNotificationId(tripId);
    await _flutterLocalNotificationsPlugin.cancel(baseId);     // dia anterior
    await _flutterLocalNotificationsPlugin.cancel(baseId + 1); // próprio dia
    if (kDebugMode) {
      print('🗑️ Notificações canceladas para viagem: $tripId');
    }
  }

  /// Cancela todas as notificações
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    if (kDebugMode) {
      print('🗑️ Todas as notificações foram canceladas');
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
      'As notificações estão a funcionar!',
      details,
    );
  }
}
