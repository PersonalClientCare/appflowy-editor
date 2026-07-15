import 'package:flutter/widgets.dart';

/// Configuration for spell checking behavior
class AppFlowySpellCheckConfiguration {
  const AppFlowySpellCheckConfiguration({
    this.minWordLength = 3,
    this.checkOnlyCompletedWords = true,
    this.debounceDelay = Duration.zero,
    this.excludePatterns = const [],
    required this.affPath,
    required this.dicPath,
    this.suggestionIcon,
    this.highlightColor,
  });

  /// Minimum word length to check for spelling errors.
  /// Words shorter than this will not be spell-checked.
  /// Default: 3 characters
  final int minWordLength;

  /// If true, only check words after whitespace/punctuation (completed words).
  /// If false, check words as you type (immediate feedback).
  ///
  /// Example:
  /// - true: "bas|" -> no redline, "bas " -> show redline
  /// - false: "bas|" -> show redline immediately
  ///
  /// Default: false (immediate checking)
  final bool checkOnlyCompletedWords;

  /// Delay before showing spell check underline.
  /// Useful to avoid flickering while typing.
  ///
  /// Example: Duration(milliseconds: 300) waits 300ms before showing redline
  /// Default: Duration.zero (immediate)
  final Duration debounceDelay;

  /// List of regex patterns to exclude from spell checking.
  ///
  /// Example:
  /// - RegExp(r'^#\w+') excludes hashtags (#flutter)
  /// - RegExp(r'@\w+') excludes mentions (@username)
  /// - RegExp(r'\d+') excludes numbers
  final List<RegExp> excludePatterns;

  /// Custom icon widget that gets displayed in front of suggestions.
  final Widget? suggestionIcon;

  /// Custom color for highlighting suggestions in overlay when hovering.
  final Color? highlightColor;

  /// Necessary hunspelll file paths
  final String affPath;
  final String dicPath;

  AppFlowySpellCheckConfiguration copyWith({
    int? minWordLength,
    bool? checkOnlyCompletedWords,
    Duration? debounceDelay,
    List<RegExp>? excludePatterns,
    Set<String>? customDictionary,
    String? affPath,
    String? dicPath,
    Widget? suggestionIcon,
    Color? highlightColor,
  }) {
    return AppFlowySpellCheckConfiguration(
      minWordLength: minWordLength ?? this.minWordLength,
      checkOnlyCompletedWords:
          checkOnlyCompletedWords ?? this.checkOnlyCompletedWords,
      debounceDelay: debounceDelay ?? this.debounceDelay,
      excludePatterns: excludePatterns ?? this.excludePatterns,
      affPath: affPath ?? this.affPath,
      dicPath: dicPath ?? this.dicPath,
      suggestionIcon: suggestionIcon ?? this.suggestionIcon,
      highlightColor: highlightColor ?? this.highlightColor,
    );
  }
}
