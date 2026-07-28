import 'package:flutter/widgets.dart';

/// Appearance and labels of the spell check suggestions menu.
///
/// The spell checking engine itself is configured through
/// [AppFlowySpellCheckConfiguration]; everything the user sees lives here.
class AppFlowySpellCheckStyle {
  const AppFlowySpellCheckStyle({
    this.suggestionIcon,
    this.highlightColor,
    this.deleteLabel = 'Delete',
    this.noSuggestionsLabel = 'No suggestions',
  });

  /// Custom icon widget that gets displayed in front of suggestions.
  final Widget? suggestionIcon;

  /// Custom color for the hover and splash highlight of a suggestion.
  final Color? highlightColor;

  /// Label of the entry that removes the misspelled word.
  final String deleteLabel;

  /// Shown when the spell checker has no replacement for the word.
  final String noSuggestionsLabel;

  AppFlowySpellCheckStyle copyWith({
    Widget? suggestionIcon,
    Color? highlightColor,
    String? deleteLabel,
    String? noSuggestionsLabel,
  }) {
    return AppFlowySpellCheckStyle(
      suggestionIcon: suggestionIcon ?? this.suggestionIcon,
      highlightColor: highlightColor ?? this.highlightColor,
      deleteLabel: deleteLabel ?? this.deleteLabel,
      noSuggestionsLabel: noSuggestionsLabel ?? this.noSuggestionsLabel,
    );
  }
}
