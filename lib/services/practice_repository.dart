import 'package:cloud_functions/cloud_functions.dart';

/// A reading practice item shown to the student.
class PracticeItem {
  const PracticeItem({
    required this.sentence,
    required this.question,
    required this.ideal,
  });

  /// The passage/sentence the student reads.
  final String sentence;

  /// The comprehension question asked.
  final String question;

  /// The ideal answer (used for soft-match scoring).
  final String ideal;
}

/// Provides reading comprehension items grouped by reading level bucket.
class PracticeRepository {
  /// Loads items for the given reading-level [bucket] (3 or 4).
  ///
  /// When the student has a Today's Goal, SparkLearn first attempts to
  /// generate practice specifically for that goal. Existing local practice
  /// items remain available as a fallback if AI generation is unavailable.
  Future<List<PracticeItem>> loadReadingItems(
    int bucket, {
    String? goal,
  }) async {
    await Future.delayed(const Duration(milliseconds: 80));

    final cleanGoal = (goal ?? '').trim();
    final normalizedGoal = cleanGoal.toLowerCase();

    if (cleanGoal.isNotEmpty) {
      try {
        final functions = FirebaseFunctions.instanceFor(
          region: 'us-central1',
        );

        final callable = functions.httpsCallable(
          'generatePractice',
          options: HttpsCallableOptions(
            timeout: const Duration(seconds: 60),
          ),
        );

        final result = await callable.call<Map<String, dynamic>>({
          'goal': cleanGoal,
          'readingLevel': bucket,
        });

        final data = result.data;
        final rawItems = data['items'];

        if (data['ok'] == true && rawItems is List) {
          final generatedItems = rawItems
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .where(
                (item) =>
                    item['sentence'] is String &&
                    item['question'] is String &&
                    item['ideal'] is String,
              )
              .map(
                (item) => PracticeItem(
                  sentence: (item['sentence'] as String).trim(),
                  question: (item['question'] as String).trim(),
                  ideal: (item['ideal'] as String).trim(),
                ),
              )
              .where(
                (item) =>
                    item.sentence.isNotEmpty &&
                    item.question.isNotEmpty &&
                    item.ideal.isNotEmpty,
              )
              .toList();

          if (generatedItems.isNotEmpty) {
            return generatedItems;
          }
        }
      } catch (_) {
        // Keep the existing local practice system as the fallback.
      }
    }

    if (normalizedGoal.contains('spelling') ||
        normalizedGoal.contains('spell')) {
      return bucket <= 3 ? _spelling3 : _spelling4;
    }

    if (normalizedGoal.contains('vocabulary') ||
        normalizedGoal.contains('context clue')) {
      return bucket <= 3 ? _vocabulary3 : _vocabulary4;
    }

    if (normalizedGoal.contains('main idea')) {
      return bucket <= 3 ? _mainIdea3 : _mainIdea4;
    }

    if (normalizedGoal.contains('inference') ||
        normalizedGoal.contains('infer')) {
      return bucket <= 3 ? _inference3 : _inference4;
    }

    return bucket <= 3 ? _bucket3 : _bucket4;
  }
}

// Grade 3 items

const _bucket3 = <PracticeItem>[
  PracticeItem(
    sentence:
        'The little turtle moved slowly across the sandy beach toward the bright blue ocean.',
    question: 'Where is the turtle going?',
    ideal: 'The turtle is going toward the ocean or the water.',
  ),
  PracticeItem(
    sentence:
        'Maya loved rainy days because she could curl up with a warm blanket and read her favorite books.',
    question: 'What does Maya like to do on rainy days?',
    ideal: 'Maya likes to curl up with a blanket and read books.',
  ),
  PracticeItem(
    sentence:
        'The baker woke up at five in the morning to make fresh bread before the shop opened.',
    question: 'Why did the baker wake up so early?',
    ideal:
        'The baker woke up early to make fresh bread before the shop opened.',
  ),
  PracticeItem(
    sentence:
        'Sam found a small bird with an injured wing sitting under the old oak tree.',
    question: 'What was wrong with the bird Sam found?',
    ideal: 'The bird had an injured or hurt wing.',
  ),
  PracticeItem(
    sentence:
        'The children cheered loudly when the coach said they had won the championship.',
    question: 'Why did the children cheer?',
    ideal: 'They cheered because they won the championship.',
  ),
];

// Grade 4 items

const _bucket4 = <PracticeItem>[
  PracticeItem(
    sentence:
        'Despite the heavy rain, the rescue team continued searching through the night because every minute counted.',
    question: 'Why did the rescue team keep searching even in the rain?',
    ideal:
        'They continued searching because every minute was important and someone needed to be rescued.',
  ),
  PracticeItem(
    sentence:
        'The scientist carefully recorded every measurement in her notebook so that other researchers could repeat the experiment.',
    question: 'Why did the scientist write down every measurement?',
    ideal:
        'She recorded the measurements so other researchers could repeat or replicate the experiment.',
  ),
  PracticeItem(
    sentence:
        'When the old library was threatened with demolition, students organized a petition that collected over two thousand signatures.',
    question: 'What did the students do to protect the library?',
    ideal:
        'The students organized a petition and collected over two thousand signatures.',
  ),
  PracticeItem(
    sentence:
        'Amara practiced her speech every evening for a week, yet still felt nervous when she finally stood in front of the crowd.',
    question:
        'How did Amara feel during her speech, and why is that surprising?',
    ideal:
        'She felt nervous even though she had practiced a lot every evening for a week.',
  ),
  PracticeItem(
    sentence:
        'The ancient map contained symbols that no one had been able to decode for centuries, until a young archaeologist noticed a pattern.',
    question: 'What made the young archaeologist important to this story?',
    ideal:
        'The archaeologist noticed a pattern and was finally able to decode the symbols that had puzzled people for centuries.',
  ),
];

