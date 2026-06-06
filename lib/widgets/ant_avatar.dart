import 'package:flutter/material.dart';

/// An avatar widget matching Ant Messenger style
class AntAvatar extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final bool showOnline;
  final double onlineDotSize;

  const AntAvatar({
    super.key,
    required this.text,
    this.size = 40,
    this.color,
    this.showOnline = false,
    this.onlineDotSize = 10,
  });

  static const _colors = [
    Color(0xFF1AA4EC), Color(0xFF52C41A), Color(0xFFFAAD14),
    Color(0xFFFF4D4F), Color(0xFF722ED1), Color(0xFF13C2C2),
    Color(0xFFEB2F96), Color(0xFFFA8C16),
  ];

  static Color getColor(String name) {
    int h = 0;
    for (int i = 0; i < name.length; i++) h = name.codeUnitAt(i) + ((h << 5) - h);
    return _colors[(h.abs() % _colors.length)];
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? getColor(text);
    final fontSize = size * 0.35;
    final radius = size * 0.25;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: Text(
              text.isNotEmpty ? text.characters.first : '?',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (showOnline)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: onlineDotSize,
              height: onlineDotSize,
              decoration: BoxDecoration(
                color: const Color(0xFF52C41A),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF141D4D)
                      : Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Online status indicator
class OnlineDot extends StatelessWidget {
  final double size;
  const OnlineDot({super.key, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF52C41A),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF141D4D)
              : Colors.white,
          width: 2,
        ),
      ),
    );
  }
}

/// Unread badge
class UnreadBadge extends StatelessWidget {
  final int count;
  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
