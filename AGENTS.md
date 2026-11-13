# punzh-dict-mobile — для агентов

Офлайн Flutter-клиент словаря Пунжиной (тверские говоры).

Sibling monorepo данных/сайта: **`../punzh-dict`**  
(контракт пакета, экспортёр, Django). Не смешивать веб-поиск / AI / ontology
без явной задачи.

| Тема | Где |
|------|-----|
| Семантика словаря (этот repo) | [`docs/DICTIONARY.md`](docs/DICTIONARY.md) |
| Ручной регресс (P7) | [`docs/MANUAL-REGRESSION.md`](docs/MANUAL-REGRESSION.md) |
| Контракт sqlite/manifest (punzh-dict) | [`../punzh-dict/docs/plans/mobile-pack-contract.md`](../punzh-dict/docs/plans/mobile-pack-contract.md) |
| Бэклог / история MVP | [`../punzh-dict/docs/plans/mobile-offline.md`](../punzh-dict/docs/plans/mobile-offline.md) |
| Людям | [`README.md`](README.md) |

## Версионирование приложения

**Источник правды — одна строка в `pubspec.yaml`:**

```yaml
version: X.Y.Z+N
```

| Поле | Куда попадает | Назначение |
|------|---------------|------------|
| `X.Y.Z` (`versionName`) | UI («О приложении»), магазины, имя APK | Семантика релиза для людей |
| `N` (`versionCode`) | Android `versionCode`, имя APK | Монотонный номер сборки; **уникален** для каждой загрузки в магазин |

### Когда бампать

| Ситуация | Что сделать |
|----------|-------------|
| Любая сборка для магазина / «скачать APK» | Обязательно поднять **`+N`** |
| Фикс бага, мелкий UX | patch + `+N` |
| Новая пользовательская возможность | minor + `+N` |
| Ломающее / смена `applicationId` | major; согласовать с человеком |
| Только USB debug | Бамп не обязателен |

### Не путать с версиями данных

| Идентификатор | Где | Когда менять |
|---------------|-----|--------------|
| **App** `X.Y.Z+N` | `pubspec.yaml` | Релизы клиента |
| **`schema_version`** | punzh-dict `schema.py` + Dart `lib/schema.dart` | Несовместимая схема sqlite |
| **`data_version`** | `manifest.json` пакета | Новый снимок словаря |

### Имя APK

`punzh-dict-{versionName}-{versionCode}-{buildType}.apk`  
Скрипты: `scripts/build_apk.sh`, `scripts/debug_usb.sh`, `scripts/sync_seed.sh`
(seed тянется из контейнера Django в **punzh-dict**).

Update path: `{MOBILE_PACK_BASE_URL}/manifest.json` (prod `/mobile-pack/` на сайте).

### Чеклист перед релизным APK

1. Прочитать `version:` в `pubspec.yaml`, поднять `+N` / semver.
2. Актуализировать seed при необходимости (`scripts/sync_seed.sh`).
3. `flutter test` / `flutter analyze`.
4. `scripts/build_apk.sh` → имя файла совпадает с version.
5. В UI «О приложении» — та же `versionName`.
