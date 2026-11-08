/// Editing times accept ASCII decimals, decimal commas and Arabic/Indic digits.
/// Grouping is deliberately rejected: machine/SRT serialization remains ASCII.
double? parseEditorDecimal(String input) {
  final value = String.fromCharCodes(
    input.trim().runes.map((rune) {
      for (final zero in [0x0660, 0x06f0, 0x0966, 0xff10]) {
        if (rune >= zero && rune <= zero + 9) return 0x30 + rune - zero;
      }
      return rune == 0x066b || rune == 0x002c ? 0x002e : rune;
    }),
  );
  if (!RegExp(r'^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$').hasMatch(value)) {
    return null;
  }
  final number = double.tryParse(value);
  return number?.isFinite == true ? number : null;
}
