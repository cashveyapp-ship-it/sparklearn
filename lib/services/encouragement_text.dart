import '../models/encouragement.dart';

String encouragementText(String key) {
  switch (key) {
    case EncouragementMessageKey.keepItUp:
      return 'ðŸ‘ Keep it up!';
    case EncouragementMessageKey.proudOfYou:
      return 'â­ Proud of you';
    case EncouragementMessageKey.stayConsistent:
      return 'ðŸ’ª Stay consistent';
    default:
      return 'ðŸ‘ Keep it up!';
  }
}
