/// The app's handwritten date voice.
///
/// One place formats every date the user reads as handwriting, so a
/// keepsake stamp, the feed masthead, and an exported share card all
/// say the same thing in the same shape. Pure string work with no
/// Flutter import, so the non-widget share renderer can use it too.
library;

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// 'Fri 2 Oct · 18:40' — the maker's mark stamped on keepsake cards and
/// printed under a share card's caption.
String handDateTime(DateTime at) {
  final day = _weekdays[at.weekday - 1].substring(0, 3);
  final month = _months[at.month - 1].substring(0, 3);
  final hour = at.hour.toString().padLeft(2, '0');
  final minute = at.minute.toString().padLeft(2, '0');
  return '$day ${at.day} $month · $hour:$minute';
}

/// 'Friday, October 2' — the long form, for a page masthead where there
/// is room to spell it out.
String handDayLine(DateTime at) =>
    '${_weekdays[at.weekday - 1]}, ${_months[at.month - 1]} ${at.day}';
