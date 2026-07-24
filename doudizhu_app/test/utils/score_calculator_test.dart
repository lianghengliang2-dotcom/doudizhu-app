import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu_app/utils/score_calculator.dart';

void main() {
  group('calculateBaseScore', () {
    test('N=0 returns 5', () {
      expect(calculateBaseScore(0), 5);
    });
    test('N=1 returns 10', () {
      expect(calculateBaseScore(1), 10);
    });
    test('N=2 returns 20', () {
      expect(calculateBaseScore(2), 20);
    });
    test('N=3 returns 40', () {
      expect(calculateBaseScore(3), 40);
    });
    test('N=4 returns 80', () {
      expect(calculateBaseScore(4), 80);
    });
    test('N=5 returns 160 (cap)', () {
      expect(calculateBaseScore(5), 160);
    });
    test('N=6 returns 210', () {
      expect(calculateBaseScore(6), 210);
    });
    test('N=7 returns 260', () {
      expect(calculateBaseScore(7), 260);
    });
    test('N=8 returns 310', () {
      expect(calculateBaseScore(8), 310);
    });
  });

  group('calculateRoundScores - 无踢', () {
    test('地主赢 N=1 (1炸)', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: false,
        blind: false,
        kickCount: 0,
        bombCount: 1,
      );
      expect(result.landlordScore, 10);
      expect(result.farmerAScore, -5);
      expect(result.farmerBScore, -5);
    });

    test('地主赢 N=2 (春天+蒙牌)', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: true,
        blind: true,
        kickCount: 0,
        bombCount: 0,
      );
      expect(result.landlordScore, 20);
      expect(result.farmerAScore, -10);
      expect(result.farmerBScore, -10);
    });

    test('地主输 N=1 (1炸)', () {
      final result = calculateRoundScores(
        isLandlordWin: false,
        spring: false,
        blind: false,
        kickCount: 0,
        bombCount: 1,
      );
      expect(result.landlordScore, -10);
      expect(result.farmerAScore, 5);
      expect(result.farmerBScore, 5);
    });

    test('地主赢 N=5 (封顶)', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: true,
        blind: true,
        kickCount: 0,
        bombCount: 3,
      );
      expect(result.landlordScore, 160);
      expect(result.farmerAScore, -80);
      expect(result.farmerBScore, -80);
    });
  });

  group('calculateRoundScores - 有踢', () {
    test('地主赢 踢=1', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: false,
        blind: false,
        kickCount: 1,
        bombCount: 0,
      );
      // N_base=0, S_base=5
      // N_kick_total=1, S_kick=10
      // farmerA(踢了): -10/2=-5, farmerB: -5/2=-2 (整数除法)
      // landlord: 5+2=7
      expect(result.landlordScore, 7);
      expect(result.farmerAScore, -5);
      expect(result.farmerBScore, -2);
    });

    test('地主赢 踢=2 (踢+反踢)', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: false,
        blind: false,
        kickCount: 2,
        bombCount: 0,
      );
      // N_base=0, S_base=5
      // N_kick_total=2, S_kick=20
      // farmerA: -20/2=-10, farmerB: -5/2=-2
      // landlord: 10+2=12
      expect(result.landlordScore, 12);
      expect(result.farmerAScore, -10);
      expect(result.farmerBScore, -2);
    });

    test('地主赢 N=5+踢=1 (封顶+超封顶)', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: true,
        blind: true,
        kickCount: 1,
        bombCount: 3,
      );
      // N_base=5, S_base=160
      // N_kick_total=6, S_kick=210
      // farmerA: -210/2=-105, farmerB: -160/2=-80
      // landlord: 105+80=185
      expect(result.landlordScore, 185);
      expect(result.farmerAScore, -105);
      expect(result.farmerBScore, -80);
    });

    test('地主输 踢=1', () {
      final result = calculateRoundScores(
        isLandlordWin: false,
        spring: false,
        blind: false,
        kickCount: 1,
        bombCount: 0,
      );
      // N_base=0, S_base=5
      // N_kick_total=1, S_kick=10
      // landlord: -(5+2)=-7, farmerA: 5, farmerB: 2
      expect(result.landlordScore, -7);
      expect(result.farmerAScore, 5);
      expect(result.farmerBScore, 2);
    });
  });
}
