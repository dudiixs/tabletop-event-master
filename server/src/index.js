import { diffAgenda, snapshotFrom } from './announcements.js';
import { sendToTopic } from './fcm.js';
import { fetchEvents } from './notion.js';

/**
 * O backend do TableTop Events.
 *
 * Faz as duas coisas que o app nao pode fazer sozinho:
 *
 * 1. `GET /events` — serve a agenda, guardando o token do Notion e mandando o
 *    CORS que o alvo web precisa. E o contrato descrito no `PROXY.md`.
 * 2. Cron — compara a agenda com a da ultima execucao e manda push do que
 *    mudou. Push existe para o que o telefone nao tem como saber; "comeca em 5
 *    minutos" continua sendo lembrete local no aparelho.
 */

const SNAPSHOT_KEY = 'agenda:snapshot';

/** Cache de 5 minutos, igual ao `AppConfig.cacheTtl` do app. */
const CACHE_SECONDS = 300;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};

/**
 * O dia de hoje em Sao Paulo, como `YYYY-MM-DD`.
 *
 * O Worker roda em UTC. Depois das 21h de Sorocaba o UTC ja virou o dia
 * seguinte, e usar a data do servidor descartaria como "passado" um evento que
 * ainda vai acontecer hoje a noite — exatamente o evento que mais importa.
 */
function todayInSaoPaulo(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

async function handleEvents(env) {
  const events = await fetchEvents(env);
  return Response.json(
    { events },
    {
      headers: {
        ...CORS,
        'Cache-Control': `public, max-age=${CACHE_SECONDS}`,
      },
    },
  );
}

/**
 * Busca a agenda, anuncia o que mudou e guarda o estado novo.
 *
 * O snapshot so e gravado depois dos envios. Se o FCM cair no meio, a proxima
 * execucao ve a mesma diferenca e tenta de novo, em vez de dar a novidade como
 * anunciada e ninguem nunca receber.
 */
export async function announceChanges(env, now = new Date()) {
  const events = await fetchEvents(env);
  const stored = await env.AGENDA.get(SNAPSHOT_KEY, 'json');

  const announcements = diffAgenda(stored, events, todayInSaoPaulo(now));

  const failures = [];
  for (const announcement of announcements) {
    try {
      await sendToTopic(env, announcement.topic, {
        title: announcement.title,
        body: announcement.body,
        data: {
          type: announcement.type,
          eventId: announcement.eventId,
          category: announcement.category,
        },
      });
    } catch (error) {
      // Um topico que falhou nao pode impedir os outros de serem avisados.
      failures.push(`${announcement.topic}: ${error.message}`);
    }
  }

  if (failures.length === 0) {
    await env.AGENDA.put(SNAPSHOT_KEY, JSON.stringify(snapshotFrom(events)));
  } else {
    console.error(`Push falhou em ${failures.length} topico(s):`, failures);
  }

  return { seeded: stored === null, sent: announcements.length, failures };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }

    if (url.pathname === '/events' && request.method === 'GET') {
      try {
        return await handleEvents(env);
      } catch (error) {
        console.error(error);
        return Response.json(
          { error: 'Não foi possível ler a agenda.' },
          { status: 502, headers: CORS },
        );
      }
    }

    // Util para conferir o deploy sem esperar o cron. Protegido por um segredo
    // porque disparar push e uma acao visivel no telefone de todo mundo, e um
    // endpoint aberto para isso seria um megafone publico.
    if (url.pathname === '/announce' && request.method === 'POST') {
      const provided = request.headers.get('x-admin-token');
      if (!env.ADMIN_TOKEN || provided !== env.ADMIN_TOKEN) {
        return new Response('Não autorizado', { status: 401, headers: CORS });
      }
      try {
        return Response.json(await announceChanges(env), { headers: CORS });
      } catch (error) {
        console.error(error);
        return Response.json({ error: error.message }, { status: 500, headers: CORS });
      }
    }

    return new Response('Não encontrado', { status: 404, headers: CORS });
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(
      announceChanges(env, new Date(event.scheduledTime)).catch((error) => {
        console.error('Cron falhou:', error);
      }),
    );
  },
};
