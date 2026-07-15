import 'package:convo_coach/features/conversation_import/domain/extraction_models.dart';
import 'package:intl/intl.dart';

class TrailingTimestamp {
  const TrailingTimestamp({required this.messageText, required this.timestamp});

  final String messageText;
  final ParsedTimestamp timestamp;
}

abstract interface class ConversationTimestampParser {
  ParsedTimestamp? parse(String text, {required String locale});

  TrailingTimestamp? extractTrailing(String text, {required String locale});
}

class LocaleAwareTimestampParser implements ConversationTimestampParser {
  const LocaleAwareTimestampParser();

  static final RegExp _timeOnly = RegExp(
    r'^(\d{1,2}):(\d{2})(?:\s*([ap]\.?m\.?))?$',
    caseSensitive: false,
  );
  static final RegExp _numericDate = RegExp(
    r'^(\d{1,4})[./-](\d{1,2})[./-](\d{1,4})$',
  );
  static final RegExp _numericDateTime = RegExp(
    r'^(\d{1,4})[./-](\d{1,2})[./-](\d{1,4})[, ]+('
    r'\d{1,2}:\d{2}(?:\s*[ap]\.?m\.?)?)$',
    caseSensitive: false,
  );
  static final RegExp _trailing = RegExp(
    r'^(.*\S)\s+(\d{1,2}:\d{2}(?:\s*[ap]\.?m\.?)?)$',
    caseSensitive: false,
  );
  static final RegExp _textualDateCandidate = RegExp(
    r'\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
    r'jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|'
    r'dec(?:ember)?)\b.*\b\d{4}\b|\b\d{4}\b.*\b(?:jan(?:uary)?|'
    r'feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|'
    r'aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\b',
    caseSensitive: false,
  );

  @override
  ParsedTimestamp? parse(String text, {required String locale}) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    if (const {'today', 'yesterday'}.contains(normalized.toLowerCase())) {
      return ParsedTimestamp(
        rawText: normalized,
        precision: TimestampPrecision.date,
      );
    }

    final time = _parseTime(normalized);
    if (time != null) return time;

    final numericDateTime = _numericDateTime.firstMatch(normalized);
    if (numericDateTime != null) {
      final date = _parseNumericDate(
        numericDateTime.group(1)!,
        numericDateTime.group(2)!,
        numericDateTime.group(3)!,
        locale,
      );
      final parsedTime = _parseTime(numericDateTime.group(4)!);
      if (date != null && parsedTime != null) {
        final value = DateTime(
          date.year!,
          date.month!,
          date.day!,
          parsedTime.hour!,
          parsedTime.minute!,
        );
        return ParsedTimestamp(
          rawText: normalized,
          precision: TimestampPrecision.dateTime,
          value: value,
          year: value.year,
          month: value.month,
          day: value.day,
          hour: value.hour,
          minute: value.minute,
        );
      }
    }

    final numericDate = _numericDate.firstMatch(normalized);
    if (numericDate != null) {
      return _parseNumericDate(
        numericDate.group(1)!,
        numericDate.group(2)!,
        numericDate.group(3)!,
        locale,
        rawText: normalized,
      );
    }

    if (!_textualDateCandidate.hasMatch(normalized)) return null;
    for (final pattern in _textDateTimePatterns(locale)) {
      final parsed = _tryPattern(normalized, pattern, locale);
      if (parsed != null) {
        final hasTime = pattern.contains('H') || pattern.contains('h');
        return ParsedTimestamp(
          rawText: normalized,
          precision: hasTime
              ? TimestampPrecision.dateTime
              : TimestampPrecision.date,
          value: hasTime ? parsed : null,
          year: parsed.year,
          month: parsed.month,
          day: parsed.day,
          hour: hasTime ? parsed.hour : null,
          minute: hasTime ? parsed.minute : null,
        );
      }
    }
    return null;
  }

  @override
  TrailingTimestamp? extractTrailing(String text, {required String locale}) {
    final match = _trailing.firstMatch(text.trim());
    if (match == null) return null;
    final timestamp = parse(match.group(2)!, locale: locale);
    if (timestamp == null) return null;
    return TrailingTimestamp(
      messageText: match.group(1)!.trim(),
      timestamp: timestamp,
    );
  }

  ParsedTimestamp? _parseTime(String text) {
    final match = _timeOnly.firstMatch(text);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final marker = match.group(3)?.toLowerCase().replaceAll('.', '');
    if (minute > 59 ||
        hour > (marker == null ? 23 : 12) ||
        hour == 0 && marker != null) {
      return null;
    }
    if (marker == 'pm' && hour < 12) hour += 12;
    if (marker == 'am' && hour == 12) hour = 0;
    return ParsedTimestamp(
      rawText: text,
      precision: TimestampPrecision.time,
      hour: hour,
      minute: minute,
    );
  }

  ParsedTimestamp? _parseNumericDate(
    String firstText,
    String secondText,
    String thirdText,
    String locale, {
    String? rawText,
  }) {
    final first = int.parse(firstText);
    final second = int.parse(secondText);
    final third = int.parse(thirdText);
    late int year;
    late int month;
    late int day;
    if (firstText.length == 4) {
      year = first;
      month = second;
      day = third;
    } else {
      year = thirdText.length == 2 ? 2000 + third : third;
      final monthFirst = locale.toLowerCase().startsWith('en_us');
      month = monthFirst ? first : second;
      day = monthFirst ? second : first;
    }
    if (!_isValidDate(year, month, day)) return null;
    return ParsedTimestamp(
      rawText: rawText ?? '$firstText/$secondText/$thirdText',
      precision: TimestampPrecision.date,
      year: year,
      month: month,
      day: day,
    );
  }

  bool _isValidDate(int year, int month, int day) {
    if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
      return false;
    }
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day;
  }

  List<String> _textDateTimePatterns(String locale) => [
    'MMM d, y h:mm a',
    'MMMM d, y h:mm a',
    'd MMM y HH:mm',
    'd MMMM y HH:mm',
    'MMM d, y',
    'MMMM d, y',
    'd MMM y',
    'd MMMM y',
  ];

  DateTime? _tryPattern(String text, String pattern, String locale) {
    try {
      return DateFormat(pattern, locale).parseStrict(text);
    } on Object {
      try {
        return DateFormat(pattern, 'en_US').parseStrict(text);
      } on Object {
        return null;
      }
    }
  }
}

DateTime? resolveVisibleTimestamp({
  required ParsedTimestamp? dateContext,
  required ParsedTimestamp? timestamp,
}) {
  if (timestamp == null) return null;
  if (timestamp.precision == TimestampPrecision.dateTime) {
    return timestamp.value;
  }
  if (timestamp.precision != TimestampPrecision.time ||
      dateContext?.year == null ||
      dateContext?.month == null ||
      dateContext?.day == null) {
    return null;
  }
  return DateTime(
    dateContext!.year!,
    dateContext.month!,
    dateContext.day!,
    timestamp.hour!,
    timestamp.minute!,
  );
}
