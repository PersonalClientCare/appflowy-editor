import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Overlay widget that shows spell check suggestions when right clicking a
/// misspelled word.
///
/// The suggestions are rendered in a rounded, elevated card anchored at the
/// click position. Right clicking anything that is not a misspelled word does
/// nothing, so the surrounding editor keeps its own context menu behaviour.
class SpellCheckOverlay extends StatefulWidget {
  const SpellCheckOverlay({
    super.key,
    required this.editorState,
    required this.node,
    required this.delegate,
    required this.misspelledCache,
    this.suggestionIcon,
    this.highlightColor,
    this.deleteLabel = 'Delete',
    this.noSuggestionsLabel = 'No suggestions',
  });

  final EditorState editorState;
  final Node node;
  final SelectableMixin delegate;
  final Map<String, bool> misspelledCache;
  final Widget? suggestionIcon;
  final Color? highlightColor;

  /// Label of the entry that removes the misspelled word.
  final String deleteLabel;

  /// Shown when the spell checker has no replacement for the word.
  final String noSuggestionsLabel;

  @override
  State<SpellCheckOverlay> createState() => _SpellCheckOverlayState();
}

class _SpellCheckOverlayState extends State<SpellCheckOverlay> {
  OverlayEntry? _overlayEntry;
  String? _menuWord;

  static const _menuVerticalOffset = 8.0;
  static const _maxSuggestions = 5;
  static const _minWordLengthForCheck = 3;

  late final String _interceptorKey = 'spell_check_${identityHashCode(this)}';

  @override
  void initState() {
    super.initState();

    // The suggestions menu is opened from a raw [Listener], which does not
    // take part in the gesture arena, so the editor would show its own
    // context menu on top of it. This interceptor swallows the right click
    // the menu was opened for.
    widget.editorState.service.selectionService.registerGestureInterceptor(
      SelectionGestureInterceptor(
        key: _interceptorKey,
        canSecondaryTap: (details) => !_SpellCheckMenuClaim.consume(
          details.globalPosition,
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.editorState.service.selectionService.unregisterGestureInterceptor(
      _interceptorKey,
    );
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    if (_overlayEntry == null) return;

    HardwareKeyboard.instance.removeHandler(_handleEscape);
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    _menuWord = null;
  }

  bool _handleEscape(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _removeOverlay();
      return true;
    }
    return false;
  }

  // Unicode-aware so non-ASCII letters (ü, ß, é, ...) and combining marks
  // (NFD input) count as word characters.
  static final _wordReg = RegExp(r'^[\p{L}\p{M}\p{N}_]+$', unicode: true);

  bool _isValidWordForSpellCheck(String word) {
    return _wordReg.hasMatch(word) && word.length >= _minWordLengthForCheck;
  }

  ({String word, int start, int length})? _getWordAtPosition(
    Offset localPosition,
  ) {
    final globalPosition = widget.delegate.localToGlobal(localPosition);
    final position = widget.delegate.getPositionInOffset(globalPosition);
    final selection = widget.delegate.getWordBoundaryInPosition(position);

    if (selection == null) return null;

    final delta = widget.node.delta;
    if (delta == null) return null;

    final text = delta.toPlainText();
    final start = selection.start.offset;
    final end = selection.end.offset;

    if (start < 0 || end > text.length || start >= end) return null;

    return (
      word: text.substring(start, end),
      start: start,
      length: end - start
    );
  }

  void _handleSecondaryTap(PointerDownEvent event) {
    _removeOverlay();

    final wordData = _getWordAtPosition(event.localPosition);
    if (wordData == null) return;

    final (:word, :start, :length) = wordData;
    if (!_isValidWordForSpellCheck(word)) return;
    if (widget.misspelledCache[word] != true) return;

    _SpellCheckMenuClaim.claim(event.position);
    _showSuggestionsMenu(word, event.position, start, length);
  }

  void _showSuggestionsMenu(
    String word,
    Offset anchor,
    int start,
    int length,
  ) {
    final suggestions = SpellChecker.instance.suggest(
      word,
      maxSuggestions: _maxSuggestions,
    );

    _menuWord = word;
    _overlayEntry = OverlayEntry(
      builder: (context) => _SpellCheckSuggestionsMenu(
        anchor: anchor.translate(0, _menuVerticalOffset),
        word: word,
        suggestions: suggestions,
        suggestionIcon: widget.suggestionIcon,
        highlightColor: widget.highlightColor,
        deleteLabel: widget.deleteLabel,
        noSuggestionsLabel: widget.noSuggestionsLabel,
        onDismiss: _removeOverlay,
        onSelected: (replacement) =>
            _replaceMisspelledWord(replacement, start, length),
      ),
    );

    HardwareKeyboard.instance.addHandler(_handleEscape);
    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _replaceMisspelledWord(
    String replacement,
    int start,
    int length,
  ) async {
    final replacedWord = _menuWord;
    _removeOverlay();

    final transaction = widget.editorState.transaction;
    transaction.replaceText(
      widget.node,
      start,
      length,
      replacement,
      attributes: widget.node.attributes,
    );
    transaction.afterSelection = Selection.collapsed(
      Position(path: widget.node.path, offset: start + replacement.length),
    );
    await widget.editorState.apply(transaction);

    // Clear the old word from cache since it's been replaced
    if (replacedWord != null) {
      widget.misspelledCache.remove(replacedWord);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.buttons == kSecondaryButton) {
            _handleSecondaryTap(event);
          }
        },
      ),
    );
  }
}

