import 'dart:async';
import 'dart:collection';

import 'package:appflowy_editor/src/service/spell_check/spell_check.dart';

/// Notified with the words whose spelling result changed in the last batch.
typedef SpellCheckCacheListener = void Function(Set<String> changedWords);

/// Process wide cache of spell check results, shared by every rich text block.
///
/// Hunspell is queried over synchronous FFI on the main isolate, so checking a
/// word cannot actually run in parallel. What this cache does instead is make
/// the work happen once and in bulk:
///
/// * a word is only ever sent to the engine once, no matter how many blocks or
///   how many times it appears in the document;
/// * queued words are drained in time sliced batches that yield to the event
///   loop between slices, so a large document cannot block a frame;
/// * listeners are notified once per batch instead of once per word, which
///   turns the old "one rebuild per word" behaviour into one rebuild per batch.
class SpellCheckWordCache {
  SpellCheckWordCache._();

  static final SpellCheckWordCache instance = SpellCheckWordCache._();

  /// Number of results kept before the oldest ones are evicted.
  static const int maxCacheSize = 5000;

  /// How long a single batch may occupy the isolate before yielding.
  static const Duration sliceBudget = Duration(milliseconds: 4);

  /// Hard cap on the words checked in one slice, so a pathologically fast
  /// dictionary still hands control back regularly.
  static const int maxWordsPerSlice = 256;

  /// How long to wait before retrying when the engine is not ready yet.
  static const Duration _notInitializedRetry = Duration(milliseconds: 200);

  /// Portion of the cache dropped when [maxCacheSize] is exceeded. Evicting a
  /// slice of the oldest entries keeps the words currently on screen cached,
  /// unlike clearing everything and rechecking the whole document.
  static const double _evictionRatio = 0.25;

  final LinkedHashMap<String, bool> _results = LinkedHashMap<String, bool>();
  final LinkedHashSet<String> _queue = LinkedHashSet<String>();
  final List<SpellCheckCacheListener> _listeners = [];

  Timer? _drainTimer;
  bool _draining = false;

  /// Whether [word] has been checked and found to be misspelled. Words that
  /// have not been checked yet report `false`, so nothing is underlined before
  /// there is a result for it.
  bool isMisspelled(String word) => _results[word] == true;

  /// Whether there is already a result for [word].
  bool isChecked(String word) => _results.containsKey(word);

  /// Queues [word] for checking unless it is already cached or queued.
  ///
  /// The first queued word starts the [debounce] window; later words join the
  /// same window instead of restarting it, so continuous typing still gets a
  /// batch every [debounce] rather than starving until the typing stops.
  void enqueue(String word, {Duration debounce = Duration.zero}) {
    if (_results.containsKey(word)) return;
    if (!_queue.add(word)) return;

    _scheduleDrain(debounce);
  }

  /// Marks [word] as correctly spelled, e.g. after it was added to the custom
  /// dictionary.
  void markCorrect(String word) {
    _queue.remove(word);
    _store(word, false);
  }

  /// Drops every cached result, for example after the dictionary or the spell
  /// check configuration changed.
  void clear() {
    _results.clear();
    _queue.clear();
    _drainTimer?.cancel();
    _drainTimer = null;
  }

  void addListener(SpellCheckCacheListener listener) => _listeners.add(listener);

  void removeListener(SpellCheckCacheListener listener) =>
      _listeners.remove(listener);

  void _scheduleDrain(Duration debounce) {
    if (_draining || _drainTimer != null) return;

    if (debounce == Duration.zero) {
      // Still deferred by a microtask so all words of the current build end up
      // in the same batch.
      _drainTimer = Timer(Duration.zero, _drain);
    } else {
      _drainTimer = Timer(debounce, _drain);
    }
  }

  Future<void> _drain() async {
    _drainTimer = null;
    if (_draining) return;

    if (!SpellChecker.instance.isInitialized) {
      // Keep the queue and try again once the engine had a chance to come up.
      if (_queue.isNotEmpty) _drainTimer = Timer(_notInitializedRetry, _drain);
      return;
    }

    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final changed = await _drainSlice();
        if (changed.isNotEmpty) _notify(changed);

        // Hand control back so the frame that is waiting on these results can
        // actually be drawn before the next slice starts.
        if (_queue.isNotEmpty) await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _draining = false;
    }
  }

  Future<Set<String>> _drainSlice() async {
    final stopwatch = Stopwatch()..start();
    final changed = <String>{};
    var checked = 0;

    while (_queue.isNotEmpty &&
        checked < maxWordsPerSlice &&
        stopwatch.elapsed < sliceBudget) {
      final word = _queue.first;
      _queue.remove(word);
      checked++;

      bool misspelled;
      try {
        misspelled = !await SpellChecker.instance.checkWord(word);
      } catch (_) {
        // Treat as known on error, so a failing engine does not underline the
        // whole document.
        misspelled = false;
      }

      if (_results[word] != misspelled) {
        _store(word, misspelled);
        changed.add(word);
      }
    }

    return changed;
  }

  void _store(String word, bool misspelled) {
    _results[word] = misspelled;

    if (_results.length > maxCacheSize) {
      final evictCount = (maxCacheSize * _evictionRatio).ceil();
      final stale = _results.keys.take(evictCount).toList(growable: false);
      for (final key in stale) {
        _results.remove(key);
      }
    }
  }

  void _notify(Set<String> changed) {
    // Copied so a listener that unsubscribes while being notified cannot
    // mutate the list we are iterating.
    for (final listener in List.of(_listeners)) {
      listener(changed);
    }
  }
}
