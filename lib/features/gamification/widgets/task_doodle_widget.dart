import 'package:flutter/material.dart';

class TaskDoodleWidget extends StatelessWidget {
  final String iconCode;
  final double size;

  const TaskDoodleWidget({
    super.key,
    required this.iconCode,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    // Attempt to load asset image first.
    // If it fails (e.g., file not found), fall back to custom painter vector doodle.
    final assetPath = 'assets/images/$iconCode.png';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getBackgroundColor(iconCode),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to our custom vector doodle painter
            return CustomPaint(
              size: Size(size, size),
              painter: TaskDoodlePainter(iconCode: iconCode),
            );
          },
        ),
      ),
    );
  }

  Color _getBackgroundColor(String code) {
    // Curated high-contrast retro arcade colors
    if (code.contains('luck')) return Colors.green.shade400;
    if (code.contains('silent')) return Colors.red.shade400;
    if (code.contains('backward')) return Colors.blue.shade400;
    if (code.contains('squat')) return Colors.orange.shade400;
    if (code.contains('group')) return Colors.purple.shade300;
    
    final hash = code.hashCode.abs();
    final List<Color> colors = [
      Colors.orange.shade400,
      Colors.pink.shade300,
      Colors.blue.shade400,
      Colors.amber.shade400,
      Colors.teal.shade300,
      Colors.indigo.shade300,
      Colors.cyan.shade400,
    ];
    return colors[hash % colors.length];
  }
}

class TaskDoodlePainter extends CustomPainter {
  final String iconCode;

  TaskDoodlePainter({required this.iconCode});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer stroke paint for cartoon outline
    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Offset fill paint for misaligned comic-book doodle look (Premium Neo-Brutalism aesthetic)
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Helper offset for misaligned fill
    const fillOffset = Offset(2, 2);

