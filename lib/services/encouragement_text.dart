import '../models/encouragement.dart';

String encouragementText(String key) {
  switch (key) {
    case EncouragementMessageKey.keepItUp:
      return '👍 Keep it up!';
    case EncouragementMessageKey.proudOfYou:
      return '⭐ Proud of you';
    case EncouragementMessageKey.stayConsistent:
      return '💪 Stay consistent';
    default:
      return '👍 Keep it up!';
  }
}
