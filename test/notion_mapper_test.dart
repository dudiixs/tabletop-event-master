import 'package:flutter_test/flutter_test.dart';
import 'package:tabletop_events/data/notion_mapper.dart';
import 'package:tabletop_events/domain/event.dart';
import 'package:tabletop_events/domain/event_category.dart';

/// A page shaped the way the real events database returns one.
Map<String, dynamic> page({
  String id = 'page-1',
  Map<String, dynamic>? properties,
  String? publicUrl,
}) =>
    {
      'id': id,
      'public_url': ?publicUrl,
      'properties': properties ?? fullProperties(),
    };

Map<String, dynamic> fullProperties() => {
      'Nome': {
        'type': 'title',
        'title': [
          {'plain_text': 'Torneio de Pokémon TCG'}
        ],
      },
      'Data': {
        'type': 'date',
        'date': {'start': '2025-09-10T19:30:00.000-03:00', 'end': null},
      },
      'Tags': {
        'type': 'multi_select',
        'multi_select': [
          {'name': 'Competitivo'},
          {'name': 'Pokémon'},
        ],
      },
      'Organizador': {
        'type': 'people',
        'people': [
          {'name': 'Eduardo Martins'}
        ],
      },
      'Sede': {
        'type': 'select',
        'select': {'name': 'TableTop Sorocaba'},
      },
      'Preço': {'type': 'number', 'number': 35.5},
      'Descrição': {
        'type': 'rich_text',
        'rich_text': [
          {
            'plain_text': 'Traga seu ',
            'annotations': {'bold': false, 'italic': false},
          },
          {
            'plain_text': 'deck',
            'annotations': {'bold': true, 'code': true},
          },
          {
            'plain_text': ' completo.',
            'annotations': {'italic': true, 'strikethrough': false},
          },
        ],
      },
      'Imagem': {
        'type': 'files',
        'files': [
          {
            'file': {'url': 'https://notion.so/signed/capa.png'}
          }
        ],
      },
      'Página do evento': {
        'type': 'url',
        'url': 'https://tabletop.com.br/eventos/1',
      },
      'Status': {
        'type': 'select',
        'select': {'name': 'Disponível'},
      },
    };

