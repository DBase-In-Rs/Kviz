const Map<String, String> _latinDigraphsToCyrillic = <String, String>{
  'DŽ': 'Џ',
  'Dž': 'Џ',
  'dŽ': 'џ',
  'dž': 'џ',
  'DJ': 'Ђ',
  'Dj': 'Ђ',
  'dJ': 'ђ',
  'dj': 'ђ',
  'LJ': 'Љ',
  'Lj': 'Љ',
  'lJ': 'љ',
  'lj': 'љ',
  'NJ': 'Њ',
  'Nj': 'Њ',
  'nJ': 'њ',
  'nj': 'њ',
};

const Map<String, String> _latinToCyrillic = <String, String>{
  'A': 'А',
  'B': 'Б',
  'C': 'Ц',
  'Č': 'Ч',
  'Ć': 'Ћ',
  'D': 'Д',
  'Đ': 'Ђ',
  'E': 'Е',
  'F': 'Ф',
  'G': 'Г',
  'H': 'Х',
  'I': 'И',
  'J': 'Ј',
  'K': 'К',
  'L': 'Л',
  'M': 'М',
  'N': 'Н',
  'O': 'О',
  'P': 'П',
  'R': 'Р',
  'S': 'С',
  'Š': 'Ш',
  'T': 'Т',
  'U': 'У',
  'V': 'В',
  'Z': 'З',
  'Ž': 'Ж',
  'a': 'а',
  'b': 'б',
  'c': 'ц',
  'č': 'ч',
  'ć': 'ћ',
  'd': 'д',
  'đ': 'ђ',
  'e': 'е',
  'f': 'ф',
  'g': 'г',
  'h': 'х',
  'i': 'и',
  'j': 'ј',
  'k': 'к',
  'l': 'л',
  'm': 'м',
  'n': 'н',
  'o': 'о',
  'p': 'п',
  'r': 'р',
  's': 'с',
  'š': 'ш',
  't': 'т',
  'u': 'у',
  'v': 'в',
  'z': 'з',
  'ž': 'ж',
};

const Map<String, String> _cyrillicToLatin = <String, String>{
  'А': 'A',
  'Б': 'B',
  'В': 'V',
  'Г': 'G',
  'Д': 'D',
  'Ђ': 'Đ',
  'Е': 'E',
  'Ж': 'Ž',
  'З': 'Z',
  'И': 'I',
  'Ј': 'J',
  'К': 'K',
  'Л': 'L',
  'М': 'M',
  'Н': 'N',
  'О': 'O',
  'П': 'P',
  'Р': 'R',
  'С': 'S',
  'Т': 'T',
  'Ћ': 'Ć',
  'У': 'U',
  'Ф': 'F',
  'Х': 'H',
  'Ц': 'C',
  'Ч': 'Č',
  'Ш': 'Š',
  'а': 'a',
  'б': 'b',
  'в': 'v',
  'г': 'g',
  'д': 'd',
  'ђ': 'đ',
  'е': 'e',
  'ж': 'ž',
  'з': 'z',
  'и': 'i',
  'ј': 'j',
  'к': 'k',
  'л': 'l',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'п': 'p',
  'р': 'r',
  'с': 's',
  'т': 't',
  'ћ': 'ć',
  'у': 'u',
  'ф': 'f',
  'х': 'h',
  'ц': 'c',
  'ч': 'č',
  'ш': 'š',
  'љ': 'lj',
  'њ': 'nj',
  'џ': 'dž',
};

const String _uppercaseCyrillic = 'АБВГДЂЕЖЗИЈКЛЉМНЊОПРСТЋУФХЦЧЏШ';

String toSerbianCyrillic(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return text;

  final buffer = StringBuffer();
  var index = 0;
  while (index < text.length) {
    if (index + 1 < text.length) {
      final pair = text.substring(index, index + 2);
      final digraph = _latinDigraphsToCyrillic[pair];
      if (digraph != null) {
        buffer.write(digraph);
        index += 2;
        continue;
      }
    }

    final char = text.substring(index, index + 1);
    buffer.write(_latinToCyrillic[char] ?? char);
    index += 1;
  }

  return buffer.toString();
}

String toSerbianLatin(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return text;

  final chars = text.runes.map(String.fromCharCode).toList(growable: false);
  final buffer = StringBuffer();
  for (var index = 0; index < chars.length; index += 1) {
    final char = chars[index];
    final nextIsUppercase =
        index + 1 < chars.length &&
        _uppercaseCyrillic.contains(chars[index + 1]);

    switch (char) {
      case 'Љ':
        buffer.write(nextIsUppercase ? 'LJ' : 'Lj');
      case 'Њ':
        buffer.write(nextIsUppercase ? 'NJ' : 'Nj');
      case 'Џ':
        buffer.write(nextIsUppercase ? 'DŽ' : 'Dž');
      default:
        buffer.write(_cyrillicToLatin[char] ?? char);
    }
  }

  return buffer.toString();
}

String srScript(bool useCyrillic, Object? value) {
  return useCyrillic ? toSerbianCyrillic(value) : toSerbianLatin(value);
}

String srAssociationTargetLabel(bool useCyrillic, Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return raw;

  final latin = toSerbianLatin(raw).toLowerCase();
  return switch (latin) {
    'a' => useCyrillic ? 'А' : 'A',
    'b' => useCyrillic ? 'Б' : 'B',
    'v' => useCyrillic ? 'В' : 'V',
    'g' => useCyrillic ? 'Г' : 'G',
    'c' => useCyrillic ? 'Ц' : 'C',
    'd' => useCyrillic ? 'Д' : 'D',
    'final' || 'konacno' || 'konačno' => useCyrillic ? 'Коначно' : 'Konačno',
    _ => srScript(useCyrillic, raw),
  };
}
