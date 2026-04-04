import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'core/providers/firebase_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      child: const _AppWithLifecycle(),
    ),
  );
}

class _AppWithLifecycle extends ConsumerStatefulWidget {
  const _AppWithLifecycle();

  @override
  ConsumerState<_AppWithLifecycle> createState() => _AppWithLifecycleState();
}

class _AppWithLifecycleState extends ConsumerState<_AppWithLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final auth = ref.read(firebaseAuthProvider);
    if (auth.currentUser == null) return;

    final firestore = ref.read(firestoreProvider);
    final uid = auth.currentUser!.uid;

    switch (state) {
      case AppLifecycleState.resumed:
        firestore.collection('users').doc(uid).update({
          'isOnline': true,
          'lastSeen': DateTime.now(),
        });
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        firestore.collection('users').doc(uid).update({
          'isOnline': false,
          'lastSeen': DateTime.now(),
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const ChatApp();
  }
}
