import 'package:hunspell_spell_check/hunspell_spell_check.dart';

export 'package:hunspell_spell_check/hunspell_spell_check.dart'
    show
        HunspellSpellCheckConfiguration,
        HunspellSpellCheckOptions,
        HunspellSpellCheckService,
        SpellChecker;

/// Backwards-compatible alias for [HunspellSpellCheckOptions], which now
/// lives in the extracted `hunspell_spell_check` package.
typedef AppFlowySpellCheckConfiguration = HunspellSpellCheckOptions;
