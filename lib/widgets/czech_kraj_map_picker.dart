import 'package:flutter/material.dart';

class CzechKrajMapPicker extends StatefulWidget {
  final String? selectedKraj;
  final ValueChanged<String> onKrajSelected;
  final bool isDarkMode;

  const CzechKrajMapPicker({
    super.key,
    required this.selectedKraj,
    required this.onKrajSelected,
    this.isDarkMode = false,
  });

  @override
  State<CzechKrajMapPicker> createState() => _CzechKrajMapPickerState();
}

class _CzechKrajMapPickerState extends State<CzechKrajMapPicker> {
  final Map<String, Path> _regionsPaths = {};

  @override
  void initState() {
    super.initState();
    _buildPaths();
  }

  void _buildPaths() {
    final Map<String, List<Offset>> regionsPoints = {
      'Karlovarský': [
        const Offset(14, 45),
        const Offset(42, 35),
        const Offset(63, 50),
        const Offset(42, 68),
        const Offset(14, 68),
      ],
      'Plzeňský': [
        const Offset(14, 68),
        const Offset(42, 68),
        const Offset(70, 72),
        const Offset(49, 108),
        const Offset(21, 90),
      ],
      'Jihočeský': [
        const Offset(70, 72),
        const Offset(119, 76),
        const Offset(91, 121),
        const Offset(49, 108),
      ],
      'Ústecký': [
        const Offset(42, 35),
        const Offset(84, 18),
        const Offset(63, 50),
      ],
      'Středočeský': [
        const Offset(63, 50),
        const Offset(84, 18),
        const Offset(112, 45),
        const Offset(119, 76),
        const Offset(70, 72),
      ],
      'Praha': [
        const Offset(84, 52),
        const Offset(96, 52),
        const Offset(96, 61),
        const Offset(84, 61),
      ],
      'Liberecký': [
        const Offset(84, 18),
        const Offset(126, 22),
        const Offset(112, 45),
      ],
      'Královéhradecký': [
        const Offset(126, 22),
        const Offset(161, 27),
        const Offset(147, 50),
        const Offset(112, 45),
      ],
      'Pardubický': [
        const Offset(112, 45),
        const Offset(147, 50),
        const Offset(161, 81),
        const Offset(119, 76),
      ],
      'Vysočina': [
        const Offset(119, 76),
        const Offset(161, 81),
        const Offset(140, 126),
        const Offset(91, 121),
      ],
      'Jihomoravský': [
        const Offset(161, 81),
        const Offset(203, 85),
        const Offset(175, 126),
        const Offset(140, 126),
      ],
      'Olomoucký': [
        const Offset(147, 50),
        const Offset(203, 36),
        const Offset(196, 58),
        const Offset(203, 85),
        const Offset(161, 81),
      ],
      'Moravskoslezský': [
        const Offset(203, 36),
        const Offset(245, 40),
        const Offset(280, 54),
        const Offset(280, 85),
        const Offset(231, 67),
        const Offset(196, 58),
      ],
      'Zlínský': [
        const Offset(203, 85),
        const Offset(231, 67),
        const Offset(280, 85),
        const Offset(245, 99),
        const Offset(210, 112),
      ],
    };

    regionsPoints.forEach((kraj, points) {
      final path = Path();
      if (points.isNotEmpty) {
        path.moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        path.close();
      }
      _regionsPaths[kraj] = path;
    });
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    final double scaleX = 300.0 / constraints.maxWidth;
    final double scaleY = 150.0 / constraints.maxHeight;
    final Offset localPos = details.localPosition;
    final Offset scaledPos = Offset(localPos.dx * scaleX, localPos.dy * scaleY);

    if (_regionsPaths['Praha']?.contains(scaledPos) == true) {
      widget.onKrajSelected('Praha');
      return;
    }

    for (final entry in _regionsPaths.entries) {
      if (entry.key == 'Praha') continue;
      if (entry.value.contains(scaledPos)) {
        widget.onKrajSelected(entry.key);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) => _handleTap(details, constraints),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1E272C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isDarkMode ? Colors.white12 : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: CustomPaint(
              painter: _CzechMapPainter(
                paths: _regionsPaths,
                selectedKraj: widget.selectedKraj,
                isDarkMode: widget.isDarkMode,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CzechMapPainter extends CustomPainter {
  final Map<String, Path> paths;
  final String? selectedKraj;
  final bool isDarkMode;

  _CzechMapPainter({
    required this.paths,
    required this.selectedKraj,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale canvas to coordinates unit (300 x 150)
    canvas.save();
    canvas.scale(size.width / 300.0, size.height / 150.0);

    // Paints
    final borderPaint = Paint()
      ..color = isDarkMode ? Colors.black54 : Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final defaultFillPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF2E3B42) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;

    final selectedFillPaint = Paint()
      ..color = const Color(0xFFBFFF00).withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final prahaSelectedFillPaint = Paint()
      ..color = const Color(0xFFD4FF00)
      ..style = PaintingStyle.fill;

    final selectedBorderPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw all regions except Praha first
    paths.forEach((kraj, path) {
      if (kraj == 'Praha') return;
      final isSelected = selectedKraj == kraj;
      canvas.drawPath(path, isSelected ? selectedFillPaint : defaultFillPaint);
      canvas.drawPath(path, isSelected ? selectedBorderPaint : borderPaint);
    });

    // Draw Praha last so it is on top
    final prahaPath = paths['Praha'];
    if (prahaPath != null) {
      final isPrahaSelected = selectedKraj == 'Praha';
      final prahaDefaultFillPaint = Paint()
        ..color = isDarkMode ? const Color(0xFF5C727D) : Colors.grey.shade400
        ..style = PaintingStyle.fill;
      canvas.drawPath(prahaPath, isPrahaSelected ? prahaSelectedFillPaint : prahaDefaultFillPaint);
      canvas.drawPath(prahaPath, isPrahaSelected ? selectedBorderPaint : borderPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CzechMapPainter oldDelegate) {
    return oldDelegate.selectedKraj != selectedKraj || oldDelegate.isDarkMode != isDarkMode;
  }
}
