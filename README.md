# TableTop Events

Agenda de eventos de board games e card games da TableTop Sorocaba. Lê os
eventos de uma base do Notion e mostra em três telas: destaque na home,
próximos 7 dias, e calendário mensal completo.

Reescrita em Flutter do app Expo/React Native original. Todas as
funcionalidades do app anterior, mais lembretes locais de evento, estados de
erro com retry, pull-to-refresh e deep links.

- **Flutter** 3.44 · **Dart** 3.12
- **Android** `com.tabletop.events` · **iOS** `com.tabletop.events`
- Deep link: `tabletopevents://` (`/`, `/semana`, `/calendario`)

## Rodando

```bash
flutter pub get
flutter run
```

Sem nenhuma configuração, o app sobe com a **agenda de exemplo** de
`assets/fixtures/events.json` — sem rede, sem token. É o suficiente para
desenvolver e revisar qualquer tela.

### Apontando para dados reais

A fonte de eventos é escolhida em tempo de build por `EVENTS_BACKEND`:

```bash
flutter run --dart-define=EVENTS_BACKEND=proxy --dart-define=PROXY_BASE_URL=https://eventos.exemplo.workers.dev
```

```bash
flutter run --dart-define=EVENTS_BACKEND=notion --dart-define=NOTION_TOKEN=ntn_xxx --dart-define=NOTION_DATABASE_ID=xxx
```

> **Nunca publique com `EVENTS_BACKEND=notion`.** O token vai para dentro do
> binário e pode ser extraído de qualquer APK — foi exatamente assim que o
> token da versão Expo acabou publicado. Navegadores também não conseguem
> chamar a API do Notion: ela não envia cabeçalhos de CORS. Veja
> [PROXY.md](PROXY.md) para o contrato que o backend precisa atender.

Nenhum segredo mora no repositório. `AppConfig` lê tudo de `--dart-define` e o
padrão é a agenda de exemplo.

## Testes

```bash
flutter test
```

116 testes. Os que mais importam são os de data em
`test/calendar_date_test.dart` e `test/event_filters_test.dart`: eles travam o
comportamento que a versão Expo errava — um evento acontecendo **hoje** aparece
na semana, e a data de um evento é a mesma em todas as telas.

```bash
flutter analyze
```

## Estrutura

```
lib/
├── main.dart                 lê a preferência de tema antes do primeiro frame
├── app.dart                  MaterialApp.router, tema, locale pt-BR
├── core/
│   ├── config/               AppConfig — backend, WhatsApp, TTL, lembretes
│   ├── format/               moeda BRL e datas pt-BR, num lugar só
│   ├── router/               go_router: /, /semana, /calendario
│   └── theme/                AppPalette (ThemeExtension), AppTheme, AppIcons
├── domain/
│   ├── calendar_date.dart    aritmética de datas — o núcleo de correção
│   ├── event.dart            Event, EventStatus, RichRun
│   ├── event_category.dart   heurística de categoria por nome e tags
│   └── event_filters.dart    hoje / próximos N dias / um dia
├── data/
│   ├── events_data_source.dart   interface + EventsFailure
│   ├── fixture_data_source.dart  agenda de exemplo (dev, testes, web)
│   ├── notion_data_source.dart   API do Notion, paginada (só dev)
│   ├── proxy_data_source.dart    backend de produção + formato do payload
│   ├── notion_mapper.dart        página do Notion → Event
│   ├── events_repository.dart    cache com TTL, requisições coalescidas
│   └── events_providers.dart     a troca de backend é UMA LINHA aqui
├── features/                 shell, home, weekly, calendar, events, common
└── notifications/            lembrete local agendado por evento
```

### Onde trocar as coisas

| O quê | Onde |
| --- | --- |
| Fonte de eventos | `eventsDataSourceProvider` em `lib/data/events_providers.dart` |
| Número do WhatsApp | `AppConfig.whatsappNumber` (um lugar só) |
| Validade do cache | `AppConfig.cacheTtl` (5 min) |
| Antecedência do lembrete | `AppConfig.reminderLeadTime` (3 h) |
| Cores | `AppPalette.light` / `AppPalette.dark` |
| Ícones | `lib/core/theme/app_icons.dart` |
| Propriedades do Notion | `NotionMapper` — aceita nome em PT e EN |

## Assets nativos

Ícone e splash são gerados a partir de `assets/images/app_icon.png`:

```bash
dart run flutter_launcher_icons
```

```bash
dart run flutter_native_splash:create
```

## Notas de build

- **Android:** o SDK precisa de `cmdline-tools` e das licenças aceitas
  (`flutter doctor --android-licenses`) antes do primeiro build.
- **iOS:** exige macOS com Xcode.
- **Web:** compila e roda, mas só com `EVENTS_BACKEND=proxy` ou `fixtures` — o
  Notion recusa requisições de navegador. Lembretes não existem no web e a UI
  esconde o sino em vez de oferecer algo que não funciona.
