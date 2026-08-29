int nextReadingLevelBucket(
    {required int currentBucket, required int lastAccuracyPct}) {
  // Buckets map roughly to reading-level bands for practice content.
  if (lastAccuracyPct >= 80) return (currentBucket + 1).clamp(3, 6);
  if (lastAccuracyPct < 60) return (currentBucket - 1).clamp(3, 6);
  return currentBucket.clamp(3, 6);
}
