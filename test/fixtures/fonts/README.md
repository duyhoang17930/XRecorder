# Arabic contrast-test font

`NotoNaskhArabic-wght.ttf` is an unmodified Google Fonts fixture, used only by
host tests. Flutter's synthetic test font renders Arabic as missing-glyph boxes;
those boxes give misleading pixel-contrast results. The fixture gives the
contrast checker real Arabic glyphs. It is not registered in pubspec or bundled
in the application, whose Manrope and Android fallback fonts are unchanged.

Source: https://github.com/google/fonts/tree/main/ofl/notonaskharabic

Downloaded 2026-11-11; 307592 bytes.
SHA-256: `67b5a525a661b607971fbd3f96a81b89d3a768e74534fca84f18ac97e6fab72f`.
Licence: SIL OFL 1.1, included in `NotoNaskhArabic-OFL.txt`.

This fixture does not replace Android visual or human TalkBack testing.
