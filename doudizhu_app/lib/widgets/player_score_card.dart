import 'package:flutter/material.dart';

class PlayerScoreCard extends StatelessWidget {
  final String name;
  final String colorHex;
  final int score;

  const PlayerScoreCard({
    super.key,
    required this.name,
    required this.colorHex,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1C1410),
            Color(0xFF2A1F18),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC4952A), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B6914).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gold accent line at top
          Container(
            height: 3,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B6914), Color(0xFFC4952A), Color(0xFF8B6914)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _parseColor(colorHex),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC4952A), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              name.characters.first,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(color: Color(0xFFF5E6C8), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '${score >= 0 ? '+' : ''}$score',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: score >= 0 ? const Color(0xFFFF6B35) : const Color(0xFF4CAF50),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final code = hex.replaceFirst('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}
