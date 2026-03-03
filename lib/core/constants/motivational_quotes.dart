import 'dart:math';

class MotivationalQuotes {
  static final _random = Random();

  static const List<Map<String, String>> quotes = [
    {
      'quote': 'We are what we repeatedly do. Excellence, then, is not an act, but a habit.',
      'author': 'Aristotle',
    },
    {
      'quote': 'The secret of getting ahead is getting started.',
      'author': 'Mark Twain',
    },
    {
      'quote': 'Success is the sum of small efforts, repeated day in and day out.',
      'author': 'Robert Collier',
    },
    {
      'quote': 'Motivation is what gets you started. Habit is what keeps you going.',
      'author': 'Jim Ryun',
    },
    {
      'quote': 'A journey of a thousand miles begins with a single step.',
      'author': 'Lao Tzu',
    },
    {
      'quote': 'It does not matter how slowly you go as long as you do not stop.',
      'author': 'Confucius',
    },
    {
      'quote': 'The only way to do great work is to love what you do.',
      'author': 'Steve Jobs',
    },
    {
      'quote': 'Small daily improvements over time lead to stunning results.',
      'author': 'Robin Sharma',
    },
    {
      'quote': 'Discipline is the bridge between goals and accomplishment.',
      'author': 'Jim Rohn',
    },
    {
      'quote': 'You will never change your life until you change something you do daily.',
      'author': 'John C. Maxwell',
    },
    {
      'quote': 'First forget inspiration. Habit is more dependable.',
      'author': 'Octavia Butler',
    },
    {
      'quote': 'Chains of habit are too light to be felt until they are too heavy to be broken.',
      'author': 'Warren Buffett',
    },
    {
      'quote': 'The difference between who you are and who you want to be is what you do.',
      'author': 'Bill Phillips',
    },
    {
      'quote': 'Your habits will determine your future.',
      'author': 'Jack Canfield',
    },
    {
      'quote': 'Every action you take is a vote for the type of person you wish to become.',
      'author': 'James Clear',
    },
    {
      'quote': 'Don\'t count the days, make the days count.',
      'author': 'Muhammad Ali',
    },
    {
      'quote': 'The best time to plant a tree was 20 years ago. The second best time is now.',
      'author': 'Chinese Proverb',
    },
    {
      'quote': 'Be the change that you wish to see in the world.',
      'author': 'Mahatma Gandhi',
    },
    {
      'quote': 'What you do every day matters more than what you do once in a while.',
      'author': 'Gretchen Rubin',
    },
    {
      'quote': 'Start where you are. Use what you have. Do what you can.',
      'author': 'Arthur Ashe',
    },
  ];

  static Map<String, String> getRandom() {
    return quotes[_random.nextInt(quotes.length)];
  }

  /// Get a quote based on the day (same quote all day)
  static Map<String, String> getDaily() {
    final dayOfYear = DateTime.now().difference(
      DateTime(DateTime.now().year, 1, 1),
    ).inDays;
    return quotes[dayOfYear % quotes.length];
  }
}
