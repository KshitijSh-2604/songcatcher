enum SongLanguage {
  all,
  bollywood,
  english,
  international;

  String get label {
    switch (this) {
      case SongLanguage.all:
        return 'All Languages';
      case SongLanguage.bollywood:
        return '🎬 Bollywood';
      case SongLanguage.english:
        return '🇬🇧 English';
      case SongLanguage.international:
        return '🌍 International';
    }
  }

  String? get firestoreValue =>
      this == SongLanguage.all ? null : name;
}

enum SongDecade {
  all,
  s70s,
  s80s,
  s90s,
  s00s,
  s10s,
  s20s;

  String get label {
    switch (this) {
      case SongDecade.all:
        return 'All Eras';
      case SongDecade.s70s:
        return '70s';
      case SongDecade.s80s:
        return '80s';
      case SongDecade.s90s:
        return '90s';
      case SongDecade.s00s:
        return '2000s';
      case SongDecade.s10s:
        return '2010s';
      case SongDecade.s20s:
        return '2020s';
    }
  }

  String? get firestoreValue {
    if (this == SongDecade.all) return null;
    return name.replaceFirst('s', ''); // e.g. s70s → 70s
  }
}