# O backend de eventos

O app não pode falar com o Notion diretamente em produção, por duas razões
independentes:

1. **O token vaza.** Qualquer credencial compilada no app pode ser extraída do
   APK. Foi assim que o token de integração da versão Expo acabou publicado —
   ele aparece literalmente no JavaScript do bundle. Um token do Notion dá
   acesso de **leitura e escrita** à base de eventos.
2. **Navegador não consegue.** A API do Notion não envia cabeçalhos de CORS, então
   o alvo web nunca carrega evento nenhum sem um intermediário.

Um backend mínimo resolve os dois. Ele guarda o token, faz a consulta paginada
e devolve um array pronto. O app já está construído para isso: basta subir o
endpoint e apontar `PROXY_BASE_URL` para ele.

```bash
flutter build apk --dart-define=EVENTS_BACKEND=proxy --dart-define=PROXY_BASE_URL=https://eventos.exemplo.workers.dev
```

## O contrato

### `GET {PROXY_BASE_URL}/events`

Responde `200` com:

```json
{
  "events": [
    {
      "id": "25385992-c728-8029-8c80-e801dbd64b7f",
      "name": "Liga Pokémon TCG — Etapa Regional",
      "date": "2025-09-10",
      "time": "19:30",
      "price": 35.5,
      "location": "TableTop Sorocaba",
      "status": "available",
      "organizer": "Eduardo Martins",
      "tags": ["Competitivo", "Pokémon"],
      "imageUrl": "https://cdn.exemplo.com/eventos/abc.png",
      "pageUrl": "https://tabletop.com.br/eventos/liga-pokemon",
      "description": [
        { "text": "Traga seu " },
        { "text": "deck de 60 cartas", "bold": true },
        { "text": " e a " },
        { "text": "decklist", "code": true },
        { "text": " preenchida." }
      ]
    }
  ]
}
```

### Campos

| Campo | Obrigatório | Formato |
| --- | --- | --- |
| `id` | **sim** | string não vazia, estável entre requisições |
| `date` | **sim** | `YYYY-MM-DD`, **sem fuso** — o dia como escrito no Notion |
| `name` | não | string; ausente vira "Evento sem nome" |
| `time` | não | `HH:mm` de parede; ausente = "Horário a confirmar" |
| `price` | não | número; **`null` significa "não definido"**, que não é grátis |
| `location` | não | string; ausente vira "Local não definido" |
| `status` | não | `available`, `sold_out`, `cancelled`, `postponed`, `unknown` |
| `organizer` | não | string; ausente vira "Organizador não definido" |
| `tags` | não | array de strings — **não** uma string com vírgulas |
| `imageUrl` | não | URL estável (ver abaixo) |
| `pageUrl` | não | URL da página do evento |
| `description` | não | array de runs, ou uma string simples |

Um registro sem `id` ou sem `date` válida é descartado em silêncio — um evento
sem dia não tem onde ser colocado na agenda.

### Duas armadilhas que só o backend pode resolver

**Datas sem fuso.** `date` tem que ser `YYYY-MM-DD` puro. Não mande
`2025-09-10T00:00:00Z`: um instante UTC lido no Brasil escorrega para o dia
anterior, e foi essa conversão que fez a versão Expo esconder os eventos de
hoje da tela da semana e mostrar a data errada na home. Se o `Data` do Notion
tem hora, separe: o dia em `date`, a hora de parede em `time`.

**Imagens.** Arquivos hospedados no Notion vêm como URLs assinadas que expiram
em cerca de uma hora. O app não pode cachear nem reusar isso. Copie o binário
para um storage estável (R2, S3, Firebase Storage) e devolva a URL de lá. Uma
propriedade `files` com link externo já é estável e pode passar direto.

### Runs de descrição

Cada run é `{ "text": "...", "bold": bool, "italic": bool, "underline": bool,
"strikethrough": bool, "code": bool, "href": "..." }` — só `text` é
obrigatório. Isso é o `rich_text` do Notion um-para-um, então o mapeamento é
direto. Uma string simples também é aceita, se o formatting não importar.

## Consultando o Notion

A base tem estas propriedades (nomes acentuados e sensíveis a acento):

| Notion | Tipo | Vira |
| --- | --- | --- |
| `Nome` | title | `name` |
| `Data` | date | `date` + `time` |
| `Tags` | multi_select | `tags` |
| `Organizador` | people | `organizer` |
| `Sede` | select | `location` |
| `Preço` | number | `price` |
| `Descrição` | rich_text | `description` |
| `Imagem` / `Capa` | files | `imageUrl` |
| `Página do evento` | url | `pageUrl` |
| `Status` | select | `status` |

**Pagine.** `POST /v1/databases/{id}/query` devolve no máximo 100 registros.
Siga `has_more` e `next_cursor` até o fim — sem isso a agenda fica calada a
partir do 101º evento, que é o comportamento que a versão Expo tinha.

```js
// Cloudflare Worker, esboço
export default {
  async fetch(request, env) {
    const events = [];
    let cursor;

    do {
      const response = await fetch(
        `https://api.notion.com/v1/databases/${env.NOTION_DATABASE_ID}/query`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${env.NOTION_TOKEN}`,
            'Notion-Version': '2022-06-28',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ page_size: 100, start_cursor: cursor }),
        },
      );
      const body = await response.json();
      events.push(...body.results.map(toEvent));
      cursor = body.has_more ? body.next_cursor : undefined;
    } while (cursor);

    return Response.json({ events }, {
      headers: {
        // O alvo web precisa disto; é o outro motivo do proxy existir.
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=300',
      },
    });
  },
};
```

O token vai como secret (`wrangler secret put NOTION_TOKEN`), nunca no
`wrangler.toml`.

**Cacheie.** Cinco minutos no servidor evita gastar a cota do Notion uma vez
por dispositivo. O app também cacheia cinco minutos localmente
(`AppConfig.cacheTtl`), então os dois juntos deixam a agenda barata.

## Verificando

Com o endpoint no ar:

```bash
curl -s https://eventos.exemplo.workers.dev/events | head -40
```

O formato do payload tem testes em
`test/fixture_data_source_test.dart`, no grupo `the proxy payload format` — a
agenda de exemplo do app usa exatamente esse formato, então ela funciona como
teste de contrato. Se o backend responde algo que aqueles testes aceitam, o
app lê.
