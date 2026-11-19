import 'dart:math' as math;

/// Calculates the physical paper scale for the Writer editing viewport.
class WriterViewportLayout {
  const WriterViewportLayout({
    required this.availableWidth,
    required this.scale,
  });

  static const double minimumZoom = 0.5;
  static const double maximumZoom = 3.0;

  final double availableWidth;
  final double scale;

  static WriterViewportLayout calculate({
    required double pageWidth,
    required double pageHeight,
    required double viewportWidth,
    required double viewportHeight,
    required String viewFit,
    double zoom = 1,
  }) {
    if (!pageWidth.isFinite ||
        !pageHeight.isFinite ||
        !viewportWidth.isFinite ||
        !viewportHeight.isFinite ||
        pageWidth <= 0 ||
        pageHeight <= 0) {
      throw ArgumentError(
        'Page and viewport dimensions must be finite and positive.',
      );
    }

    final availableWidth = math.max(1.0, viewportWidth - 8);
    final safeHeight = math.max(1.0, viewportHeight);
    final fitScale = math.min(
      availableWidth / pageWidth,
      safeHeight / pageHeight,
    );
    final baseScale = switch (viewFit) {
      'Width' => availableWidth / pageWidth,
      'Actual' => 1.0,
      _ => fitScale,
    };
    final safeZoom = zoom.isFinite
        ? zoom.clamp(minimumZoom, maximumZoom).toDouble()
        : 1.0;

    return WriterViewportLayout(
      availableWidth: availableWidth,
      scale: (baseScale * safeZoom).clamp(0.15, maximumZoom).toDouble(),
    );
  }
}
