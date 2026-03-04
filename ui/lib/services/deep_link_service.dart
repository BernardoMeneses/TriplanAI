import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:app_links/app_links.dart';
import 'package:triplan_ai_front/services/trip_share_service.dart';
import 'package:triplan_ai_front/services/trips_service.dart';

/// Serviço para gerenciar deep linking e abertura de arquivos compartilhados
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final TripShareService _tripShareService = TripShareService();
  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;
  // App links (custom scheme) listener
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _appLinkStreamSubscription;

  /// Inicializa listeners para arquivos compartilhados (.triplan)
  ///
  /// ⚠️ Deve ser chamado após o primeiro frame (ex: addPostFrameCallback)
    void initialize(
      BuildContext context,
      void Function(Trip trip) onTripImported,
      {void Function(Uri uri)? onAppLink,
      }) {
    // Arquivos compartilhados quando a app estava FECHADA
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        _handleSharedFile(
          context,
          files.first.path,
          onTripImported,
        );
      }
    }).catchError((e) {
      debugPrint('Erro getInitialMedia: $e');
    });

    // Arquivos compartilhados enquanto a app está ABERTA
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
              (List<SharedMediaFile> files) {
            if (files.isNotEmpty) {
              _handleSharedFile(
                context,
                files.first.path,
                onTripImported,
              );
            }
          },
          onError: (err) {
            debugPrint('Erro getMediaStream: $err');
          },
        );

    // --- App links (custom URI scheme) ---
    try {
      // Enquanto app aberta - escutar stream
      _appLinkStreamSubscription = _appLinks.uriLinkStream.listen((uri) {
        if (uri != null) {
          try {
            onAppLink?.call(uri);
          } catch (e) {
            debugPrint('Erro ao tratar app link stream: $e');
          }
        }
      }, onError: (err) {
        debugPrint('Erro app link stream: $err');
      });
    } catch (e) {
      debugPrint('AppLinks não suportado ou erro: $e');
    }
  }

  /// Processa o arquivo compartilhado
  Future<void> _handleSharedFile(
      BuildContext context,
      String filePath,
      void Function(Trip trip) onTripImported,
      ) async {
    // Validar extensão
    if (!filePath.toLowerCase().endsWith('.triplan')) {
      _showSnackBar(
        context,
        'Apenas arquivos .triplan são suportados',
        Colors.orange,
      );
      return;
    }

    // Mostrar loading
    _showLoading(context);

    try {
      // Importar viagem
      final Trip trip =
      await _tripShareService.importTripFromFile(filePath);

      // Fechar loading
      _closeLoading(context);

      // Sucesso
      _showSnackBar(
        context,
        'Viagem "${trip.title}" importada com sucesso!',
        Colors.green,
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () => onTripImported(trip),
        ),
      );

      // Callback
      onTripImported(trip);
    } catch (e) {
      // Garantir que o loading fecha
      _closeLoading(context);

      _showSnackBar(
        context,
        'Erro ao importar viagem: $e',
        Colors.red,
      );
    }
  }

  /// Mostra loading modal
  void _showLoading(BuildContext context) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Importando viagem...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fecha loading se existir
  void _closeLoading(BuildContext context) {
    if (!context.mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  /// Helper para SnackBars
  void _showSnackBar(
      BuildContext context,
      String message,
      Color color, {
        SnackBarAction? action,
      }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        action: action,
      ),
    );
  }

  /// Limpa recursos
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    _intentDataStreamSubscription = null;
    _appLinkStreamSubscription?.cancel();
    _appLinkStreamSubscription = null;
  }
}
