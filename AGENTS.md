# punzh-dict-mobile — для агентов

Офлайн Flutter-клиент словаря Пунжиной (тверские говоры).

Sibling monorepo данных/сайта: **`../punzh-dict`**  
(контракт пакета, экспортёр, Django). Не смешивать веб-поиск / AI / ontology
без явной задачи.

| Тема | Где |
|------|-----|
| Функции v1 | [`docs/FEATURES-V1.md`](docs/FEATURES-V1.md) |
| Беклог следующей версии | [`docs/BACKLOG.md`](docs/BACKLOG.md) |
| Семантика словаря (этот repo) | [`docs/DICTIONARY.md`](docs/DICTIONARY.md) |
| Ручной регресс | [`docs/MANUAL-REGRESSION.md`](docs/MANUAL-REGRESSION.md) |
| Контракт sqlite/manifest (punzh-dict) | [`../punzh-dict/docs/plans/mobile-pack-contract.md`](../punzh-dict/docs/plans/mobile-pack-contract.md) |
| Людям (продукт) | [`README.md`](README.md) |
| Сборка и разработка | [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) |

## Ветки и подпись

| Ветка | Release-подпись | Назначение |
|-------|-----------------|------------|
| **`main`** | upload keystore (`android/key.properties` + `*.p12`, **не в git**) | Пилот / магазины |
| **`dev`** | debug (как раньше) | USB / повседневная отладка |

Шаблон: [`android/key.properties.example`](android/key.properties.example).  
Бэкап keystore + `key.properties` — вне репо (потеря = нельзя обновить приложение в магазине с тем же `applicationId`).

### Порядок магазинов (пилот)

1. **RuStore**  
2. Сайт («скачать APK» с главной) — позже  
3. Google Play — по готовности аккаунта / после пилота  

RuStore: обычно **AAB** (`flutter build appbundle --release`) + при необходимости APK.  
Ассеты и листинг: [`store/rustore/`](store/rustore/).

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
Скрипты: `scripts/build_apk.sh`, `scripts/publish_downloads.sh`, `scripts/debug_usb.sh`, `scripts/sync_seed.sh`
(seed тянется из контейнера Django в **punzh-dict**).

Update path (словарь): `{MOBILE_PACK_BASE_URL}/manifest.json` (prod `/mobile-pack/`).  
Update path (приложение, F2): `{MOBILE_PACK_BASE_URL}/app-manifest.json` — пишет
**только** `publish_downloads.sh` при выгрузке APK (не `publish_mobile_pack.sh`).

### После релизной сборки → прод

**Правило:** каждый **release** APK заливается на karielan-hub как стабильное имя
**вместе** с `app-manifest.json` (без манифеста выгрузка неполная):

`krl@karielan-hub:~/punzh-dict/mobile-pack/punzh-dict-latest.apk`  
`krl@karielan-hub:~/punzh-dict/mobile-pack/app-manifest.json`  
Tracked download: `https://punzhina.krc.karelia.ru/app/apk/`  
App manifest: `https://punzhina.krc.karelia.ru/mobile-pack/app-manifest.json`

`scripts/build_apk.sh` (release) вызывает `scripts/publish_downloads.sh` (`scp`).  
Переопределение: `PUNZH_APK_DEPLOY`, `PUNZH_APK_REMOTE_PATH`, `PUNZH_APP_MANIFEST_REMOTE_PATH`,
`PUNZH_APK_DOWNLOAD_URL`.

AAB/APK для витрин — локально в `store/rustore/`
(`punzh-dict-{versionName}-{versionCode}-release.{aab,apk}`); в git не коммитить.
Иконка витрины: `scripts/gen_store_icon.sh` → `store/rustore/icon-512.png` (тоже не в git).
В git из `store/rustore/`: тексты (`listing.md`, `CHECKLIST.md`) и скрины для README.

### Чеклист перед релизным APK / AAB

1. Ветка **`main`**; есть локальные `android/key.properties` + keystore.
2. Прочитать `version:` в `pubspec.yaml`, поднять `+N` / semver.
3. Актуализировать seed при необходимости (`scripts/sync_seed.sh`).
4. `flutter test` / `flutter analyze`.
5. `scripts/build_apk.sh` и/или `flutter build appbundle --release`.
6. Проверить на сервере `punzh-dict-latest.apk` **и** `app-manifest.json` (`version_code` = `+N`); копии в `store/`.
7. В UI «О приложении» — та же `versionName`; для sideload — кнопка проверки приложения.
8. Артефакт подписан **upload**, не debug (`jarsigner -verify` / Play App Signing dump).
