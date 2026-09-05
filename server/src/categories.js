/**
 * A porta de `EventCategory` do app para o servidor.
 *
 * Isto tem que ser um espelho exato de `lib/domain/event_category.dart`. O app
 * assina o topico `game_<categoria>` usando a deteccao dele, e o servidor
 * escolhe o topico usando esta — se as duas divergirem, um evento vai para o
 * topico que ninguem assinou e o push simplesmente nao chega, sem erro nenhum
 * em lugar nenhum. Mudou la, muda aqui.
 *
 * A ordem de declaracao e a ordem de precedencia: um "Torneio de Pokemon" e
 * arquivado em Pokemon, porque o jogo importa mais que o formato para quem
 * escolheu o que seguir.
 */
export const CATEGORIES = [
  { name: 'pokemon', label: 'Pokémon TCG', keywords: ['pokemon', 'ptcg'] },
  { name: 'digimon', label: 'Digimon', keywords: ['digimon'] },
  { name: 'magic', label: 'Magic: The Gathering', keywords: ['magic', 'mtg'] },
  { name: 'yugioh', label: 'Yu-Gi-Oh!', keywords: ['yugioh', 'yu-gi-oh', 'ygo'] },
  { name: 'gundam', label: 'Gundam', keywords: ['gundam'] },
  {
    name: 'boardGames',
    label: 'Board Games',
    keywords: ['board', 'tabuleiro', 'boardgame'],
  },
  { name: 'rpg', label: 'RPG', keywords: ['rpg', 'd&d', 'dnd', 'tormenta'] },
  {
    name: 'tournament',
    label: 'Torneio',
    keywords: ['torneio', 'campeonato', 'tournament', 'liga'],
  },
  { name: 'other', label: 'Evento Especial', keywords: [] },
];

/**
 * Minusculas e sem os acentos que nome de evento em portugues carrega.
 *
 * Usa o mesmo mapa explicito do Dart em vez de normalize('NFD'), que tiraria
 * acento de mais e faria as duas implementacoes divergirem em algum nome que
 * ninguem testou.
 */
const ACCENTS = {
  á: 'a', à: 'a', ã: 'a', â: 'a', ä: 'a',
  é: 'e', è: 'e', ê: 'e', ë: 'e',
  í: 'i', ì: 'i', î: 'i', ï: 'i',
  ó: 'o', ò: 'o', õ: 'o', ô: 'o', ö: 'o',
  ú: 'u', ù: 'u', û: 'u', ü: 'u',
  ç: 'c', ñ: 'n',
};

export function fold(value) {
  let folded = String(value ?? '').toLowerCase();
  for (const [accented, plain] of Object.entries(ACCENTS)) {
    folded = folded.split(accented).join(plain);
  }
  return folded;
}

/** A primeira categoria cujas palavras aparecem no nome ou nas tags. */
export function detectCategory(name, tags = []) {
  const haystack = fold(`${name ?? ''} ${(tags ?? []).join(' ')}`);
  for (const category of CATEGORIES) {
    if (category.name === 'other') continue;
    if (category.keywords.some((keyword) => haystack.includes(keyword))) {
      return category;
    }
  }
  return CATEGORIES[CATEGORIES.length - 1];
}

/**
 * O topico FCM de uma categoria.
 *
 * Prefixado para nunca colidir com outra coisa no projeto Firebase, igual ao
 * `InterestsController.topics`.
 */
export function topicFor(category) {
  return `game_${category.name}`;
}
