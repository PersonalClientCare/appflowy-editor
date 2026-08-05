import 'package:flutter/widgets.dart';

/// Appearance and labels of the spell check suggestions menu.
///
/// The spell checking engine itself is configured through
/// [AppFlowySpellCheckConfiguration]; everything the user sees lives here.
class AppFlowySpellCheckStyle {
  const AppFlowySpellCheckStyle({
    this.suggestionIcon,
    this.addToDictionaryIcon,
    this.highlightColor,
    this.deleteLabel = 'Delete',
    this.addToDictionaryLabel = 'Add to dictionary',
    this.noSuggestionsLabel = 'No suggestions',
  });

  /// Custom icon widget that gets displayed in front of suggestions.
  final Widget? suggestionIcon;

  /// Custom icon widget that gets displayed in front of the entry that adds
  /// the word to the custom dictionary.
  final Widget? addToDictionaryIcon;

  /// Custom color for the hover and splash highlight of a suggestion.
  final Color? highlightColor;

  /// Label of the entry that removes the misspelled word.
  final String deleteLabel;

  /// Label of the entry that adds the misspelled word to the custom
  /// dictionary, so it is treated as correctly spelled going forward.
  final String addToDictionaryLabel;

  /// Shown when the spell checker has no replacement for the word.
  final String noSuggestionsLabel;

  AppFlowySpellCheckStyle copyWith({
    Widget? suggestionIcon,
    Widget? addToDictionaryIcon,
    Color? highlightColor,
    String? deleteLabel,
    String? addToDictionaryLabel,
    String? noSuggestionsLabel,
  }) {
    return AppFlowySpellCheckStyle(
      suggestionIcon: suggestionIcon ?? this.suggestionIcon,
      addToDictionaryIcon: addToDictionaryIcon ?? this.addToDictionaryIcon,
      highlightColor: highlightColor ?? this.highlightColor,
      deleteLabel: deleteLabel ?? this.deleteLabel,
      addToDictionaryLabel: addToDictionaryLabel ?? this.addToDictionaryLabel,
      noSuggestionsLabel: noSuggestionsLabel ?? this.noSuggestionsLabel,
    );
  }
}
