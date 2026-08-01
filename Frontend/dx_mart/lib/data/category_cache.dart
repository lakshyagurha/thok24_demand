import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Disk cache for the category tree, stale-while-revalidate.
///
/// The tree is the first thing three screens need and it changes about never — a
/// shopkeeper adds a shelf maybe once a month. Refetching it on every cold start put a
/// spinner in front of the catalogue on exactly the connection least able to afford one.
///
/// So: return whatever is on disk immediately, then refresh in the background and tell
/// the caller if the answer changed. A cold launch paints real categories from disk with
/// no network at all; the refresh lands a moment later and usually changes nothing.
///
/// The cache is deliberately *not* invalidated by the app's language switch. All three
/// name variants ship in the same payload and are picked at render time, so switching
/// language costs zero requests.
class CategoryCache {
  CategoryCache._();

  /// Bumped whenever [Category.toTreeNode] changes shape. An old payload is then
  /// discarded rather than parsed into a half-populated model — the failure mode that
  /// makes cached data worse than no cached data.
  static const int _schemaVersion = 1;
  static const String _key = 'category_tree_v$_schemaVersion';
  static const String _stampKey = 'category_tree_at_v$_schemaVersion';

  /// After this, the disk copy is still *served* but is no longer trusted enough to
  /// skip the network on. It is a staleness bound, not an expiry: nothing is ever
  /// thrown away just for being old.
  static const Duration ttl = Duration(hours: 24);

  static List<Category>? _memory;
  static DateTime? _memoryAt;

  /// The tree as of the last successful load, or null if nothing has ever been cached.
  ///
  /// Synchronous once the process has read disk once, which is what lets the category
  /// screen paint in its first frame instead of after a `FutureBuilder` round trip.
  static List<Category>? get cached => _memory;

  static bool get isStale {
    final at = _memoryAt;
    return at == null || DateTime.now().difference(at) > ttl;
  }

  /// Reads the disk copy into memory. Safe to call repeatedly; only the first call
  /// touches disk.
  static Future<List<Category>?> load() async {
    if (_memory != null) return _memory;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw) as List;
      final tree = [
        for (final n in decoded)
          Category.fromTreeNode(Map<String, dynamic>.from(n as Map)),
      ];
      if (tree.isEmpty) return null;

      _memory = tree;
      final stamp = prefs.getInt(_stampKey);
      _memoryAt = stamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(stamp);
      return tree;
    } catch (_) {
      // A corrupt or half-written payload must never be the reason the app cannot
      // start. Drop it and let the caller go to the network.
      await clear();
      return null;
    }
  }

  static Future<void> save(List<Category> tree) async {
    if (tree.isEmpty) return;
    _memory = tree;
    _memoryAt = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([for (final c in tree) c.toTreeNode()]),
      );
      await prefs.setInt(_stampKey, _memoryAt!.millisecondsSinceEpoch);
    } catch (_) {
      // Writing the cache failing is not worth surfacing: the tree is already in
      // memory and this run works fine without a disk copy.
    }
  }

  static Future<void> clear() async {
    _memory = null;
    _memoryAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_stampKey);
    } catch (_) {
      // Same reasoning as save().
    }
  }

  /// True when the two trees differ, so a caller can skip a `setState` — and the whole
  /// rebuild behind it — on the common case where a background refresh confirms what
  /// is already on screen.
  ///
  /// Takes both sides explicitly rather than comparing against [cached]: the refresh
  /// path saves the new tree before it compares, so a version reading [cached] as the
  /// "before" would be comparing the fresh tree against itself and never report a
  /// change.
  static bool differs(List<Category>? before, List<Category> after) {
    if (before == null || before.length != after.length) return true;
    return jsonEncode([for (final c in before) c.toTreeNode()]) !=
        jsonEncode([for (final c in after) c.toTreeNode()]);
  }
}
