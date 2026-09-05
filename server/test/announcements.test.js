import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { diffAgenda, snapshotFrom } from '../src/announcements.js';
import { detectCategory, fold, topicFor } from '../src/categories.js';

const event = (overrides = {}) => ({
  id: 'evt-1',
  name: 'Liga Pokémon',
  date: '2026-09-20',
  time: '19:30',
  location: 'TableTop Sorocaba',
  status: 'available',
  tags: [],
  ...overrides,
});

const TODAY = '2026-09-04';

describe('classificação por jogo', () => {
  // Isto tem que continuar batendo com EventCategory.detect no Dart. Se
  // divergir, o servidor publica num tópico que o app não assinou e o push
  // some sem erro em lugar nenhum.
  it('acha o jogo pelo nome', () => {
    assert.equal(detectCategory('Liga de Magic', []).name, 'magic');
    assert.equal(detectCategory('Torneio de MTG', []).name, 'magic');
  });

  it('ignora acento, como o app', () => {
    assert.equal(fold('Pokémon'), 'pokemon');
    assert.equal(detectCategory('Liga Pokémon', []).name, 'pokemon');
    assert.equal(detectCategory('liga pokemon', []).name, 'pokemon');
  });

  it('o jogo ganha do formato', () => {
    // Mesma precedência do Dart: quem segue Pokémon quer este evento; quem
    // segue "Torneio" genérico não deveria recebê-lo no lugar.
    assert.equal(detectCategory('Torneio de Pokémon', []).name, 'pokemon');
  });

  it('acha o jogo pelas tags também', () => {
    assert.equal(detectCategory('Encontro de sexta', ['RPG']).name, 'rpg');
  });

  it('o que não casa vira evento especial', () => {
    assert.equal(detectCategory('Noite de autógrafos', []).name, 'other');
  });

  it('o tópico é prefixado', () => {
    assert.equal(topicFor(detectCategory('Liga Pokémon', [])), 'game_pokemon');
  });
});

describe('o que merece um push', () => {
  it('a primeira execução não anuncia nada', () => {
    // Sem isto, o primeiro deploy trataria a base inteira como novidade e
    // mandaria um push por evento para todo mundo de uma vez.
    assert.deepEqual(diffAgenda(null, [event()], TODAY), []);
  });

  it('anuncia um evento que não existia', () => {
    const [announcement] = diffAgenda({}, [event()], TODAY);

    assert.equal(announcement.type, 'new_event');
    assert.equal(announcement.topic, 'game_pokemon');
    assert.equal(announcement.eventId, 'evt-1');
    assert.match(announcement.body, /20\/09\/2026 às 19:30/);
  });

  it('não anuncia nada quando nada mudou', () => {
    const events = [event()];
    assert.deepEqual(diffAgenda(snapshotFrom(events), events, TODAY), []);
  });

  it('anuncia um cancelamento', () => {
    const before = snapshotFrom([event()]);
    const [announcement] = diffAgenda(
      before,
      [event({ status: 'cancelled' })],
      TODAY,
    );

    assert.equal(announcement.type, 'event_cancelled');
    assert.equal(announcement.title, 'Evento cancelado');
  });

  it('não repete o cancelamento a cada execução', () => {
    // O cron roda a cada 15 minutos. Sem esta guarda, um evento cancelado
    // avisaria a mesma pessoa 96 vezes por dia até sair da base.
    const cancelled = [event({ status: 'cancelled' })];
    assert.deepEqual(diffAgenda(snapshotFrom(cancelled), cancelled, TODAY), []);
  });

  it('anuncia quando a data muda', () => {
    const before = snapshotFrom([event()]);
    const [announcement] = diffAgenda(
      before,
      [event({ date: '2026-09-27' })],
      TODAY,
    );

    assert.equal(announcement.type, 'event_updated');
    assert.equal(announcement.title, 'Evento remarcado');
  });

  it('anuncia quando só a hora muda', () => {
    const before = snapshotFrom([event()]);
    const [announcement] = diffAgenda(before, [event({ time: '14:00' })], TODAY);

    assert.equal(announcement.title, 'Evento remarcado');
    assert.match(announcement.body, /14:00/);
  });

  it('anuncia mudança de local com o texto certo', () => {
    const before = snapshotFrom([event()]);
    const [announcement] = diffAgenda(
      before,
      [event({ location: 'TableTop Campinas' })],
      TODAY,
    );

    assert.equal(announcement.title, 'Evento mudou de local');
    assert.match(announcement.body, /TableTop Campinas/);
  });

  it('cala sobre o que já passou', () => {
    const before = snapshotFrom([event({ date: '2026-08-01' })]);
    const changed = [event({ date: '2026-08-02' })];

    // Remarcar um evento da semana passada não é notícia para ninguém.
    assert.deepEqual(diffAgenda(before, changed, TODAY), []);
  });

  it('um evento hoje ainda conta como futuro', () => {
    // O limite é >= hoje, não > hoje: o evento desta noite é justamente o que
    // mais importa avisar.
    const announcements = diffAgenda({}, [event({ date: TODAY })], TODAY);
    assert.equal(announcements.length, 1);
  });

  it('cada evento vai para o tópico do seu jogo', () => {
    const announcements = diffAgenda(
      {},
      [
        event({ id: 'a', name: 'Liga Pokémon' }),
        event({ id: 'b', name: 'Draft de Magic' }),
      ],
      TODAY,
    );

    assert.deepEqual(
      announcements.map((a) => a.topic),
      ['game_pokemon', 'game_magic'],
    );
  });
});
