/// Where the agenda reads its events from.
enum EventsBackend {
  /// Bundled sample data. No network, so it also drives the widget tests and
  /// lets the web build run despite the Notion API refusing browser requests.
  fixtures,

  /// Calls the Notion API straight from the device.
  ///
  /// **Development only.** Whatever token this uses ends up inside the shipped
  /// binary, which is exactly how the Expo build leaked its integration token.
  /// Ship [proxy] instead.
  notionDirect,

  /// Calls a backend that holds the Notion token and returns normalized events.
  ///
  /// The production path. See `PROXY.md` for the contract the endpoint has to
  /// satisfy.
  proxy,
}

/// Everything about this build that is not code.
///
/// Values arrive through `--dart-define` so no secret is written into the
/// source tree. Defaults are the safe ones: sample data and no token.
///
/// ```
/// flutter run --dart-define=EVENTS_BACKEND=proxy \
///             --dart-define=PROXY_BASE_URL=https://events.example.workers.dev
/// ```
class AppConfig {
  const AppConfig({
    required this.backend,
    this.notionToken = '',
    this.notionDatabaseId = '',
    this.proxyBaseUrl = '',
    this.whatsappNumber = '5515998135916',
    this.companyName = 'TableTop — Board & Card Games',
    this.cacheTtl = const Duration(minutes: 5),
    this.reminderLeadTime = const Duration(hours: 3),
  });

  /// Reads the build-time configuration.
  factory AppConfig.fromEnvironment() {
    const backendName = String.fromEnvironment(
      'EVENTS_BACKEND',
      defaultValue: 'fixtures',
    );

    return AppConfig(
      backend: switch (backendName) {
        'notion' || 'notionDirect' => EventsBackend.notionDirect,
        'proxy' => EventsBackend.proxy,
        _ => EventsBackend.fixtures,
      },
      notionToken: const String.fromEnvironment('NOTION_TOKEN'),
      notionDatabaseId: const String.fromEnvironment('NOTION_DATABASE_ID'),
      proxyBaseUrl: const String.fromEnvironment('PROXY_BASE_URL'),
    );
  }

  final EventsBackend backend;

  final String notionToken;
  final String notionDatabaseId;
  final String proxyBaseUrl;

  /// The number the WhatsApp button writes to. Defined once — the Expo app
  /// carried it in two places and they had to be kept in sync by hand.
  final String whatsappNumber;
  final String companyName;

  /// How long a fetched agenda stays fresh before the next read refetches.
  final Duration cacheTtl;

  /// How far ahead of an event its reminder fires.
  final Duration reminderLeadTime;

  /// Whether this build has what the selected backend needs to work.
  bool get isBackendUsable => switch (backend) {
        EventsBackend.fixtures => true,
        EventsBackend.notionDirect =>
          notionToken.isNotEmpty && notionDatabaseId.isNotEmpty,
        EventsBackend.proxy => proxyBaseUrl.isNotEmpty,
      };

  /// What to tell the developer when [isBackendUsable] is false.
  String get backendProblem => switch (backend) {
        EventsBackend.fixtures => '',
        EventsBackend.notionDirect =>
          'Defina NOTION_TOKEN e NOTION_DATABASE_ID via --dart-define.',
        EventsBackend.proxy => 'Defina PROXY_BASE_URL via --dart-define.',
      };
}
