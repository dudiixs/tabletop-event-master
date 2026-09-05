/**
 * Le a base do Notion e devolve eventos no formato que o `PROXY.md` descreve.
 *
 * O token do Notion fica aqui e nunca no app: ele da acesso de leitura **e
 * escrita** a base, e qualquer credencial compilada no APK pode ser extraida
 * dele — foi assim que o token da versao Expo acabou publicado.
 */

const NOTION_VERSION = '2022-06-28';

/** Nomes de propriedade, com e sem acento, na ordem em que sao tentados. */
const PROPS = {
  name: ['Nome', 'Name', 'Título', 'Titulo'],
  date: ['Data', 'Date'],
  tags: ['Tags', 'Etiquetas'],
  organizer: ['Organizador', 'Organizer'],
  location: ['Sede', 'Local', 'Location'],
  price: ['Preço', 'Preco', 'Price'],
  description: ['Descrição', 'Descricao', 'Description'],
  image: ['Imagem', 'Capa', 'Image'],
  pageUrl: ['Página do evento', 'Pagina do evento', 'Page'],
  status: ['Status', 'Situação', 'Situacao'],
};

function pick(properties, names) {
  for (const name of names) {
    if (properties[name] !== undefined) return properties[name];
  }
  return undefined;
}

function plainText(richText) {
  if (!Array.isArray(richText)) return '';
  return richText.map((run) => run.plain_text ?? '').join('').trim();
}

/** Converte `rich_text` do Notion nos runs que o app renderiza. */
function descriptionRuns(richText) {
  if (!Array.isArray(richText) || richText.length === 0) return undefined;
  return richText.map((run) => {
    const annotations = run.annotations ?? {};
    const entry = { text: run.plain_text ?? '' };
    if (annotations.bold) entry.bold = true;
    if (annotations.italic) entry.italic = true;
    if (annotations.underline) entry.underline = true;
    if (annotations.strikethrough) entry.strikethrough = true;
    if (annotations.code) entry.code = true;
    if (run.href) entry.href = run.href;
    return entry;
  });
}

/**
 * Separa o dia da hora **sem passar por Date**.
 *
 * `2025-09-10T19:30:00-03:00` lido como instante e reimpresso escorrega de dia
 * quando o fuso do servidor nao e o de quem escreveu. A versao Expo fazia
 * exatamente isso e escondia os eventos de hoje da tela da semana. O Notion ja
 * entrega a string certa; o trabalho e so corta-la.
 */
function splitDate(start) {
  if (typeof start !== 'string' || start.length < 10) return null;
  const date = start.slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return null;

  const time = start.length >= 16 && start[10] === 'T' ? start.slice(11, 16) : undefined;
  return { date, time: /^\d{2}:\d{2}$/.test(time ?? '') ? time : undefined };
}

function fileUrl(property) {
  const files = property?.files;
  if (!Array.isArray(files) || files.length === 0) return undefined;
  const file = files[0];
  // Um link externo e estavel. Um arquivo hospedado no Notion vem como URL
  // assinada que expira em cerca de uma hora — o app cacheia imagem, entao
  // isso vira um quadrado quebrado. Copiar o binario para um storage estavel
  // (R2/S3) e a correcao; ate la o link ao menos funciona no primeiro acesso.
  return file.external?.url ?? file.file?.url ?? undefined;
}

const STATUS_BY_LABEL = {
  esgotado: 'sold_out',
  lotado: 'sold_out',
  'sold out': 'sold_out',
  cancelado: 'cancelled',
  cancelada: 'cancelled',
  cancelled: 'cancelled',
  adiado: 'postponed',
  adiada: 'postponed',
  postponed: 'postponed',
  disponível: 'available',
  disponivel: 'available',
  aberto: 'available',
  available: 'available',
};

function statusOf(property) {
  const label = property?.select?.name ?? property?.status?.name;
  if (!label) return 'available';
  return STATUS_BY_LABEL[label.trim().toLowerCase()] ?? 'unknown';
}

/** Um registro do Notion no formato do contrato. Devolve null se inutilizavel. */
export function toEvent(page) {
  const properties = page.properties ?? {};

  const dateProperty = pick(properties, PROPS.date)?.date;
  const parsed = splitDate(dateProperty?.start);
  // Sem id ou sem dia valido nao ha onde por o evento na agenda.
  if (!page.id || !parsed) return null;

  const priceProperty = pick(properties, PROPS.price);
  const price = typeof priceProperty?.number === 'number' ? priceProperty.number : null;

  const organizer = (pick(properties, PROPS.organizer)?.people ?? [])
    .map((person) => person.name)
    .filter(Boolean)
    .join(', ');

  const event = {
    id: page.id,
    date: parsed.date,
    name: plainText(pick(properties, PROPS.name)?.title) || undefined,
    time: parsed.time,
    // null e "nao definido", que nao e o mesmo que gratuito — o app distingue
    // os dois na tela, entao mandar 0 aqui mentiria.
    price,
    location: pick(properties, PROPS.location)?.select?.name ?? undefined,
    status: statusOf(pick(properties, PROPS.status)),
    organizer: organizer || undefined,
    tags: (pick(properties, PROPS.tags)?.multi_select ?? [])
      .map((tag) => tag.name)
      .filter(Boolean),
    imageUrl: fileUrl(pick(properties, PROPS.image)),
    pageUrl: pick(properties, PROPS.pageUrl)?.url ?? undefined,
    description: descriptionRuns(pick(properties, PROPS.description)?.rich_text),
  };

  for (const key of Object.keys(event)) {
    if (event[key] === undefined) delete event[key];
  }
  return event;
}

/**
 * Toda a base, paginada ate o fim.
 *
 * `POST /v1/databases/{id}/query` devolve no maximo 100 registros. Sem seguir
 * `has_more` a agenda fica calada a partir do 101o evento, que e o que a
 * versao Expo fazia.
 */
export async function fetchEvents(env) {
  const token = env.NOTION_TOKEN;
  const databaseId = env.NOTION_DATABASE_ID;
  if (!token || !databaseId) {
    throw new Error('Faltam NOTION_TOKEN e NOTION_DATABASE_ID.');
  }

  const events = [];
  let cursor;

  do {
    const response = await fetch(
      `https://api.notion.com/v1/databases/${databaseId}/query`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Notion-Version': NOTION_VERSION,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ page_size: 100, start_cursor: cursor }),
      },
    );

    if (!response.ok) {
      throw new Error(`Notion respondeu ${response.status}: ${await response.text()}`);
    }

    const body = await response.json();
    for (const page of body.results ?? []) {
      const event = toEvent(page);
      if (event) events.push(event);
    }
    cursor = body.has_more ? body.next_cursor : undefined;
  } while (cursor);

  return events;
}
