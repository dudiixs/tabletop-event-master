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

> **Já existe uma implementação deste contrato em `server/`** — um Cloudflare
> Worker que serve `/events` e, no mesmo lugar, dispara o push descrito no fim
> deste documento. As instruções de deploy estão em `server/README.md`. O que
> segue é o contrato, para quem for reimplementar em outro lugar.

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


# O push

Separado do endpoint acima porque a decisão é diferente. Lembrete de "começa em
1 hora, 30 e 5 minutos" é **local**: o telefone já sabe a hora do evento, então
o aviso dispara offline, no minuto certo, sem depender da latência de entrega
do FCM. Push é para o que o telefone **não tem como saber** — um evento novo na
agenda, um cancelamento, uma data que mudou.

## Alvo: tópico, não dispositivo

O app assina um tópico FCM por jogo que a pessoa segue: `game_pokemon`,
`game_magic`, `game_rpg`, e assim por diante — `game_` mais o nome do valor em
`EventCategory`. Quem escolheu só Pokémon nunca é acordado por um evento de
Magic.

Isso significa que **o servidor não precisa registrar dispositivo nenhum**: não
há tabela de tokens, nada para sincronizar quando alguém troca de telefone, e
nada de dado pessoal guardado. O preço é que não dá para falar com uma pessoa
específica; se algum dia for preciso, aí sim entra o token do aparelho, que o
app já sabe ler (`PushGateway.token()`).

A lista de categorias vive em `lib/domain/event_category.dart` e está espelhada
em `server/src/categories.js`. **As duas têm que concordar.** Se o servidor
classificar um evento como `tournament` e o app como `pokemon`, o push vai para
um tópico que ninguém assinou e não chega — sem erro em lugar nenhum.

## O formato da mensagem

Mande `notification` **e** `data`. O bloco `notification` é o que o sistema
desenha sozinho com o app fechado — sem ele, no iOS a mensagem nem acorda o
aparelho. O `data` é o que o app lê para decidir o que fazer no toque, e é a
única parte que sobrevive intacta a todos os modos de entrega.

```json
{
  "message": {
    "topic": "game_pokemon",
    "notification": {
      "title": "Novo evento de Pokémon TCG",
      "body": "Liga Pokémon — 20/09/2026 às 19:30"
    },
    "data": {
      "type": "new_event",
      "eventId": "25385992-c728-8029-8c80-e801dbd64b7f",
      "category": "pokemon"
    },
    "android": { "notification": { "channel_id": "event_announcements" } }
  }
}
```

### `data`

| Campo | Obrigatório | Valores |
| --- | --- | --- |
| `type` | não | `new_event`, `event_cancelled`, `event_updated` |
| `eventId` | para abrir o evento | o mesmo `id` que `/events` devolve |
| `category` | não | o nome do valor em `EventCategory` |
| `title` / `body` | não | sobrescrevem o bloco `notification` |

**Todo valor de `data` tem que ser string.** A FCM v1 recusa a mensagem inteira,
com `400`, se algum for número ou booleano.

Um `type` que o app não conhece é exibido, nunca despachado: o servidor não
consegue fazer o app agir inventando um tipo novo. Sem `eventId`, ou com ele
vazio, o toque só abre o app.

`channel_id` tem que ser `event_announcements`, o canal que o app registra para
novidades. É o que permite silenciar a divulgação sem perder o lembrete do
evento que a pessoa marcou — se as duas coisas caírem no mesmo canal, a única
forma de parar uma é parar a outra.

## Não anuncie na primeira execução

Quem compara agendas para achar novidade precisa tratar "não tenho agenda
anterior" como "não anuncie nada, só guarde esta". Sem isso o primeiro deploy
lê a base inteira como novidade e manda um push por evento existente para todo
mundo de uma vez, que é como se ensina uma pessoa a desligar as notificações do
app no mesmo minuto em que ela o instalou.

Pela mesma razão: um evento cancelado que continua cancelado não rende um aviso
a cada passada do cron, e mudança em evento que já aconteceu não rende nenhum.

## A credencial

Enviar exige a chave privada da service account do projeto Firebase, e ela
**nunca** pode ir para o app — quem a tem consegue notificar todo mundo que
instalou. O `google-services.json` que o app carrega serve só para receber, e é
por isso que ele pode ficar no repositório e a outra não. A API legada com
"server key" foi desligada em 2024; use a HTTP v1, que quer um access token
OAuth2 assinado com essa chave.
