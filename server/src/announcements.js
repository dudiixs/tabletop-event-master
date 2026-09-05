import { detectCategory, topicFor } from './categories.js';

/**
 * O que vale acordar o telefone de alguem.
 *
 * Funcao pura de proposito: (agenda anterior, agenda atual) -> avisos. Toda a
 * regra de "isto merece um push" fica testavel sem Notion, sem FCM e sem
 * relogio de verdade. O `index.js` so cuida de buscar, guardar e enviar.
 */

/** Os campos cuja mudanca alguem precisa saber. */
function snapshotOf(event) {
  return {
    name: event.name ?? '',
    date: event.date,
    time: event.time ?? '',
    location: event.location ?? '',
    status: event.status ?? 'available',
  };
}

export function snapshotFrom(events) {
  return Object.fromEntries(events.map((event) => [event.id, snapshotOf(event)]));
}

function formatDate(date) {
  const [year, month, day] = date.split('-');
  return `${day}/${month}/${year}`;
}

function whenText(event) {
  const date = formatDate(event.date);
  return event.time ? `${date} às ${event.time}` : date;
}

/**
 * Compara duas agendas e diz o que anunciar.
 *
 * [previous] null significa primeira execucao: devolve nada. Sem isso o
 * primeiro deploy trataria a base inteira como novidade e mandaria um push por
 * evento existente para todo mundo de uma vez, que e como se ensina uma pessoa
 * a desligar as notificacoes do app no mesmo minuto em que ela o instalou.
 *
 * [today] entra como parametro, e nao como `new Date()`, para o teste poder
 * fixar o dia — e porque o Worker roda em UTC enquanto a agenda e de Sorocaba.
 */
export function diffAgenda(previous, events, today) {
  if (previous === null || previous === undefined) return [];

  const announcements = [];

  for (const event of events) {
    // Ninguem precisa saber de mudanca em evento que ja aconteceu.
    if (event.date < today) continue;

    const before = previous[event.id];
    const now = snapshotOf(event);
    const category = detectCategory(event.name, event.tags);
    const base = {
      topic: topicFor(category),
      eventId: event.id,
      category: category.name,
    };

    if (!before) {
      announcements.push({
        ...base,
        type: 'new_event',
        title: `Novo evento de ${category.label}`,
        body: `${event.name ?? 'Evento sem nome'} — ${whenText(event)}`,
      });
      continue;
    }

    if (now.status === 'cancelled' && before.status !== 'cancelled') {
      announcements.push({
        ...base,
        type: 'event_cancelled',
        title: 'Evento cancelado',
        body: `${event.name ?? 'Evento sem nome'} — ${whenText(event)}`,
      });
      continue;
    }

    // Um evento cancelado que continua cancelado nao rende aviso a cada hora.
    if (now.status === 'cancelled') continue;

    const moved = now.date !== before.date || now.time !== before.time;
    const relocated = now.location !== before.location;

    if (moved || relocated) {
      announcements.push({
        ...base,
        type: 'event_updated',
        title: moved ? 'Evento remarcado' : 'Evento mudou de local',
        body: moved
          ? `${event.name ?? 'Evento sem nome'} agora é ${whenText(event)}`
          : `${event.name ?? 'Evento sem nome'} agora é em ${now.location}`,
      });
    }
  }

  return announcements;
}
