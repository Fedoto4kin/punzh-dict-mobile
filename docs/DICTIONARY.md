# Устройство словаря (для офлайн-клиента)

Семантика **поиска, помет, карточки и указателя** для Flutter-приложения
в этом репозитории (`punzh-dict-mobile`).

**DDL / манифест / экспорт** — канон в sibling monorepo **punzh-dict**:

- [`../punzh-dict/docs/plans/mobile-pack-contract.md`](../../punzh-dict/docs/plans/mobile-pack-contract.md)
- `punzh-dict/app/dict/mobile/schema.py` + `export_mobile_db`

Клиент *потребляет* пакет; схема сверяется по `schema_version`.

Офлайн — **ограниченный** клиент электронной версии. Не дублирует ontology,
AI-поиск, леммы RU, `?f=`, веб-trigram. При расхождении с вебом сверять в
punzh-dict: `app/dict/search/krl.py` и `partials/search_help.html`; поведение
офлайна задаётся этим файлом и кодом в `lib/`.

## Направление поиска

Как `detect_direction` на сайте: любая кириллица → **русский**, иначе
**карельский** (`lib/search_direction.dart`).

## Карельский поиск

- Индекс: таблица `words` (LIKE, `COLLATE NOCASE`).
- Нормализация запроса: `prepareKrlIlikeQuery` / `prepare_krl_ilike_query`
  (апострофы; š/č/ž без «птичек»; ü↔y; `.` → один символ; `?` → `%`;
  внутренние дефисы ≈ пробел). **Без** авто-префикса `%`: полное совпадение
  паттерна, если пользователь не поставил `?` / `.`.
- Fuzzy: если точных хитов нет — «Возможно вы искали» (Levenshtein ≤ 2 по
  `words`, без PG-trigram); чип подставляет слово и перезапускает поиск.
- Лимит выдачи: 200 статей.

Код: `lib/krl_query.dart`, `lib/levenshtein.dart`, `DictionaryRepository.searchKarelian*`.

## Русский поиск

- Индекс: `translations.rus_word`, префикс `foo%` (ё→е).
- Без лемм, стопов, multi-word OR, `?f=exact/all`, expand по «см.» в поиске.

## Пометы (фильтры KRL)

- Только после KRL-поиска с непустой primary-выдачей.
- Типы 1–4 (radio ≤1 на тип, AND между типами); type 5 — фразеологизмы
  (отдельный флаг, не chip type).
- Grammar (type 2): только родители `level=0`.
- Фасеты из **нефильтрованного** hit set; неприменимые AND-комбинации —
  visible but disabled.
- Полоску «Пометы» **не показывать**, если нет реального выбора
  (`TagFacets.hasFilterChoices`: меньше двух разных помет и нет контраста
  по фразеологизмам). Оставлять, если уже есть активные фильтры (сброс).

Пользовательская справка в UI: пункт меню «Как искать»
(`lib/content/about_copy.dart`).

## Алфавитный указатель

- Буквы `KRL_ABC` (`lib/schema.dart` → `krlAbc`).
- Выборка: `articles.first_letter` + `ORDER BY sort_key, id`.
- Большие списки / KRL-выдача: n-gram scrubber и окна страниц (`lib/ngram.dart`).
- Фильтры помет на указателе **не** применяются.

## Карточка статьи

- HTML из `articles.article_html` + `additions`.
- Заголовок: `word_normalized` или orthography-clear (`lib/orthography.dart`).
- Связи «см.» / «от» (и родственные `links.kind`): стек карточек, system back = pop.
- Закладки: `bookmarks.json` вне пакета данных (переживают update БД).

## Обновление данных

- Remote: `{MOBILE_PACK_BASE_URL}/manifest.json` (prod `/mobile-pack/`).
- Проверка `schema_version` / `min_app` / `sha256`, атомарная замена runtime DB.
- Seed в APK — fallback при первом запуске / отсутствии runtime-файла.
- Сборка пакета и publish — в **punzh-dict** (`export_mobile_db`,
  `scripts/publish_mobile_pack.sh`).

## Версии (не путать)

| Что | Где |
|-----|-----|
| App `X.Y.Z+N` | `pubspec.yaml` |
| `schema_version` | пакет / `lib/schema.dart` (должен совпадать с punzh-dict `schema.py`) |
| `data_version` | пакет `manifest` + `meta` |

Подробнее: [`AGENTS.md`](../AGENTS.md).
