import 'package:flutter/material.dart';

/// Downloads an optional screen on first use, with a way back and a retry
/// when a connection drops. Keep the future stable across parent rebuilds.
class FeatureLoader extends StatefulWidget {
  const FeatureLoader({
    super.key,
    required this.load,
    required this.builder,
    required this.label,
    required this.onBack,
  });

  final Future<void> Function() load;
  final WidgetBuilder builder;
  final String label;
  final VoidCallback onBack;

  @override
  State<FeatureLoader> createState() => _FeatureLoaderState();
}

/// Loads already in flight or finished, by label.
///
/// A deferred library only needs fetching once, so revisiting a page should be
/// instant rather than asking again. It also matters for correctness: calling
/// `loadLibrary()` a second time in one isolate can hand back a future that
/// never completes, which left the page stuck on its spinner forever.
final Map<String, Future<void>> _loads = {};

/// Visible for tests that want each case to start from nothing.
@visibleForTesting
void resetFeatureLoads() => _loads.clear();

Future<void> _loadOnce(String key, Future<void> Function() load) async {
  final existing = _loads[key];
  if (existing != null) return existing;
  final future = load();
  _loads[key] = future;
  try {
    await future;
  } catch (_) {
    _loads.remove(key); // let a retry try again
    rethrow;
  }
}

class _FeatureLoaderState extends State<FeatureLoader> {
  late Future<void> _loading = _loadOnce(widget.label, widget.load);

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _loading,
        builder: (context, result) {
          if (result.connectionState == ConnectionState.done &&
              !result.hasError) {
            return widget.builder(context);
          }
          return StartupScreen(
            label: widget.label,
            onBack: widget.onBack,
            onRetry: result.hasError
                ? () => setState(
                    () => _loading = _loadOnce(widget.label, widget.load))
                : null,
          );
        },
      );
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({
    super.key,
    required this.label,
    required this.onBack,
    this.onRetry,
  });

  final String label;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRetry == null) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(onRetry == null
                  ? label
                  : 'Couldn’t finish loading. Try again.'),
              const SizedBox(height: 16),
              if (onRetry != null)
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              TextButton(onPressed: onBack, child: const Text('Back')),
            ],
          ),
        ),
      );
}
