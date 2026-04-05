import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/firebase_providers.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:chat_app/core/widgets/connectivity_banner.dart';
import 'package:chat_app/core/widgets/no_network_screen.dart';
import 'features/chat/presentation/screens/chat_list_screen.dart';

final splashTimeoutProvider = StateProvider<bool>((ref) => false);
final navigatorKey = GlobalKey<NavigatorState>();

class ChatApp extends ConsumerWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateChangesProvider);
    final isSplashDone = ref.watch(splashTimeoutProvider);

    
    ref.listen(connectivityProvider, (previous, next) {
      final results = next.valueOrNull ?? [];
      final isOffline = results.contains(ConnectivityResult.none);
      
      if (isOffline) {
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/no-network'),
            builder: (_) => const NoNetworkScreen(),
          ),
        );
      } else {
        
        navigatorKey.currentState?.popUntil((route) {
          return route.settings.name != '/no-network';
        });
      }
    });

    
    ref.listen(authStateChangesProvider, (previous, next) {
      if (!isSplashDone || next.isLoading) return;

      final prevUid = previous?.asData?.value?.uid;
      final nextUid = next.asData?.value?.uid;

      if (prevUid != nextUid) {
        if (nextUid != null) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ChatListScreen()),
            (route) => false,
          );
        } else {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    });

    
    if (!isSplashDone) {
      Future.delayed(const Duration(seconds: 2), () {
        ref.read(splashTimeoutProvider.notifier).state = true;
      });
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ChatApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: !isSplashDone || authState.isLoading
          ? const SplashScreen()
          : authState.when(
              data: (user) =>
                  user != null ? const ChatListScreen() : const LoginScreen(),
              loading: () => const SplashScreen(),
              error: (_, __) => const LoginScreen(),
            ),
    );
  }
}