    // Dynamic drawing by iconCode
    switch (iconCode) {
      case 'pocket':
        _drawPocket(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'hop':
        _drawHop(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'backward':
      case 'group_backward':
        _drawBackward(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'backpack':
        _drawBackpack(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'silent':
      case 'group_silent':
        _drawSilent(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'echo':
        _drawEcho(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'knight':
        _drawKnight(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'squat':
      case 'group_squat':
        _drawSquat(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'sound':
      case 'group_music':
      case 'music':
        _drawMusic(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'limp':
        _drawLimp(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'forbidden':
      case 'group_heart':
      case 'heart':
        _drawHeart(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'whisper':
      case 'group_whisper':
        _drawWhisper(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'airplane':
      case 'group_fly':
        _drawAirplane(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'guide':
        _drawGuide(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'friends':
      case 'group_walk':
      case 'group_train':
      case 'group_link':
        _drawFriends(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'mic':
        _drawMic(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'poem':
      case 'group_poem':
        _drawPoem(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'globe':
      case 'group_chat':
        _drawGlobe(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'stick':
      case 'group_stick':
        _drawStick(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'animal':
      case 'group_animal':
        _drawAnimal(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'lock':
        _drawLock(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'theater':
      case 'group_laugh':
        _drawTheater(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'shield':
        _drawShield(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'crown':
      case 'group_pirate':
        _drawCrown(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'shadow':
      case 'spy':
      case 'group_stealth':
        _drawSpy(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'pointer':
        _drawPointer(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'question':
        _drawQuestion(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'book':
        _drawBook(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'stone':
      case 'group_balance':
        _drawStone(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'leaf':
      case 'group_trash':
        _drawLeaf(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'robot':
        _drawRobot(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'statue':
        _drawStatue(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'clap':
      case 'group_clap':
        _drawClap(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'service':
        _drawService(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'pray':
        _drawPray(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'cross':
        _drawCross(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'phone':
        _drawPhone(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'slow':
      case 'group_slow':
        _drawSlow(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'fast':
        _drawFast(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'cloud':
        _drawCloud(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
      case 'luck':
      case 'group_luck':
      default:
        _drawLuck(canvas, size, fillPaint, outlinePaint, fillOffset);
        break;
    }
  }

  // Individual Drawings
  void _drawPocket(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;
    
    // Pants contour
    final path = Path()
      ..moveTo(w * 0.25, h * 0.2)
      ..lineTo(w * 0.75, h * 0.2)
      ..lineTo(w * 0.8, h * 0.85)
      ..lineTo(w * 0.52, h * 0.85)
      ..lineTo(w * 0.5, h * 0.55)
      ..lineTo(w * 0.48, h * 0.85)
      ..lineTo(w * 0.2, h * 0.85)
      ..close();

    // Pocket cuts
    final pocketL = Path()
      ..moveTo(w * 0.3, h * 0.35)
      ..quadraticBezierTo(w * 0.38, h * 0.37, w * 0.42, h * 0.48);

    final pocketR = Path()
      ..moveTo(w * 0.7, h * 0.35)
      ..quadraticBezierTo(w * 0.62, h * 0.37, w * 0.58, h * 0.48);

    canvas.drawPath(path.shift(offset), fill);
    canvas.drawPath(path, outline);
    canvas.drawPath(pocketL, outline);
    canvas.drawPath(pocketR, outline);
  }

  void _drawHop(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Foot / Shoe shape
    final foot = Path()
      ..moveTo(w * 0.2, h * 0.6)
      ..lineTo(w * 0.35, h * 0.3)
      ..lineTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.45, h * 0.65)
      ..quadraticBezierTo(w * 0.7, h * 0.65, w * 0.8, h * 0.5)
      ..lineTo(w * 0.85, h * 0.65)
      ..quadraticBezierTo(w * 0.5, h * 0.75, w * 0.2, h * 0.6)
      ..close();

    // Bounce lines
    final bounce = Path()
      ..moveTo(w * 0.3, h * 0.8)
      ..lineTo(w * 0.2, h * 0.9)
      ..moveTo(w * 0.5, h * 0.82)
      ..lineTo(w * 0.45, h * 0.95)
      ..moveTo(w * 0.7, h * 0.8)
      ..lineTo(w * 0.75, h * 0.92);

    canvas.drawPath(foot.shift(offset), fill);
    canvas.drawPath(foot, outline);
    canvas.drawPath(bounce, outline);
  }

  void _drawBackward(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Two big arrows pointing left
    final arrow = Path()
      ..moveTo(w * 0.55, h * 0.25)
      ..lineTo(w * 0.25, h * 0.5)
      ..lineTo(w * 0.55, h * 0.75)
      ..lineTo(w * 0.55, h * 0.6)
      ..lineTo(w * 0.8, h * 0.6)
      ..lineTo(w * 0.8, h * 0.4)
      ..lineTo(w * 0.55, h * 0.4)
      ..close();

    canvas.drawPath(arrow.shift(offset), fill);
    canvas.drawPath(arrow, outline);
  }

  void _drawBackpack(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Backpack body RRect
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.25, h * 0.25, w * 0.5, h * 0.55),
      const Radius.circular(12),
    );

    // Front pocket
    final pocket = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.35, h * 0.5, w * 0.3, h * 0.25),
      const Radius.circular(6),
    );

    // Handle
    final handle = Path()
      ..moveTo(w * 0.4, h * 0.25)
      ..quadraticBezierTo(w * 0.5, h * 0.12, w * 0.6, h * 0.25);

    canvas.drawRRect(rect.shift(offset), fill);
    canvas.drawRRect(rect, outline);
    canvas.drawRRect(pocket, outline);
    canvas.drawPath(handle, outline);
  }

  void _drawSilent(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Silent emoji face
    canvas.drawCircle(Offset(w * 0.5, h * 0.5) + offset, w * 0.35, fill);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.35, outline);

    // Eyes
    canvas.drawCircle(Offset(w * 0.38, h * 0.42), 4, outline..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(w * 0.62, h * 0.42), 4, outline..style = PaintingStyle.fill);

    outline.style = PaintingStyle.stroke;

    // Zipper / tape cross mouth
    final cross = Path()
      ..moveTo(w * 0.35, h * 0.65)
      ..lineTo(w * 0.65, h * 0.65)
      ..moveTo(w * 0.4, h * 0.6)
      ..lineTo(w * 0.4, h * 0.7)
      ..moveTo(w * 0.5, h * 0.6)
      ..lineTo(w * 0.5, h * 0.7)
      ..moveTo(w * 0.6, h * 0.6)
      ..lineTo(w * 0.6, h * 0.7);

    canvas.drawPath(cross, outline);
  }

  void _drawEcho(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Two speech bubbles (representing talking and echo)
    final bubble1 = Path()
      ..moveTo(w * 0.15, h * 0.25)
      ..quadraticBezierTo(w * 0.15, h * 0.15, w * 0.35, h * 0.15)
      ..quadraticBezierTo(w * 0.55, h * 0.15, w * 0.55, h * 0.25)
      ..quadraticBezierTo(w * 0.55, h * 0.35, w * 0.35, h * 0.35)
      ..lineTo(w * 0.2, h * 0.45)
      ..lineTo(w * 0.25, h * 0.35)
      ..close();

    final bubble2 = Path()
      ..moveTo(w * 0.85, h * 0.6)
      ..quadraticBezierTo(w * 0.85, h * 0.5, w * 0.65, h * 0.5)
      ..quadraticBezierTo(w * 0.45, h * 0.5, w * 0.45, h * 0.6)
      ..quadraticBezierTo(w * 0.45, h * 0.7, w * 0.65, h * 0.7)
      ..lineTo(w * 0.8, h * 0.8)
      ..lineTo(w * 0.75, h * 0.7)
      ..close();

    canvas.drawPath(bubble1.shift(offset), fill);
    canvas.drawPath(bubble1, outline);
    canvas.drawPath(bubble2.shift(offset), fill);
    canvas.drawPath(bubble2, outline);
  }

  void _drawKnight(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Sword
    final sword = Path()
      ..moveTo(w * 0.2, h * 0.8)
      ..lineTo(w * 0.7, h * 0.3)
      ..lineTo(w * 0.75, h * 0.35)
      ..lineTo(w * 0.25, h * 0.85)
      ..close()
      ..moveTo(w * 0.15, h * 0.75)
      ..lineTo(w * 0.3, h * 0.9)
      ..moveTo(w * 0.15, h * 0.85)
      ..lineTo(w * 0.2, h * 0.8);

    canvas.drawPath(sword.shift(offset), fill);
    canvas.drawPath(sword, outline);
  }

  void _drawSquat(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Squatting character path
    final body = Path()
      // Head
      ..addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.25), radius: 10))
      // Torso / legs bent
      ..moveTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.5, h * 0.55)
      ..lineTo(w * 0.35, h * 0.6)
      ..lineTo(w * 0.38, h * 0.8) // Left leg
      ..moveTo(w * 0.5, h * 0.55)
      ..lineTo(w * 0.65, h * 0.6)
      ..lineTo(w * 0.62, h * 0.8) // Right leg
      // Arms out
      ..moveTo(w * 0.5, h * 0.42)
      ..lineTo(w * 0.25, h * 0.42)
      ..moveTo(w * 0.5, h * 0.42)
      ..lineTo(w * 0.75, h * 0.42);

    canvas.drawPath(body, outline);
  }

  void _drawMusic(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Double music note
    final note = Path()
      ..moveTo(w * 0.35, h * 0.6)
      ..lineTo(w * 0.35, h * 0.2)
      ..lineTo(w * 0.7, h * 0.12)
      ..lineTo(w * 0.7, h * 0.52)
      ..moveTo(w * 0.35, h * 0.28)
      ..lineTo(w * 0.7, h * 0.2)
      ..addOval(Rect.fromCircle(center: Offset(w * 0.27, h * 0.6), radius: 8))
      ..addOval(Rect.fromCircle(center: Offset(w * 0.62, h * 0.52), radius: 8));

    canvas.drawPath(note.shift(offset), fill);
    canvas.drawPath(note, outline);
  }

  void _drawLimp(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Bandaged leg / crutch
    final crutch = Path()
      ..moveTo(w * 0.3, h * 0.25)
      ..lineTo(w * 0.5, h * 0.85)
      ..moveTo(w * 0.25, h * 0.28)
      ..lineTo(w * 0.35, h * 0.22)
      ..moveTo(w * 0.38, h * 0.5)
      ..lineTo(w * 0.48, h * 0.48);

    final leg = Path()
      ..moveTo(w * 0.6, h * 0.3)
      ..lineTo(w * 0.65, h * 0.65)
      ..lineTo(w * 0.8, h * 0.7)
      ..lineTo(w * 0.75, h * 0.78)
      ..lineTo(w * 0.55, h * 0.72)
      ..close();

    canvas.drawPath(leg.shift(offset), fill);
    canvas.drawPath(leg, outline);
    canvas.drawPath(crutch, outline);
  }

  void _drawHeart(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Cute love heart
    final heart = Path()
      ..moveTo(w * 0.5, h * 0.35)
      ..cubicTo(w * 0.2, h * 0.1, w * 0.1, h * 0.5, w * 0.5, h * 0.85)
      ..cubicTo(w * 0.9, h * 0.5, w * 0.8, h * 0.1, w * 0.5, h * 0.35)
      ..close();

    canvas.drawPath(heart.shift(offset), fill);
    canvas.drawPath(heart, outline);
  }

  void _drawWhisper(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Ear and sound ripples
    final ear = Path()
      ..moveTo(w * 0.45, h * 0.2)
      ..quadraticBezierTo(w * 0.7, h * 0.2, w * 0.7, h * 0.45)
      ..quadraticBezierTo(w * 0.7, h * 0.7, w * 0.5, h * 0.75)
      ..quadraticBezierTo(w * 0.35, h * 0.8, w * 0.35, h * 0.7)
      ..quadraticBezierTo(w * 0.4, h * 0.6, w * 0.5, h * 0.5)
      ..quadraticBezierTo(w * 0.55, h * 0.4, w * 0.45, h * 0.35);

    final ripple = Path()
      ..moveTo(w * 0.2, h * 0.38)
      ..quadraticBezierTo(w * 0.25, h * 0.45, w * 0.2, h * 0.52)
      ..moveTo(w * 0.28, h * 0.33)
      ..quadraticBezierTo(w * 0.35, h * 0.45, w * 0.28, h * 0.57);

    canvas.drawPath(ear.shift(offset), fill);
    canvas.drawPath(ear, outline);
    canvas.drawPath(ripple, outline);
  }

  void _drawAirplane(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Paper airplane flying up-right
    final plane = Path()
      ..moveTo(w * 0.2, h * 0.6)
      ..lineTo(w * 0.8, h * 0.2)
      ..lineTo(w * 0.55, h * 0.7)
      ..lineTo(w * 0.45, h * 0.8)
      ..lineTo(w * 0.42, h * 0.6)
      ..close()
      ..moveTo(w * 0.2, h * 0.6)
      ..lineTo(w * 0.55, h * 0.7)
      ..moveTo(w * 0.42, h * 0.6)
      ..lineTo(w * 0.8, h * 0.2);

    canvas.drawPath(plane.shift(offset), fill);
    canvas.drawPath(plane, outline);
  }

  void _drawGuide(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Open guide book
    final book = Path()
      ..moveTo(w * 0.15, h * 0.75)
      ..lineTo(w * 0.15, h * 0.3)
      ..quadraticBezierTo(w * 0.35, h * 0.25, w * 0.5, h * 0.35)
      ..quadraticBezierTo(w * 0.65, h * 0.25, w * 0.85, h * 0.3)
      ..lineTo(w * 0.85, h * 0.75)
      ..quadraticBezierTo(w * 0.65, h * 0.7, w * 0.5, h * 0.8)
      ..quadraticBezierTo(w * 0.35, h * 0.7, w * 0.15, h * 0.75)
      ..close()
      ..moveTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.5, h * 0.8);

    canvas.drawPath(book.shift(offset), fill);
    canvas.drawPath(book, outline);
  }

  void _drawFriends(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Two friends standing arm-in-arm
    final friends = Path()
      // Left friend
      ..addOval(Rect.fromCircle(center: Offset(w * 0.38, h * 0.33), radius: 8))
      ..moveTo(w * 0.38, h * 0.42)
      ..lineTo(w * 0.38, h * 0.75)
      // Right friend
      ..addOval(Rect.fromCircle(center: Offset(w * 0.62, h * 0.33), radius: 8))
      ..moveTo(w * 0.62, h * 0.42)
      ..lineTo(w * 0.62, h * 0.75)
      // Arm holding together
      ..moveTo(w * 0.3, h * 0.5)
      ..lineTo(w * 0.7, h * 0.5);

    canvas.drawPath(friends, outline);
  }

  void _drawMic(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Vintage microphone
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.4, h * 0.2, w * 0.2, h * 0.38),
      const Radius.circular(10),
    );

    final stand = Path()
      ..moveTo(w * 0.32, h * 0.45)
      ..quadraticBezierTo(w * 0.5, h * 0.68, w * 0.68, h * 0.45)
      ..moveTo(w * 0.5, h * 0.58)
      ..lineTo(w * 0.5, h * 0.8)
      ..moveTo(w * 0.35, h * 0.8)
      ..lineTo(w * 0.65, h * 0.8);

    canvas.drawRRect(body.shift(offset), fill);
    canvas.drawRRect(body, outline);
    canvas.drawPath(stand, outline);
  }

  void _drawPoem(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Scroll and feather quill
    final scroll = Path()
      ..moveTo(w * 0.2, h * 0.25)
      ..lineTo(w * 0.65, h * 0.25)
      ..lineTo(w * 0.65, h * 0.75)
      ..lineTo(w * 0.2, h * 0.75)
      ..close();

    final pen = Path()
      ..moveTo(w * 0.85, h * 0.15)
      ..quadraticBezierTo(w * 0.65, h * 0.45, w * 0.5, h * 0.8)
      ..lineTo(w * 0.45, h * 0.82)
      ..lineTo(w * 0.5, h * 0.75);

    canvas.drawPath(scroll.shift(offset), fill);
    canvas.drawPath(scroll, outline);
    canvas.drawPath(pen, outline);
  }

  void _drawGlobe(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Globe with coordinates
    canvas.drawCircle(Offset(w * 0.5, h * 0.5) + offset, w * 0.35, fill);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.35, outline);

    final lines = Path()
      ..moveTo(w * 0.15, h * 0.5)
      ..lineTo(w * 0.85, h * 0.5)
      ..moveTo(w * 0.5, h * 0.15)
      ..lineTo(w * 0.5, h * 0.85)
      ..moveTo(w * 0.2, h * 0.3)
      ..quadraticBezierTo(w * 0.5, h * 0.45, w * 0.8, h * 0.3)
      ..moveTo(w * 0.2, h * 0.7)
      ..quadraticBezierTo(w * 0.5, h * 0.55, w * 0.8, h * 0.7);

    canvas.drawPath(lines, outline);
  }

  void _drawStick(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Wood branch / walking stick with crown
    final stick = Path()
      ..moveTo(w * 0.3, h * 0.85)
      ..lineTo(w * 0.65, h * 0.25)
      ..lineTo(w * 0.7, h * 0.28)
      ..lineTo(w * 0.35, h * 0.88)
      ..close()
      ..moveTo(w * 0.55, h * 0.42)
      ..lineTo(w * 0.48, h * 0.46)
      ..moveTo(w * 0.48, h * 0.55)
      ..lineTo(w * 0.4, h * 0.58);

    canvas.drawPath(stick.shift(offset), fill);
    canvas.drawPath(stick, outline);
  }

  void _drawAnimal(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Cartoon animal paw print
    final mainPad = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.6), radius: 14));

    final toeL = Path()..addOval(Rect.fromCircle(center: Offset(w * 0.28, h * 0.4), radius: 7));
    final toeML = Path()..addOval(Rect.fromCircle(center: Offset(w * 0.42, h * 0.28), radius: 7));
    final toeMR = Path()..addOval(Rect.fromCircle(center: Offset(w * 0.58, h * 0.28), radius: 7));
    final toeR = Path()..addOval(Rect.fromCircle(center: Offset(w * 0.72, h * 0.4), radius: 7));

    canvas.drawPath(mainPad.shift(offset), fill);
    canvas.drawPath(mainPad, outline);
    canvas.drawPath(toeL, outline);
    canvas.drawPath(toeML, outline);
    canvas.drawPath(toeMR, outline);
    canvas.drawPath(toeR, outline);
  }

  void _drawLock(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Padlock
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.3, h * 0.45, w * 0.4, h * 0.38),
      const Radius.circular(8),
    );

    final shackle = Path()
      ..moveTo(w * 0.38, h * 0.45)
      ..quadraticBezierTo(w * 0.38, h * 0.2, w * 0.5, h * 0.2)
      ..quadraticBezierTo(w * 0.62, h * 0.2, w * 0.62, h * 0.45);

    canvas.drawRRect(body.shift(offset), fill);
    canvas.drawRRect(body, outline);
    canvas.drawPath(shackle, outline);
  }

  void _drawTheater(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Comedy and tragedy masks
    final maskL = Path()
      ..moveTo(w * 0.15, h * 0.4)
      ..quadraticBezierTo(w * 0.35, h * 0.3, w * 0.45, h * 0.4)
      ..lineTo(w * 0.4, h * 0.75)
      ..quadraticBezierTo(w * 0.25, h * 0.8, w * 0.15, h * 0.75)
      ..close();

    canvas.drawPath(maskL.shift(offset), fill);
    canvas.drawPath(maskL, outline);

    // Eye holes
    canvas.drawCircle(Offset(w * 0.25, h * 0.48), 3, outline..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(w * 0.35, h * 0.48), 3, outline..style = PaintingStyle.fill);
    outline.style = PaintingStyle.stroke;
    
    // Smile
    canvas.drawPath(Path()..moveTo(w * 0.22, h * 0.62)..quadraticBezierTo(w * 0.3, h * 0.7, w * 0.38, h * 0.62), outline);
  }

  void _drawShield(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Shield
    final shield = Path()
      ..moveTo(w * 0.25, h * 0.25)
      ..lineTo(w * 0.75, h * 0.25)
      ..quadraticBezierTo(w * 0.75, h * 0.58, w * 0.5, h * 0.85)
      ..quadraticBezierTo(w * 0.25, h * 0.58, w * 0.25, h * 0.25)
      ..close();

    canvas.drawPath(shield.shift(offset), fill);
    canvas.drawPath(shield, outline);
  }

  void _drawCrown(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Royal Crown
    final crown = Path()
      ..moveTo(w * 0.2, h * 0.72)
      ..lineTo(w * 0.15, h * 0.35)
      ..lineTo(w * 0.35, h * 0.5)
      ..lineTo(w * 0.5, h * 0.25)
      ..lineTo(w * 0.65, h * 0.5)
      ..lineTo(w * 0.85, h * 0.35)
      ..lineTo(w * 0.8, h * 0.72)
      ..close();

    canvas.drawPath(crown.shift(offset), fill);
    canvas.drawPath(crown, outline);
  }

  void _drawSpy(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Fedora hat and sunglasses
    final hat = Path()
      ..moveTo(w * 0.2, h * 0.42)
      ..lineTo(w * 0.8, h * 0.42)
      ..moveTo(w * 0.3, h * 0.42)
      ..lineTo(w * 0.32, h * 0.22)
      ..quadraticBezierTo(w * 0.5, h * 0.16, w * 0.68, h * 0.22)
      ..lineTo(w * 0.7, h * 0.42);

    final glasses = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.38, h * 0.56), radius: 8))
      ..addOval(Rect.fromCircle(center: Offset(w * 0.62, h * 0.56), radius: 8))
      ..moveTo(w * 0.46, h * 0.56)
      ..lineTo(w * 0.54, h * 0.56);

    canvas.drawPath(hat.shift(offset), fill);
    canvas.drawPath(hat, outline);
    canvas.drawPath(glasses, outline);
  }

  void _drawPointer(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Stop hand icon
    final hand = Path()
      ..moveTo(w * 0.4, h * 0.8)
      ..lineTo(w * 0.4, h * 0.4)
      ..quadraticBezierTo(w * 0.45, h * 0.35, w * 0.5, h * 0.4)
      ..lineTo(w * 0.5, h * 0.8);

    canvas.drawPath(hand, outline);
  }

  void _drawQuestion(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Question Mark
    final q = Path()
      ..moveTo(w * 0.35, h * 0.35)
      ..quadraticBezierTo(w * 0.5, h * 0.2, w * 0.65, h * 0.35)
      ..quadraticBezierTo(w * 0.62, h * 0.52, w * 0.5, h * 0.55)
      ..lineTo(w * 0.5, h * 0.68)
      ..moveTo(w * 0.5, h * 0.8);

    canvas.drawPath(q, outline);
  }

  void _drawBook(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Open book
    final book = Path()
      ..moveTo(w * 0.2, h * 0.7)
      ..lineTo(w * 0.2, h * 0.25)
      ..quadraticBezierTo(w * 0.38, h * 0.2, w * 0.5, h * 0.3)
      ..quadraticBezierTo(w * 0.62, h * 0.2, w * 0.8, h * 0.25)
      ..lineTo(w * 0.8, h * 0.7)
      ..close();

    canvas.drawPath(book.shift(offset), fill);
    canvas.drawPath(book, outline);
  }

  void _drawStone(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Heavy round stone
    final stone = Path()
      ..addOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.55), width: w * 0.55, height: h * 0.42));

    final shine = Path()
      ..moveTo(w * 0.6, h * 0.25)
      ..lineTo(w * 0.65, h * 0.15)
      ..moveTo(w * 0.75, h * 0.32)
      ..lineTo(w * 0.85, h * 0.32);

    canvas.drawPath(stone.shift(offset), fill);
    canvas.drawPath(stone, outline);
    canvas.drawPath(shine, outline);
  }

  void _drawLeaf(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Green leaf
    final leaf = Path()
      ..moveTo(w * 0.25, h * 0.75)
      ..cubicTo(w * 0.1, h * 0.35, w * 0.5, h * 0.15, w * 0.75, h * 0.25)
      ..cubicTo(w * 0.9, h * 0.65, w * 0.5, h * 0.85, w * 0.25, h * 0.75)
      ..close()
      ..moveTo(w * 0.25, h * 0.75)
      ..lineTo(w * 0.6, h * 0.4);

    canvas.drawPath(leaf.shift(offset), fill);
    canvas.drawPath(leaf, outline);
  }

  void _drawRobot(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Cute robot head
    final head = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.25, h * 0.3, w * 0.5, h * 0.45),
      const Radius.circular(8),
    );

    final ears = Path()
      ..moveTo(w * 0.25, h * 0.48)
      ..lineTo(w * 0.18, h * 0.48)
      ..moveTo(w * 0.75, h * 0.48)
      ..lineTo(w * 0.82, h * 0.48);

    canvas.drawRRect(head.shift(offset), fill);
    canvas.drawRRect(head, outline);
    canvas.drawPath(ears, outline);
  }

  void _drawStatue(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Stiff statue pose
    final fig = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.22), radius: 8))
      ..moveTo(w * 0.5, h * 0.3)
      ..lineTo(w * 0.5, h * 0.6)
      ..lineTo(w * 0.45, h * 0.85)
      ..moveTo(w * 0.5, h * 0.6)
      ..lineTo(w * 0.55, h * 0.85)
      ..moveTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.32, h * 0.35)
      ..moveTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.68, h * 0.35);

    canvas.drawPath(fig, outline);
  }

  void _drawClap(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Clapping hands
    final handL = Path()
      ..moveTo(w * 0.22, h * 0.72)
      ..lineTo(w * 0.42, h * 0.42)
      ..lineTo(w * 0.48, h * 0.46)
      ..lineTo(w * 0.3, h * 0.78)
      ..close();

    final handR = Path()
      ..moveTo(w * 0.78, h * 0.72)
      ..lineTo(w * 0.58, h * 0.42)
      ..lineTo(w * 0.52, h * 0.46)
      ..lineTo(w * 0.7, h * 0.78)
      ..close();

    canvas.drawPath(handL.shift(offset), fill);
    canvas.drawPath(handL, outline);
    canvas.drawPath(handR.shift(offset), fill);
    canvas.drawPath(handR, outline);
  }

  void _drawService(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Tray with dome
    final tray = Path()
      ..moveTo(w * 0.2, h * 0.65)
      ..lineTo(w * 0.8, h * 0.65)
      ..lineTo(w * 0.75, h * 0.7)
      ..lineTo(w * 0.25, h * 0.7)
      ..close();

    final dome = Path()
      ..moveTo(w * 0.3, h * 0.65)
      ..quadraticBezierTo(w * 0.3, h * 0.32, w * 0.5, h * 0.32)
      ..quadraticBezierTo(w * 0.7, h * 0.32, w * 0.7, h * 0.65);

    canvas.drawPath(dome.shift(offset), fill);
    canvas.drawPath(dome, outline);
    canvas.drawPath(tray, outline);
  }

  void _drawPray(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Praying hands / folded hands
    final pray = Path()
      ..moveTo(w * 0.4, h * 0.8)
      ..lineTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.6, h * 0.8)
      ..close();

    canvas.drawPath(pray.shift(offset), fill);
    canvas.drawPath(pray, outline);
  }

  void _drawCross(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Crossed arms
    final cross = Path()
      ..moveTo(w * 0.25, h * 0.42)
      ..lineTo(w * 0.75, h * 0.75)
      ..moveTo(w * 0.75, h * 0.42)
      ..lineTo(w * 0.25, h * 0.75);

    canvas.drawPath(cross, outline);
  }

  void _drawPhone(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Mobile phone crossed out
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.35, h * 0.25, w * 0.3, h * 0.5),
      const Radius.circular(8),
    );

    final line = Path()
      ..moveTo(w * 0.25, h * 0.3)
      ..lineTo(w * 0.75, h * 0.7);

    canvas.drawRRect(body.shift(offset), fill);
    canvas.drawRRect(body, outline);
    canvas.drawPath(line, outline);
  }

  void _drawSlow(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Cute cartoon snail
    final shell = Path()
      ..addOval(Rect.fromCircle(center: Offset(w * 0.42, h * 0.5), radius: 15));

    final body = Path()
      ..moveTo(w * 0.15, h * 0.65)
      ..lineTo(w * 0.7, h * 0.65)
      ..quadraticBezierTo(w * 0.82, h * 0.65, w * 0.8, h * 0.48)
      ..lineTo(w * 0.74, h * 0.48)
      ..lineTo(w * 0.72, h * 0.65)
      ..close();

    canvas.drawPath(body.shift(offset), fill);
    canvas.drawPath(body, outline);
    canvas.drawPath(shell.shift(offset), fill);
    canvas.drawPath(shell, outline);
  }

  void _drawFast(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Lightning bolt
    final bolt = Path()
      ..moveTo(w * 0.55, h * 0.18)
      ..lineTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.48, h * 0.52)
      ..lineTo(w * 0.4, h * 0.85)
      ..lineTo(w * 0.72, h * 0.45)
      ..lineTo(w * 0.52, h * 0.45)
      ..close();

    canvas.drawPath(bolt.shift(offset), fill);
    canvas.drawPath(bolt, outline);
  }

  void _drawCloud(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Cute fluffy cloud
    final cloud = Path()
      ..moveTo(w * 0.3, h * 0.6)
      ..quadraticBezierTo(w * 0.2, h * 0.52, w * 0.28, h * 0.42)
      ..quadraticBezierTo(w * 0.32, h * 0.25, w * 0.5, h * 0.28)
      ..quadraticBezierTo(w * 0.68, h * 0.25, w * 0.72, h * 0.42)
      ..quadraticBezierTo(w * 0.8, h * 0.52, w * 0.7, h * 0.6)
      ..close();

    canvas.drawPath(cloud.shift(offset), fill);
    canvas.drawPath(cloud, outline);
  }

  void _drawLuck(Canvas canvas, Size size, Paint fill, Paint outline, Offset offset) {
    final w = size.width;
    final h = size.height;

    // Five-pointed star
    final star = Path()
      ..moveTo(w * 0.5, h * 0.15)
      ..lineTo(w * 0.62, h * 0.38)
      ..lineTo(w * 0.85, h * 0.42)
      ..lineTo(w * 0.68, h * 0.58)
      ..lineTo(w * 0.72, h * 0.82)
      ..lineTo(w * 0.5, h * 0.7)
      ..lineTo(w * 0.28, h * 0.82)
      ..lineTo(w * 0.32, h * 0.58)
      ..lineTo(w * 0.15, h * 0.42)
      ..lineTo(w * 0.38, h * 0.38)
      ..close();

    canvas.drawPath(star.shift(offset), fill);
    canvas.drawPath(star, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
