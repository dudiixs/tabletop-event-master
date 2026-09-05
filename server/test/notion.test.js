import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { toEvent } from '../src/notion.js';

const page = (properties) => ({ id: 'pagina-1', properties });

const withDate = (start, extra = {}) =>
  page({
    Nome: { title: [{ plain_text: 'Liga Pokémon' }] },
    Data: { date: { start } },
    ...extra,
  });

describe('lendo um registro do Notion', () => {
  it('separa o dia da hora sem passar por Date', () => {
    // A armadilha que a versão Expo caiu: ler como instante e reimprimir
    // escorrega de dia quando o fuso do servidor não é o de quem escreveu.
    const event = toEvent(withDate('2026-09-10T19:30:00.000-03:00'));

    assert.equal(event.date, '2026-09-10');
    assert.equal(event.time, '19:30');
  });

  it('aceita data sem hora', () => {
    const event = toEvent(withDate('2026-09-10'));

    assert.equal(event.date, '2026-09-10');
    assert.equal(event.time, undefined);
  });

  it('descarta um registro sem data utilizável', () => {
    // Um evento sem dia não tem onde ser colocado na agenda.
    assert.equal(toEvent(withDate(undefined)), null);
    assert.equal(toEvent(withDate('setembro')), null);
  });

  it('preço ausente é null, não zero', () => {
    // O app mostra "Gratuito" para zero e "a confirmar" para null. Mandar 0
    // aqui anunciaria como grátis um evento cujo preço ninguém definiu.
    const semPreco = toEvent(withDate('2026-09-10'));
    assert.equal(semPreco.price, null);

    const gratis = toEvent(withDate('2026-09-10', { Preço: { number: 0 } }));
    assert.equal(gratis.price, 0);
  });

  it('tags viram um array, não uma string com vírgulas', () => {
    const event = toEvent(
      withDate('2026-09-10', {
        Tags: { multi_select: [{ name: 'Competitivo' }, { name: 'Pokémon' }] },
      }),
    );

    assert.deepEqual(event.tags, ['Competitivo', 'Pokémon']);
  });

  it('traduz os rótulos de status do Notion', () => {
    const cancelado = toEvent(
      withDate('2026-09-10', { Status: { select: { name: 'Cancelado' } } }),
    );
    assert.equal(cancelado.status, 'cancelled');

    const esgotado = toEvent(
      withDate('2026-09-10', { Status: { select: { name: 'esgotado' } } }),
    );
    assert.equal(esgotado.status, 'sold_out');
  });

  it('sem status é disponível', () => {
    assert.equal(toEvent(withDate('2026-09-10')).status, 'available');
  });

  it('um status desconhecido não vira disponível por engano', () => {
    // O app pede confirmação nesse caso em vez de afirmar que tem vaga.
    const event = toEvent(
      withDate('2026-09-10', { Status: { select: { name: 'Pré-inscrição' } } }),
    );
    assert.equal(event.status, 'unknown');
  });

  it('preserva a formatação da descrição', () => {
    const event = toEvent(
      withDate('2026-09-10', {
        Descrição: {
          rich_text: [
            { plain_text: 'Traga seu ', annotations: {} },
            { plain_text: 'deck', annotations: { bold: true } },
          ],
        },
      }),
    );

    assert.deepEqual(event.description, [
      { text: 'Traga seu ' },
      { text: 'deck', bold: true },
    ]);
  });

  it('aceita o nome da propriedade sem acento', () => {
    const event = toEvent(
      page({
        Nome: { title: [{ plain_text: 'Liga' }] },
        Data: { date: { start: '2026-09-10' } },
        Descricao: { rich_text: [{ plain_text: 'oi', annotations: {} }] },
        Preco: { number: 35.5 },
      }),
    );

    assert.equal(event.price, 35.5);
    assert.deepEqual(event.description, [{ text: 'oi' }]);
  });

  it('prefere o link externo à URL assinada do Notion', () => {
    // A URL assinada expira em cerca de uma hora e o app cacheia imagem.
    const event = toEvent(
      withDate('2026-09-10', {
        Imagem: {
          files: [
            {
              external: { url: 'https://cdn.exemplo.com/capa.png' },
              file: { url: 'https://notion.so/assinada?expira=1h' },
            },
          ],
        },
      }),
    );

    assert.equal(event.imageUrl, 'https://cdn.exemplo.com/capa.png');
  });
});
