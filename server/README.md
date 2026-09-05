# O backend

Um Cloudflare Worker que faz as duas coisas que o app não pode fazer sozinho:
serve a agenda do Notion (guardando o token) e manda o push do que mudou.

```
GET  /events     a agenda, no formato do PROXY.md
POST /announce   dispara a comparação agora (protegido por ADMIN_TOKEN)
cron */15        compara e anuncia sozinho
```

## Subindo

```bash
cd server
npm install
npx wrangler kv namespace create AGENDA
```

Cole o `id` devolvido no `wrangler.toml`, no lugar de `COLE_O_ID_DO_KV_AQUI`.

### Os segredos

Nenhum destes vai no `wrangler.toml` — aquele arquivo vai para o git.

```bash
npx wrangler secret put NOTION_TOKEN
npx wrangler secret put NOTION_DATABASE_ID
npx wrangler secret put FIREBASE_CLIENT_EMAIL
npx wrangler secret put FIREBASE_PRIVATE_KEY
npx wrangler secret put ADMIN_TOKEN
```

`FIREBASE_CLIENT_EMAIL` e `FIREBASE_PRIVATE_KEY` saem do JSON da service
account: no console do Firebase, **Configurações do projeto → Contas de
serviço → Gerar nova chave privada**. Cole a `private_key` inteira, incluindo
as linhas `-----BEGIN PRIVATE KEY-----` e `-----END PRIVATE KEY-----`.

Essa chave assina push em nome do projeto. Quem a tem consegue notificar todo
mundo que instalou o app — trate como senha de produção, e nunca a coloque no
app: o `google-services.json` que o app carrega **não** serve para enviar, só
para receber, e é por isso que ele pode ficar no repositório e esta não.

```bash
npx wrangler deploy
```

## Conferindo

```bash
curl -s https://tabletop-events.SEU-SUBDOMINIO.workers.dev/events | head -40
```

O formato tem teste de contrato do lado do app, em
`test/fixture_data_source_test.dart`, no grupo `the proxy payload format`. Se o
Worker responde algo que aqueles testes aceitam, o app lê.

Para o push, sem esperar o cron:

```bash
curl -X POST -H "x-admin-token: SEU_ADMIN_TOKEN" \
  https://tabletop-events.SEU-SUBDOMINIO.workers.dev/announce
```

A primeira chamada responde `{"seeded":true,"sent":0}` e **não manda nada**:
ela só grava a agenda atual como ponto de partida. Isso é proposital — sem
isso o primeiro deploy trataria a base inteira como novidade e mandaria um
push por evento existente para todo mundo de uma vez. A partir da segunda
chamada, só o que mudou vira aviso.

## Apontando o app para cá

```bash
flutter build apk --dart-define=EVENTS_BACKEND=proxy \
                  --dart-define=PROXY_BASE_URL=https://tabletop-events.SEU-SUBDOMINIO.workers.dev
```

## Testes

```bash
npm test
```

Cobrem o que é lógica pura: a leitura de um registro do Notion e a decisão do
que merece um push. O que fala com a rede — Notion, OAuth2, FCM — não é
coberto e só se prova em produção.

## Uma coisa que precisa ser mantida à mão

`src/categories.js` é um espelho de `lib/domain/event_category.dart`. O app
assina `game_<categoria>` usando a detecção dele e o Worker publica usando a
daqui. **Se as duas divergirem, o push vai para um tópico que ninguém assinou e
não chega — sem erro em lugar nenhum.** Mudou a lista ou as palavras-chave de
um lado, mude no outro. Os dois lados têm teste fixando os mesmos casos.

## O que ainda falta

Imagens hospedadas dentro do Notion voltam como URL assinada que expira em
cerca de uma hora, e o app cacheia imagem. `fileUrl()` já prefere o link
externo quando existe; para arquivos internos, a correção é copiar o binário
para o R2 no cron e devolver a URL de lá.
