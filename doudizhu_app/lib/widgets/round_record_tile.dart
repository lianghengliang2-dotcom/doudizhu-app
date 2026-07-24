import 'package:flutter/material.dart';
import '../models/round.dart';

class RoundRecordTile extends StatelessWidget {
  final GameRound round;
  final Map<String, String> playerNames;

  const RoundRecordTile({
    super.key,
    required this.round,
    required this.playerNames,
  });

  @override
  Widget build(BuildContext context) {
    final landlordName = playerNames[round.landlordId] ?? '?';
    final result = round.isLandlordWin ? '赢' : '输';
    final resultColor = round.isLandlordWin ? const Color(0xFFE53935) : const Color(0xFF4CAF50);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1410),
            Color(0xFF2A1F18),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF8B6914), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC4952A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF8B6914), width: 1),
                ),
                child: Text(
                  '#${round.roundIndex}',
                  style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(landlordName, style: const TextStyle(color: Color(0xFFF5E6C8), fontWeight: FontWeight.bold)),
              const Text(' 地主', style: TextStyle(color: Color(0xFF8B7355))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: resultColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: resultColor, width: 1),
                ),
                child: Text(result, style: TextStyle(color: resultColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              ..._buildBadges(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: round.scores.entries.map((e) {
              final name = playerNames[e.key] ?? '?';
              final score = e.value;
              return Text(
                '$name ${score >= 0 ? '+' : ''}$score',
                style: TextStyle(
                  color: score >= 0 ? const Color(0xFFFF6B35) : const Color(0xFF4CAF50),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBadges() {
    final items = <String>[];
    if (round.spring) items.add('春');
    if (round.blind) items.add('蒙');
    if (round.kickCount > 0) items.add('踢${round.kickCount}');
    if (round.bombCount > 0) items.add('炸${round.bombCount}');

    return items.map((t) => Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFC4952A).withOpacity(0.2), const Color(0xFF8B6914).withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF8B6914), width: 1),
      ),
      child: Text(t, style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.bold)),
    )).toList();
  }
}