// Vocabulary and context clues - Grade 3
const _vocabulary3 = <PracticeItem>[
  PracticeItem(
    sentence:
        'Lena was exhausted after running around the playground for an hour.',
    question: 'What does exhausted most likely mean?',
    ideal: 'Exhausted means very tired.',
  ),
  PracticeItem(
    sentence: 'The tiny kitten cautiously stepped toward the much larger dog.',
    question: 'What does cautiously mean in this sentence?',
    ideal: 'Cautiously means carefully or with care.',
  ),
  PracticeItem(
    sentence: 'The glass vase was fragile, so Mia carried it with both hands.',
    question: 'What does fragile mean?',
    ideal: 'Fragile means easily broken.',
  ),
];

// Vocabulary and context clues - Grade 4
const _vocabulary4 = <PracticeItem>[
  PracticeItem(
    sentence:
        'The hikers were relieved when they finally reached the shelter before the storm.',
    question: 'What does relieved mean in this sentence?',
    ideal: 'Relieved means no longer worried or afraid.',
  ),
  PracticeItem(
    sentence:
        'Marcus was reluctant to enter the contest, but his teacher encouraged him.',
    question: 'What does reluctant most likely mean?',
    ideal: 'Reluctant means unsure or unwilling to do something.',
  ),
  PracticeItem(
    sentence:
        'The museum displayed an ancient artifact that had been preserved for centuries.',
    question: 'What does preserved mean?',
    ideal: 'Preserved means kept safe or protected from damage.',
  ),
];

// Main idea - Grade 3
const _mainIdea3 = <PracticeItem>[
  PracticeItem(
    sentence:
        'Bees visit flowers to collect nectar. As they move from flower to flower, they also carry pollen that helps plants grow new seeds.',
    question: 'What is the main idea?',
    ideal: 'Bees help plants reproduce while collecting nectar.',
  ),
  PracticeItem(
    sentence:
        'Carlos feeds his dog every morning, fills the water bowl, and takes the dog outside before school.',
    question: 'What is the main idea?',
    ideal: 'Carlos takes care of his dog every morning.',
  ),
];

// Main idea - Grade 4
const _mainIdea4 = <PracticeItem>[
  PracticeItem(
    sentence:
        'Trees provide shade, produce oxygen, give animals places to live, and help prevent soil from washing away.',
    question: 'What is the main idea of this paragraph?',
    ideal:
        'Trees provide many important benefits to people and the environment.',
  ),
  PracticeItem(
    sentence:
        'Recycling paper, glass, and plastic reduces waste and allows materials to be used again instead of being thrown away.',
    question: 'What is the main idea?',
    ideal: 'Recycling reduces waste by allowing materials to be reused.',
  ),
];

// Inference - Grade 3
const _inference3 = <PracticeItem>[
  PracticeItem(
    sentence:
        'Jordan grabbed an umbrella and put on his rain boots before walking outside.',
    question: 'What can you infer about the weather?',
    ideal: 'It is probably raining or expected to rain.',
  ),
  PracticeItem(
    sentence: 'Nina blew out the candles while her family sang and clapped.',
    question: 'What can you infer is happening?',
    ideal: 'Nina is celebrating her birthday.',
  ),
];

// Inference - Grade 4
const _inference4 = <PracticeItem>[
  PracticeItem(
    sentence:
        'The lights were off, the parking lot was empty, and a sign on the door listed opening time as 9:00 a.m.',
    question: 'What can you infer about the store?',
    ideal: 'The store is probably closed.',
  ),
  PracticeItem(
    sentence:
        'Eli studied every evening, reviewed his notes twice, and smiled when the teacher placed the test on his desk.',
    question: 'What can you infer about how Eli feels about the test?',
    ideal: 'Eli probably feels prepared or confident.',
  ),
];

// Spelling - Grade 3
const _spelling3 = <PracticeItem>[
  PracticeItem(
    sentence: 'Which word is spelled correctly?',
    question: 'Choose the correct spelling.',
    ideal: 'beautiful',
  ),
  PracticeItem(
    sentence: 'Which word is spelled correctly?',
    question: 'Choose the correct spelling.',
    ideal: 'because',
  ),
  PracticeItem(
    sentence: 'Which word is spelled correctly?',
    question: 'Choose the correct spelling.',
    ideal: 'different',
  ),
  PracticeItem(
    sentence: 'Which word is spelled correctly?',
    question: 'Choose the correct spelling.',
    ideal: 'favorite',
  ),
  PracticeItem(
    sentence: 'Which word is spelled correctly?',
    question: 'Choose the correct spelling.',
    ideal: 'remember',
  ),
];

// Spelling - Grade 4
const _spelling4 = <PracticeItem>[
  PracticeItem(
    sentence: 'Which word is spelled correctly?',
    question: 'Choose the correct spelling.',
    ideal: 'necessary',
  ),
  PracticeItem(
    sentence: 'Which word is spelled correctly?',
    question: 'Choose the correct spelling.',
    ideal: 'separate',
  ),
  PracticeItem(
    sentence: 'Which word is spelled correctly?',
    question: 'Choose the correct spelling.',
    ideal: 'environment',
  ),
  PracticeItem(
    sentence: 'Which word is spelled correctly?',
    question: 'Choose the correct spelling.',
    ideal: 'beginning',
  ),
  PracticeItem(
    sentence: 'Which word is spelled correctly?',
    question: 'Choose the correct spelling.',
    ideal: 'knowledge',
  ),
];

