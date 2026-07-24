class RoundScoreResult {
  final int landlordScore;
  final int farmerAScore;
  final int farmerBScore;

  const RoundScoreResult({
    required this.landlordScore,
    required this.farmerAScore,
    required this.farmerBScore,
  });
}

int calculateBaseScore(int n) {
  if (n <= 5) return 5 * (1 << n);
  return 160 + (n - 5) * 50;
}

RoundScoreResult calculateRoundScores({
  required bool isLandlordWin,
  required bool spring,
  required bool blind,
  required int kickCount,
  required int bombCount,
}) {
  final nBase = (spring ? 1 : 0) + (blind ? 1 : 0) + bombCount;
  final sBase = calculateBaseScore(nBase);

  final int sKick;
  if (kickCount > 0) {
    sKick = calculateBaseScore(nBase + kickCount);
  } else {
    sKick = sBase;
  }

  final int farmerADelta = sKick ~/ 2;
  final int farmerBDelta = sBase ~/ 2;

  int landlordScore = farmerADelta + farmerBDelta;
  int farmerAScore = -farmerADelta;
  int farmerBScore = -farmerBDelta;

  if (!isLandlordWin) {
    landlordScore = -landlordScore;
    farmerAScore = -farmerAScore;
    farmerBScore = -farmerBScore;
  }

  return RoundScoreResult(
    landlordScore: landlordScore,
    farmerAScore: farmerAScore,
    farmerBScore: farmerBScore,
  );
}