void main() {
  const mapper = NotionMapper();

  group('mapPage', () {
    test('reads every property of a complete record', () {
      final event = mapper.mapPage(page())!;

      expect(event.id, 'page-1');
      expect(event.name, 'Torneio de Pokémon TCG');
      expect(event.day, DateTime(2025, 9, 10));
      expect(event.time, (hour: 19, minute: 30));
      expect(event.price, 35.5);
      expect(event.location, 'TableTop Sorocaba');
      expect(event.status, EventStatus.available);
      expect(event.tags, ['Competitivo', 'Pokémon']);
      expect(event.organizer, 'Eduardo Martins');
      expect(event.imageUrl, 'https://notion.so/signed/capa.png');
      expect(event.pageUrl, 'https://tabletop.com.br/eventos/1');
    });

    test('keeps rich text as inline runs with their own marks', () {
      final event = mapper.mapPage(page())!;

      expect(event.description, hasLength(3));
      expect(event.description[0].text, 'Traga seu ');
      expect(event.description[0].bold, isFalse);
      expect(event.description[1].text, 'deck');
      expect(event.description[1].bold, isTrue);
      expect(event.description[1].code, isTrue);
      expect(event.description[2].italic, isTrue);
      // Flattening the runs must reconstruct the sentence exactly, which is
      // what the two-line card preview shows.
      expect(event.plainDescription, 'Traga seu deck completo.');
    });

    test('drops a record with no date', () {
      final properties = fullProperties()..remove('Data');

      expect(mapper.mapPage(page(properties: properties)), isNull);
    });

    test('drops a record whose date is unparseable', () {
      final properties = fullProperties()
        ..['Data'] = {
          'type': 'date',
          'date': {'start': 'em breve'},
        };

      expect(mapper.mapPage(page(properties: properties)), isNull);
    });

    test('leaves the price null when the Notion field is empty', () {
      final properties = fullProperties()
        ..['Preço'] = {'type': 'number', 'number': null};

      final event = mapper.mapPage(page(properties: properties))!;

      // Empty is not free. The Expo app coerced this to 0 and labelled the
      // event "Gratuito".
      expect(event.price, isNull);
      expect(event.hasPrice, isFalse);
      expect(event.isFree, isFalse);
    });

    test('reads an actual zero price as free', () {
      final properties = fullProperties()
        ..['Preço'] = {'type': 'number', 'number': 0};

      final event = mapper.mapPage(page(properties: properties))!;

      expect(event.isFree, isTrue);
    });

    test('falls back on each missing property instead of failing', () {
      final event = mapper.mapPage(page(properties: {
        'Data': {
          'type': 'date',
          'date': {'start': '2025-09-10'},
        },
      }))!;

      expect(event.name, 'Evento sem nome');
      expect(event.location, 'Local não definido');
      expect(event.organizer, 'Organizador não definido');
      expect(event.tags, isEmpty);
      expect(event.description, isEmpty);
      expect(event.imageUrl, isNull);
      expect(event.time, isNull);
      expect(event.status, EventStatus.available);
    });

    test('accepts the English property names too', () {
      final event = mapper.mapPage(page(properties: {
        'Name': {
          'type': 'title',
          'title': [
            {'plain_text': 'Magic Draft Night'}
          ],
        },
        'Date': {
          'type': 'date',
          'date': {'start': '2025-09-12'},
        },
        'Location': {
          'type': 'select',
          'select': {'name': 'Downtown'},
        },
        'Price': {'type': 'number', 'number': 20},
      }))!;

      expect(event.name, 'Magic Draft Night');
      expect(event.location, 'Downtown');
      expect(event.price, 20);
    });

    test('survives a property of the wrong type', () {
      final properties = fullProperties()
        ..['Preço'] = {'type': 'rich_text', 'rich_text': []}
        ..['Sede'] = 'texto solto';

      final event = mapper.mapPage(page(properties: properties))!;

      expect(event.price, isNull);
      expect(event.location, 'Local não definido');
      expect(event.name, 'Torneio de Pokémon TCG');
    });

    test('prefers an external image URL over an expiring hosted one', () {
      final properties = fullProperties()
        ..['Imagem'] = {
          'type': 'files',
          'files': [
            {
              'external': {'url': 'https://cdn.tabletop.com.br/capa.png'}
            },
          ],
        };

      final event = mapper.mapPage(page(properties: properties))!;

      expect(event.imageUrl, 'https://cdn.tabletop.com.br/capa.png');
    });

    test('falls back to the page public_url when there is no link property', () {
      final properties = fullProperties()..remove('Página do evento');

      final event = mapper.mapPage(
        page(properties: properties, publicUrl: 'https://notion.so/publica'),
      )!;

      expect(event.pageUrl, 'https://notion.so/publica');
    });

    test('joins co-organizers', () {
      final properties = fullProperties()
        ..['Organizador'] = {
          'type': 'people',
          'people': [
            {'name': 'Ana'},
            {'name': 'Bruno'},
          ],
        };

      expect(mapper.mapPage(page(properties: properties))!.organizer,
          'Ana, Bruno');
    });
  });

  group('status mapping', () {
    test('recognises every state the database uses', () {
      expect(EventStatus.fromNotion('Esgotado'), EventStatus.soldOut);
      expect(EventStatus.fromNotion('esgotado'), EventStatus.soldOut);
      expect(EventStatus.fromNotion('Cancelado'), EventStatus.cancelled);
      expect(EventStatus.fromNotion('Adiado'), EventStatus.postponed);
      expect(EventStatus.fromNotion('Disponível'), EventStatus.available);
      expect(EventStatus.fromNotion(null), EventStatus.available);
    });

    test('does not call an unrecognised state available', () {
      // The Expo mapping let anything that was not "Esgotado" fall through to
      // available, so a cancelled event advertised open seats.
      expect(EventStatus.fromNotion('Rascunho'), EventStatus.unknown);
      expect(EventStatus.fromNotion('Rascunho').isOpen, isFalse);
      expect(EventStatus.cancelled.isOpen, isFalse);
      expect(EventStatus.available.isOpen, isTrue);
    });
  });

  group('category detection', () {
    test('matches through accents and casing', () {
      expect(
        EventCategory.detect(name: 'Liga de Pokémon', tags: const []),
        EventCategory.pokemon,
      );
      expect(
        EventCategory.detect(name: 'liga de pokemon', tags: const []),
        EventCategory.pokemon,
      );
    });

    test('matches on tags when the name says nothing', () {
      expect(
        EventCategory.detect(name: 'Quinta à noite', tags: const ['RPG']),
        EventCategory.rpg,
      );
    });

    test('prefers the specific game over the format', () {
      expect(
        EventCategory.detect(name: 'Torneio de Magic', tags: const []),
        EventCategory.magic,
      );
    });

    test('falls back to the generic category', () {
      final category =
          EventCategory.detect(name: 'Encontro da comunidade', tags: const []);

      expect(category, EventCategory.other);
      expect(category.emoji, '🎮');
    });
  });

  group('mapResults', () {
    test('maps a response body and skips the unusable records', () {
      final events = mapper.mapResults({
        'results': [
          page(id: 'a'),
          page(id: 'b', properties: fullProperties()..remove('Data')),
          page(id: 'c'),
          'lixo',
        ],
      });

      expect(events.map((e) => e.id), ['a', 'c']);
    });

    test('returns empty for a malformed body', () {
      expect(mapper.mapResults(const {}), isEmpty);
      expect(mapper.mapResults(const {'results': 'nada'}), isEmpty);
    });
  });

  group('nextCursor', () {
    test('returns the cursor while there are more pages', () {
      expect(
        NotionMapper.nextCursor(const {'has_more': true, 'next_cursor': 'c1'}),
        'c1',
      );
    });

    test('returns null on the last page', () {
      expect(
        NotionMapper.nextCursor(const {'has_more': false, 'next_cursor': 'c1'}),
        isNull,
      );
      expect(NotionMapper.nextCursor(const {}), isNull);
    });
  });
}
