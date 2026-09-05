/**
 * Envio de push pela FCM HTTP v1.
 *
 * A API legada (`https://fcm.googleapis.com/fcm/send`, com a "server key") foi
 * desligada em 2024. A v1 quer um access token OAuth2, e o unico jeito de
 * conseguir um sem navegador e assinar um JWT com a chave privada da service
 * account — o que da para fazer com a WebCrypto que o Worker ja tem, sem
 * dependencia nenhuma.
 */

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

/** Token em memoria, valido enquanto esta instancia do Worker viver. */
let cachedToken = null;

function base64url(bytes) {
  const binary = String.fromCharCode(...new Uint8Array(bytes));
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** Converte a PEM PKCS#8 da service account no formato que a WebCrypto aceita. */
async function importPrivateKey(pem) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    // A chave vem de uma variavel de ambiente, entao as quebras de linha
    // podem ter chegado como \n literal em vez de quebra de verdade.
    .replace(/\\n/g, '')
    .replace(/\s/g, '');

  const der = Uint8Array.from(atob(body), (char) => char.charCodeAt(0));

  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/**
 * Troca a chave da service account por um access token.
 *
 * Reaproveitado ate um minuto antes de expirar: o token vale uma hora, e pedir
 * um novo a cada push gastaria uma ida a mais no oauth2 por mensagem.
 */
async function accessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const clientEmail = env.FIREBASE_CLIENT_EMAIL;
  const privateKey = env.FIREBASE_PRIVATE_KEY;
  if (!clientEmail || !privateKey) {
    throw new Error(
      'Faltam FIREBASE_CLIENT_EMAIL e FIREBASE_PRIVATE_KEY. Ponha os dois com ' +
        '`wrangler secret put`, nunca no wrangler.toml.',
    );
  }

  const header = base64url(
    new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
  );
  const claims = base64url(
    new TextEncoder().encode(
      JSON.stringify({
        iss: clientEmail,
        scope: SCOPE,
        aud: TOKEN_URL,
        iat: now,
        exp: now + 3600,
      }),
    ),
  );

  const key = await importPrivateKey(privateKey);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );

  const assertion = `${header}.${claims}.${base64url(signature)}`;

  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`oauth2 recusou o JWT: ${response.status} ${await response.text()}`);
  }

  const body = await response.json();
  cachedToken = { value: body.access_token, expiresAt: now + (body.expires_in ?? 3600) };
  return cachedToken.value;
}

/**
 * Manda uma mensagem para um topico.
 *
 * O payload carrega `notification` **e** `data` de proposito. O bloco
 * `notification` e o que o sistema desenha sozinho quando o app esta fechado —
 * sem ele, no iOS a mensagem nem acorda o aparelho. O `data` e o que o app le
 * para saber o que fazer no toque, e e a unica parte que sobrevive intacta a
 * todos os modos de entrega. `PushAnnouncement.fromData` da preferencia ao
 * `data` justamente por isso.
 *
 * As chaves de `data` tem que ser string: a FCM v1 recusa a mensagem inteira,
 * com 400, se algum valor for numero ou booleano.
 */
export async function sendToTopic(env, topic, { title, body, data }) {
  const token = await accessToken(env);
  const projectId = env.FIREBASE_PROJECT_ID;

  const message = {
    topic,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data ?? {})
        .filter(([, value]) => value !== null && value !== undefined)
        .map(([key, value]) => [key, String(value)]),
    ),
    android: {
      priority: 'normal',
      notification: {
        // Tem que ser igual a LocalAnnouncementPresenter.channelId no app.
        channel_id: 'event_announcements',
      },
    },
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message }),
    },
  );

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`FCM recusou o push para ${topic}: ${response.status} ${detail}`);
  }

  return response.json();
}
