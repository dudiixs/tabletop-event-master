import 'calendar_date.dart';
import 'event_category.dart';

/// How an event is being offered.
///
/// The Expo app mapped only the literal "Esgotado" and let everything else fall
/// through to "available" — so a cancelled event was announced as having seats.
/// Every state the Notion `Status` select can hold is named here, and anything
/// unrecognised is [unknown] rather than optimistically available.
enum EventStatus {
  available,
  soldOut,
  cancelled,
  postponed,
  unknown;

  /// Maps a Notion `Status` select value, accented or not, cased any way.
  static EventStatus fromNotion(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return EventStatus.available;
    return switch (value) {
      'esgotado' || 'lotado' || 'sold out' => EventStatus.soldOut,
      'cancelado' || 'cancelada' || 'cancelled' => EventStatus.cancelled,
      'adiado' || 'adiada' || 'postponed' => EventStatus.postponed,
      'disponível' || 'disponivel' || 'aberto' || 'available' =>
        EventStatus.available,
      _ => EventStatus.unknown,
    };
  }

  /// Whether the event still accepts people.
  bool get isOpen => this == EventStatus.available;
}

/// One inline run of Notion rich text, carrying its own formatting.
///
/// Notion returns a paragraph as a list of runs, each with its own
/// annotations. The Expo app rendered every run as a separate block, which
/// broke sentences onto their own lines whenever a single word was bold. Here
/// the runs stay inline and are composed into one paragraph.
class RichRun {
  const RichRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.strikethrough = false,
    this.underline = false,
    this.code = false,
    this.href,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool strikethrough;
  final bool underline;
  final bool code;
  final String? href;

  bool get isLink => href != null && href!.isNotEmpty;
}

/// A single event on the agenda.
class Event {
  const Event({
    required this.id,
    required this.name,
    required this.day,
    this.time,
    this.price,
    required this.location,
    required this.status,
    required this.description,
    required this.tags,
    required this.organizer,
    this.imageUrl,
    this.pageUrl,
  });

  final String id;
  final String name;

  /// The event's calendar day, always local midnight. Never a UTC instant.
  final DateTime day;

  /// Wall-clock start time as authored in Notion, or null when the record
  /// carries only a date.
  final ({int hour, int minute})? time;

  /// Ticket price in BRL. `null` means the Notion field was left empty — which
  /// is *not* the same as free, the conflation the Expo app made.
  final double? price;

  final String location;
  final EventStatus status;

  /// The event's description as Notion authored it, formatting preserved.
  final List<RichRun> description;

  final List<String> tags;
  final String organizer;
  final String? imageUrl;
  final String? pageUrl;

  bool get isFree => price != null && price == 0;
  bool get hasPrice => price != null;
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasPage => pageUrl != null && pageUrl!.isNotEmpty;
  bool get hasDescription => description.isNotEmpty;

  /// The description flattened to plain text, for the two-line card preview.
  String get plainDescription => description.map((run) => run.text).join();

  /// The category inferred from the event's name and tags.
  EventCategory get category => EventCategory.detect(name: name, tags: tags);

  /// The start as a local instant, used for reminder scheduling. Falls back to
  /// [defaultHour] when the Notion record carries no time.
  DateTime startsAt({int defaultHour = 20}) => DateTime(
        day.year,
        day.month,
        day.day,
        time?.hour ?? defaultHour,
        time?.minute ?? 0,
      );

  bool occursOn(DateTime other) => isSameDay(day, other);

  Event copyWith({EventStatus? status}) => Event(
        id: id,
        name: name,
        day: day,
        time: time,
        price: price,
        location: location,
        status: status ?? this.status,
        description: description,
        tags: tags,
        organizer: organizer,
        imageUrl: imageUrl,
        pageUrl: pageUrl,
      );

  @override
  bool operator ==(Object other) => other is Event && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Event($id, $name, ${day.toIso8601String()})';
}
