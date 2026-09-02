import '../domain/calendar_date.dart';
import '../domain/event.dart';

/// Turns a Notion page from the events database into an [Event].
///
/// The property names are the ones authored in the Notion database and are
/// accent-sensitive — `Preço`, `Descrição`. Where the Expo app accepted a
/// Portuguese or English name for the description, that leniency is kept and
/// extended to the other fields, so renaming a column in Notion degrades one
/// field instead of emptying the whole card.
class NotionMapper {
  const NotionMapper();

  /// Reads one page. Returns null when the record has no usable date — an
  /// event without a day cannot be placed on the agenda.
  Event? mapPage(Map<String, dynamic> page) {
    final id = page['id'] as String?;
    if (id == null) return null;

    final properties = page['properties'];
    if (properties is! Map<String, dynamic>) return null;

    final parsedDate = parseNotionDate(
      _date(properties, const ['Data', 'Date', 'Quando']),
    );
    if (parsedDate == null) return null;

    return Event(
      id: id,
      name: _title(properties, const ['Nome', 'Name', 'Título', 'Titulo']) ??
          'Evento sem nome',
      day: parsedDate.day,
      time: parsedDate.time,
      price: _number(properties, const ['Preço', 'Preco', 'Price', 'Valor']),
      location: _select(properties, const ['Sede', 'Local', 'Location']) ??
          'Local não definido',
      status: EventStatus.fromNotion(
        _select(properties, const ['Status', 'Situação', 'Situacao']),
      ),
      description: _richText(
        properties,
        const ['Descrição', 'Descricao', 'Description'],
      ),
      tags: _multiSelect(properties, const ['Tags', 'Categorias']),
      organizer: _people(properties, const ['Organizador', 'Organizer']) ??
          'Organizador não definido',
      imageUrl: _file(properties, const ['Imagem', 'Capa', 'Image', 'Cover']),
      pageUrl: _url(
            properties,
            const ['Página do evento', 'Pagina do evento', 'URL', 'Link'],
          ) ??
          _nonEmpty(page['public_url']),
    );
  }

  /// Reads a whole `/databases/{id}/query` response body.
  List<Event> mapResults(Map<String, dynamic> body) {
    final results = body['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(mapPage)
        .whereType<Event>()
        .toList();
  }

  /// The cursor for the next page, or null when this was the last one.
  ///
  /// The Expo app ignored these two fields entirely, which capped the agenda at
  /// the 100 records one Notion response carries.
  static String? nextCursor(Map<String, dynamic> body) {
    if (body['has_more'] != true) return null;
    return body['next_cursor'] as String?;
  }

  // --- property readers -----------------------------------------------------
  //
  // Each reader walks the candidate names and returns the first that is present
  // and of the expected shape, so a property of an unexpected type yields null
  // instead of throwing mid-parse.

  Map<String, dynamic>? _property(
    Map<String, dynamic> properties,
    List<String> names,
    String expectedType,
  ) {
    for (final name in names) {
      final property = properties[name];
      if (property is! Map<String, dynamic>) continue;
      if (property['type'] == expectedType ||
          property.containsKey(expectedType)) {
        return property;
      }
    }
    return null;
  }

  String? _nonEmpty(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _title(Map<String, dynamic> properties, List<String> names) {
    final runs = _property(properties, names, 'title')?['title'];
    if (runs is! List || runs.isEmpty) return null;
    final text = runs
        .whereType<Map<String, dynamic>>()
        .map((run) => run['plain_text'] as String? ?? '')
        .join();
    return _nonEmpty(text);
  }

  String? _date(Map<String, dynamic> properties, List<String> names) {
    final date = _property(properties, names, 'date')?['date'];
    if (date is! Map<String, dynamic>) return null;
    return date['start'] as String?;
  }

  List<String> _multiSelect(
    Map<String, dynamic> properties,
    List<String> names,
  ) {
    final options =
        _property(properties, names, 'multi_select')?['multi_select'];
    if (options is! List) return const [];
    // Kept as a real list. The Expo app joined these into one string and split
    // it back on commas in the UI, which tore any tag containing a comma in two.
    return options
        .whereType<Map<String, dynamic>>()
        .map((option) => _nonEmpty(option['name']))
        .whereType<String>()
        .toList();
  }

  String? _select(Map<String, dynamic> properties, List<String> names) {
    final option = _property(properties, names, 'select')?['select'];
    if (option is! Map<String, dynamic>) return null;
    return _nonEmpty(option['name']);
  }

  String? _people(Map<String, dynamic> properties, List<String> names) {
    final people = _property(properties, names, 'people')?['people'];
    if (people is! List || people.isEmpty) return null;
    final named = people
        .whereType<Map<String, dynamic>>()
        .map((person) => _nonEmpty(person['name']))
        .whereType<String>()
        .toList();
    return named.isEmpty ? null : named.join(', ');
  }

  /// Reads a number property. Stays null when the field is empty, so an event
  /// with no price set is never announced as free.
  double? _number(Map<String, dynamic> properties, List<String> names) {
    final value = _property(properties, names, 'number')?['number'];
    return value is num ? value.toDouble() : null;
  }

  String? _url(Map<String, dynamic> properties, List<String> names) {
    return _nonEmpty(_property(properties, names, 'url')?['url']);
  }

  String? _file(Map<String, dynamic> properties, List<String> names) {
    final files = _property(properties, names, 'files')?['files'];
    if (files is! List) return null;
    for (final entry in files.whereType<Map<String, dynamic>>()) {
      // An external link is stable, so prefer it. A Notion-hosted file comes
      // back as a signed URL that expires in about an hour.
      final external = entry['external'];
      if (external is Map<String, dynamic>) {
        final url = _nonEmpty(external['url']);
        if (url != null) return url;
      }
      final hosted = entry['file'];
      if (hosted is Map<String, dynamic>) {
        final url = _nonEmpty(hosted['url']);
        if (url != null) return url;
      }
    }
    return null;
  }

  /// Reads a rich_text property into inline runs, each keeping its own
  /// formatting.
  ///
  /// Notion returns a paragraph as a list of runs. The Expo app rendered each
  /// run as its own block, so a single bold word broke the sentence onto a new
  /// line. Here they stay inline and compose into one paragraph.
  List<RichRun> _richText(
    Map<String, dynamic> properties,
    List<String> names,
  ) {
    final runs = _property(properties, names, 'rich_text')?['rich_text'];
    if (runs is! List) return const [];

    final mapped = <RichRun>[];
    for (final run in runs.whereType<Map<String, dynamic>>()) {
      final text = run['plain_text'] as String? ?? '';
      if (text.isEmpty) continue;

      final annotations = run['annotations'];
      final marks = annotations is Map<String, dynamic>
          ? annotations
          : const <String, dynamic>{};

      mapped.add(RichRun(
        text: text,
        bold: marks['bold'] == true,
        italic: marks['italic'] == true,
        strikethrough: marks['strikethrough'] == true,
        underline: marks['underline'] == true,
        code: marks['code'] == true,
        href: _nonEmpty(run['href']),
      ));
    }
    return mapped;
  }
}