/// Bridges the raw pointer event that opens the suggestions menu and the
/// secondary tap the editor's selection service sees for the same click.
class _SpellCheckMenuClaim {
  const _SpellCheckMenuClaim._();

  static const _maxAge = Duration(milliseconds: 500);

  static Offset? _position;
  static DateTime? _claimedAt;

  static void claim(Offset position) {
    _position = position;
    _claimedAt = DateTime.now();
  }

  /// Whether the right click at [position] opened a suggestions menu. Stale
  /// claims are dropped so a click that never reached the recognizer cannot
  /// swallow a later context menu.
  static bool consume(Offset position) {
    final claimedAt = _claimedAt;
    if (claimedAt == null ||
        DateTime.now().difference(claimedAt) > _maxAge ||
        _position != position) {
      return false;
    }

    _position = null;
    _claimedAt = null;

    return true;
  }
}

class _SpellCheckSuggestionsMenu extends StatelessWidget {
  const _SpellCheckSuggestionsMenu({
    required this.anchor,
    required this.word,
    required this.suggestions,
    required this.onSelected,
    required this.onDismiss,
    required this.deleteLabel,
    required this.noSuggestionsLabel,
    this.suggestionIcon,
    this.highlightColor,
  });

  final Offset anchor;
  final String word;
  final List<String> suggestions;
  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;
  final String deleteLabel;
  final String noSuggestionsLabel;
  final Widget? suggestionIcon;
  final Color? highlightColor;

  static const _screenPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withAlpha(80);
    final highlight = highlightColor ?? theme.primaryColor.withAlpha(45);

    return Stack(
      children: [
        // Dismisses the menu on any click outside of it.
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => onDismiss(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(_screenPadding),
          child: CustomSingleChildLayout(
            // The delegate works in local coordinates, so compensate for the
            // surrounding padding.
            delegate: _MenuLayoutDelegate(
              anchor: anchor - const Offset(_screenPadding, _screenPadding),
            ),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 220.0,
                maxWidth: 300.0,
                maxHeight: 320.0,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 20.0,
                    offset: const Offset(0.0, 6.0),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(theme),
                      Divider(height: 1.0, color: dividerColor),
                      Flexible(
                        child: suggestions.isEmpty
                            ? _emptyHint(theme)
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                shrinkWrap: true,
                                itemCount: suggestions.length,
                                itemBuilder: (context, index) =>
                                    _SuggestionTile(
                                  label: suggestions[index],
                                  icon: suggestionIcon ??
                                      const Icon(Icons.auto_fix_high, size: 18),
                                  highlightColor: highlight,
                                  onPressed: () => onSelected(
                                    suggestions[index],
                                  ),
                                ),
                              ),
                      ),
                      Divider(height: 1.0, color: dividerColor),
                      _SuggestionTile(
                        label: deleteLabel,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: theme.colorScheme.error,
                        highlightColor: highlight,
                        onPressed: () => onSelected(''),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 10.0),
      child: Row(
        children: [
          Icon(
            Icons.spellcheck,
            size: 18.0,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.error,
                decorationStyle: TextDecorationStyle.wavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
      child: Text(
        noSuggestionsLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withAlpha(150),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.label,
    required this.icon,
    required this.highlightColor,
    required this.onPressed,
    this.color,
  });

  final String label;
  final Widget icon;
  final Color highlightColor;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurface;

    return InkWell(
      onTap: onPressed,
      hoverColor: highlightColor,
      splashColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          children: [
            IconTheme.merge(
              data: IconThemeData(color: foreground, size: 18.0),
              child: icon,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Places the menu at [anchor], flipping or shifting it so it stays on screen.
class _MenuLayoutDelegate extends SingleChildLayoutDelegate {
  const _MenuLayoutDelegate({required this.anchor});

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final dx = anchor.dx + childSize.width > size.width
        ? size.width - childSize.width
        : anchor.dx;
    // Flip above the anchor when there is not enough room below it.
    final fitsBelow = anchor.dy + childSize.height <= size.height;
    final dy = fitsBelow
        ? anchor.dy
        : (anchor.dy - childSize.height).clamp(0.0, size.height);

    return Offset(dx.clamp(0.0, size.width), dy);
  }

  @override
  bool shouldRelayout(_MenuLayoutDelegate oldDelegate) =>
      anchor != oldDelegate.anchor;
}
