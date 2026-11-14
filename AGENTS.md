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

## Ветки и подпись

| Ветка | Release-подпись | Назначение |
|-------|-----------------|------------|
| **`main`** | upload keystore (`android/key.properties` + `*.p12`, **не в git**) | Пилот / магазины |
| **`dev`** | debug (как раньше) | USB / повседневная отладка |

Шаблон: [`android/key.properties.example`](android/key.properties.example).  
Бэкап keystore + `key.properties` — вне репо (потеря = нельзя обновить приложение в магазине с тем же `applicationId`).

### Порядок магазинов (пилот)

1. **RuStore**  
2. **Huawei AppGallery**  
3. Сайт («скачать APK» с главной) — позже  
4. Google Play — по готовности аккаунта / после пилота  

RuStore / Huawei AppGallery: обычно **AAB** (`flutter build appbundle --release`) + при необходимости APK.  
Ассеты и листинг Huawei: [`store/huawei/`](store/huawei/) (`listing.md`, `CHECKLIST.md`).  
Пока одна и та же сборка висит в RuStore — для AppGallery **не** бампать `+N`; грузить тот же `1.0.0+N`. HMS для пилота не нужен.

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

Update path: `{MOBILE_PACK_BASE_URL}/manifest.json` (prod `/mobile-pack/` на сайте).

### После релизной сборки → `punzh-dict` / коммит

**Правило:** каждый **release** APK после сборки кладётся в sibling  
[`../punzh-dict/app/downloads/`](../punzh-dict/app/downloads/) и **коммитится в репозитории punzh-dict** (не в mobile).

| Файл в `app/downloads/` | Назначение |
|-------------------------|------------|
| `punzh-dict-{versionName}-{versionCode}.apk` | версионированный артефакт |
| `punzh-dict.apk` | стабильное имя «скачать последнюю» |
| `manifest.json` | version / sha256 / size / built_at |

`scripts/build_apk.sh` (release) сам вызывает `scripts/publish_downloads.sh`.  
AAB для магазинов — отдельно (`store/rustore/`, AppGallery); в `downloads/` — APK для сайта/архива.

Коммит пример:

```bash
git -C ../punzh-dict add app/downloads/
git -C ../punzh-dict commit -m "Add Android APK $(grep -E '^version:' pubspec.yaml | awk '{print $2}')."
```

### Чеклист перед релизным APK / AAB

1. Ветка **`main`**; есть локальные `android/key.properties` + keystore.
2. Прочитать `version:` в `pubspec.yaml`, поднять `+N` / semver.
3. Актуализировать seed при необходимости (`scripts/sync_seed.sh`).
4. `flutter test` / `flutter analyze`.
5. `scripts/build_apk.sh` и/или `flutter build appbundle --release`.
6. Проверить `../punzh-dict/app/downloads/` (APK + `manifest.json`); **закоммитить в punzh-dict**.
7. В UI «О приложении» — та же `versionName`.
8. Артефакт подписан **upload**, не debug (`jarsigner -verify` / Play App Signing dump).
