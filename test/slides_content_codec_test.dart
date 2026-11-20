import 'package:flutter_test/flutter_test.dart';
import 'package:offynexbd/lib/modules/workspace/slides_content_codec.dart';

void main() {
  test('decodes legacy one-line-per-slide presentations', () {
    expect(SlidesContentCodec.decode('Opening\nSummary'), ['Opening', 'Summary']);
  });

  test('round trips multiline slide text without splitting slides', () {
    final slides = ['Title\nFirst paragraph\nSecond paragraph', 'Closing'];
    expect(SlidesContentCodec.decode(SlidesContentCodec.encode(slides)), slides);
  });

  test('rejects malformed structured slide data', () {
    expect(
      () => SlidesContentCodec.decode('OFFYNEXBD_SLIDES_V1\n{"not":"a list"}'),
      throwsFormatException,
    );
  });

  test('rejects oversized slide collections and content', () {
    expect(
      () => SlidesContentCodec.encode(
        List<String>.filled(SlidesContentCodec.maxSlides + 1, 'Slide'),
      ),
      throwsFormatException,
    );
    expect(
      () => SlidesContentCodec.decode(
        'Legacy content'.padRight(SlidesContentCodec.maxTextBytes + 1, 'x'),
      ),
      throwsFormatException,
    );
  });

}
