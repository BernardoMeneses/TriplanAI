import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'common/app_scaffold.dart';
import 'common/app_colors.dart';
import 'features/new_trip/pages/new_trip_page.dart';
import 'features/home/pages/home_page.dart';
import 'features/auth/pages/login_page.dart';
import 'features/travelling/pages/traveling_page.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/trips_service.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'services/connectivity_service.dart';
import 'services/adapty_service.dart';
import 'services/trip_cache_service.dart';
import 'services/favorites_service.dart';
import 'services/subscription_service.dart';
import 'services/location_service.dart';
import 'shared/widgets/destination_search_modal.dart';
import 'package:flutter/services.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();

    // Bloquear rotação de tela (apenas portrait)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    if (kDebugMode) {
      print('🚀 TriplanAI: Iniciando app...');
    }

    await ThemeService().init();

    // Inicializar serviço de notificações
    await NotificationService().initialize();
    await NotificationService().requestPermissions();

    // Inicializar Adapty (pagamentos)
    await AdaptyService().initialize();

    if (kDebugMode) {
      print('✅ TriplanAI: Todos os serviços inicializados');
    }

    runApp(
      EasyLocalization(
        supportedLocales: const [
          Locale('pt'),
          Locale('en'),
          Locale('es'),
          Locale('fr'),
          Locale('de'),
          Locale('it'),
          Locale('ja'),
          Locale('zh'),
          Locale('ko'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('pt'),
        child: const TriplanAIApp(),
      ),
    );
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('❌ Erro ao iniciar app: $e');
      print(stackTrace);
    }
    // Fallback: rodar app mesmo com erro
    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('pt')],
        path: 'assets/translations',
        fallbackLocale: const Locale('pt'),
        child: const TriplanAIApp(),
      ),
    );
  }
}

class TriplanAIApp extends StatefulWidget {
  const TriplanAIApp({super.key});

  @override
  State<TriplanAIApp> createState() => _TriplanAIAppState();
}

class _TriplanAIAppState extends State<TriplanAIApp> {
  int _currentIndex = 0;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final DeepLinkService _deepLinkService = DeepLinkService();
  final ConnectivityService _connectivityService = ConnectivityService();

  void _openNewTripTab() {
    setState(() {
      _currentIndex = 1;
    });
  }

  List<Widget> get _pages => [
    HomePage(onLogout: _onLogout, onOpenNewTripTab: _openNewTripTab),
    const NewTripPage(),
    TravelingPage(onLogout: _onLogout, onOpenNewTripTab: _openNewTripTab),
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _themeService.addListener(_onThemeChanged);

    // Iniciar verificação periódica de conectividade (para toda a app)
    _connectivityService.startPeriodicCheck();

    // Inicializar deep link service após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _deepLinkService.initialize(
          context,
          (trip) {
            // Navegar para a página da viagem importada
            Navigator.pushNamed(context, '/new-trip', arguments: trip);
          },
          onAppLink: (uri) async {
            try {
              if (uri.scheme == 'triplanai' &&
                  uri.host == 'app' &&
                  uri.path == '/login') {
                // Forçar logout e limpar caches quando receber link de confirmação de deleção
                await AuthService().logout();
                await TripCacheService().clearCache();
                await FavoritesService().clearCache();
                SubscriptionService().clearCache();
                LocationService.clearCache();

                if (mounted) {
                  _onLogout();
                }
              }
            } catch (e) {
              if (kDebugMode) print('Erro ao processar app link: $e');
            }
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _deepLinkService.dispose();
    _connectivityService.stopPeriodicCheck();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _checkAuth() async {
    try {
      if (kDebugMode) {
        print('🔐 Verificando autenticação...');
      }

      final isAuth = await _authService.init().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (kDebugMode) {
            print('⏱️ Timeout na verificação de auth');
          }
          return false;
        },
      );

      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
          _isLoading = false;
        });

        if (kDebugMode) {
          print('✅ Auth check completo: $isAuth');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro no _checkAuth: $e');
      }
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  void _onLoginSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _onLogout() {
    setState(() {
      _isAuthenticated = false;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TriplanAI',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      themeMode: _themeService.themeMode,
      builder: (context, child) {
        // Limitar escala de texto para evitar overflow
        final mediaQueryData = MediaQuery.of(context);
        final constrainedTextScaleFactor = mediaQueryData.textScaleFactor.clamp(
          1.0,
          1.3,
        );

        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: TextScaler.linear(constrainedTextScaleFactor),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'Roboto', // Defina a fonte padrão global aqui
              fontWeight: FontWeight.normal,
              fontSize: 14,
              color: Colors.black,
              overflow: TextOverflow.ellipsis,
            ),
            child: child!,
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.backgroundLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.primaryDark,
          surface: AppColors.surfaceLight,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surfaceLight,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimaryLight,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontFamily: 'Roboto'),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.backgroundDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.primaryDark,
          surface: AppColors.surfaceDark,
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontFamily: 'Roboto'),
          ),
        ),
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/new-trip') {
          final args = settings.arguments;

          // Pode receber Trip (para edição) ou DestinationResult (para nova viagem)
          Trip? existingTrip;
          DestinationResult? destinationResult;

          if (args is Trip) {
            existingTrip = args;
          } else if (args is DestinationResult) {
            destinationResult = args;
          }

          return MaterialPageRoute(
            builder: (context) => NewTripPage(
              existingTrip: existingTrip,
              initialDestination: destinationResult,
            ),
          );
        }

        return null;
      },
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isAuthenticated
          ? AppScaffold(
              currentIndex: _currentIndex,
              onTabChange: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              child: _pages[_currentIndex],
              onLogout: _onLogout,
            )
          : LoginPage(onLoginSuccess: _onLoginSuccess),
    );
  }
}
