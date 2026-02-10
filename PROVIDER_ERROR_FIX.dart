import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ledger/app/routes.dart';
import 'package:ledger/features/today/today_models.dart';
import 'package:ledger/features/today/today_controller.dart';
import 'package:ledger/shared/colors.dart';
import 'package:ledger/shared/text_styles.dart';
import 'package:ledger/shared/data/ledger_repository.dart';

// =============================================================================
// PROVIDER ERROR - FIX GUIDE & EXPLANATION
// =============================================================================
//
// THE PROBLEM:
// ============
// Error: Could not find the correct Provider<TodayController> above this Builder Widget
//
// CAUSE:
// When using ChangeNotifierProvider with create(), the context passed to create()
// is the context BEFORE the provider is added to the widget tree. This means:
//
//   return ChangeNotifierProvider(
//     create: (context) {
//       // ❌ This context does NOT include TodayController yet!
//       // Even though it includes LedgerRepository
//       final controller = TodayController(...);
//       return controller;
//     },
//     child: const _TodayView(),  // ❌ This child cannot access TodayController
//   );
//
// THE FIX:
// ========
// Use the builder parameter instead of child. The builder's context includes
// the provider that was just created:
//
//   return ChangeNotifierProvider(
//     create: (context) {
//       final controller = TodayController(...);
//       return controller;
//     },
//     builder: (context, child) {
//       // ✅ This context includes both LedgerRepository AND TodayController!
//       return const _TodayView();
//     },
//   );
//
// PROVIDER ARCHITECTURE IN THIS APP:
// ==================================
//
// App Level (app.dart):
//   FutureBuilder<LedgerRepository>
//     └─ Provider<LedgerRepository>.value    ← Available to all screens
//
// Screen Level (today_screen.dart):
//   ChangeNotifierProvider<TodayController>
//     ├─ create: creates TodayController (using injected repository)
//     └─ builder: provides context with TodayController access
//        └─ _TodayView (can now access TodayController)

/// Example of WRONG way (causes ProviderNotFoundException)
class WrongPatternExample extends StatelessWidget {
  const WrongPatternExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        // ❌ Problem: This context doesn't have TodayController yet
        final repo = Provider.of<LedgerRepository>(context, listen: false);
        return TodayController(repository: repo);
      },
      child: const MyChild(),  // ❌ MyChild's context doesn't have access
    );
  }
}

/// Example of CORRECT way (fixes ProviderNotFoundException)
class CorrectPatternExample extends StatelessWidget {
  const CorrectPatternExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        // ✅ Create the controller using the injected repository
        final repo = Provider.of<LedgerRepository>(context, listen: false);
        return TodayController(repository: repo);
      },
      builder: (context, child) {
        // ✅ This context includes TodayController
        // The builder parameter creates a new BuildContext in the provider's scope
        return const MyChild();  // ✅ MyChild can now access TodayController
      },
    );
  }
}

class MyChild extends StatelessWidget {
  const MyChild({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Now this works because we used builder pattern
    final controller = Provider.of<TodayController>(context, listen: false);
    return Center(child: Text('Tasks: ${controller.taskCount}'));
  }
}

// =============================================================================
// KEY CONCEPTS
// =============================================================================

/// Provider Hierarchy Rules:
/// 1. A provider can only be accessed in its subtree
/// 2. The context must be a child of the provider in the widget tree
/// 3. When you use child: , that child's context doesn't include the provider
/// 4. When you use builder: , the builder's context DOES include the provider
///
/// Why?
/// - child: creates the child widget BEFORE the provider is added to tree
/// - builder: creates the child widget AFTER the provider is in the tree
///
/// Provider Hierarchy in Ledger:
///
///   MaterialApp (root)
///     └─ FutureBuilder<LedgerRepository>
///        └─ Provider<LedgerRepository>.value
///           └─ LedgerApp
///              └─ Routes
///                 └─ TodayScreen
///                    └─ ChangeNotifierProvider<TodayController>
///                       └─ _TodayView
///                          └─ Can access:
///                             - LedgerRepository (from app level)
///                             - TodayController (from screen level)

// =============================================================================
// FIX APPLIED TO TODAY_SCREEN.DART
// =============================================================================

/// The exact fix that was applied:

class TodayScreenFixed extends StatelessWidget {
  const TodayScreenFixed({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        // Step 1: Get repository from app-level provider
        final repository = Provider.of<LedgerRepository>(context, listen: false);
        // Step 2: Create controller with injected repository
        return TodayController(repository: repository);
      },
      builder: (context, child) {
        // Step 3: Use builder (not child) so context includes TodayController
        // Now _TodayView can access both LedgerRepository and TodayController
        return const _TodayViewFixed();
      },
    );
  }
}

class _TodayViewFixed extends StatelessWidget {
  const _TodayViewFixed();

  @override
  Widget build(BuildContext context) {
    // ✅ This now works because we used builder pattern
    final controller = Provider.of<TodayController>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
      ),
      body: Center(
        child: Text('Tasks: ${controller.taskCount}'),
      ),
    );
  }
}

// =============================================================================
// TESTING THE FIX
// =============================================================================

/// To verify the fix works:
/// 1. Run `flutter clean` to clear old builds
/// 2. Run `flutter pub get` to refresh dependencies
/// 3. Run `flutter run` to test the app
///
/// Expected behavior:
/// ✅ App loads without ProviderNotFoundException
/// ✅ Today screen displays properly
/// ✅ TodayController is accessible
/// ✅ No errors in console

// =============================================================================
// PREVENTION TIPS
// =============================================================================

/// Always remember:
/// 1. Use builder: for providers that need access to their own context
/// 2. Use child: only when child doesn't need to access the provider
/// 3. Check provider hierarchy - is my widget under the provider?
/// 4. Remember: create() context ≠ child context
/// 5. When in doubt, use builder: - it's always safer

/// Provider scoping rules:
/// - Providers are scoped to their subtree
/// - You can't access a provider above your widget in the tree
/// - You CAN access providers below your widget
/// - Different routes have different scopes (providers don't cross routes)

