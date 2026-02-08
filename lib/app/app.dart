import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ledger/app/theme.dart';
import 'package:ledger/app/routes.dart';
import 'package:ledger/shared/data/ledger_repository.dart';
import 'package:ledger/shared/data/shared_prefs_storage.dart';
import 'package:ledger/shared/data/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LedgerApp extends StatefulWidget {
  const LedgerApp({super.key});

  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> with WidgetsBindingObserver {
  late Future<LedgerRepository> _repoFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repoFuture = _initializeRepository();
  }

  Future<LedgerRepository> _initializeRepository() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(prefs);
    return LedgerRepository(storage);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // =========================================================================
  // APP LIFECYCLE HANDLING - Critical for integrity
  // =========================================================================
  //
  // When app goes to background:
  // - Save session state with timestamp
  // - Track that app was backgrounded
  //
  // When app resumes:
  // - Check session state
  // - If task was active, calculate elapsed time

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final repo = await _repoFuture;

    switch (state) {
      case AppLifecycleState.paused:
        // App going to background - save heartbeat
        final session = await repo.loadSession();
        if (session != null && session.hasActiveTask) {
          await repo.saveSession(
            SessionState(
              activeTaskId: session.activeTaskId,
              sessionStartedAt: session.sessionStartedAt,
              lastHeartbeat: DateTime.now(),
            ),
          );
        }
        break;

      case AppLifecycleState.resumed:
        // App resuming from background
        // Session state is loaded by individual screens
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LedgerRepository>(
      future: _repoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return Provider<LedgerRepository>.value(
          value: snapshot.data!,
          child: MaterialApp(
            title: 'Ledger',
            theme: AppTheme.darkTheme,
            initialRoute: Routes.today,
            onGenerateRoute: Routes.generateRoute,
          ),
        );
      },
    );
  }
}
