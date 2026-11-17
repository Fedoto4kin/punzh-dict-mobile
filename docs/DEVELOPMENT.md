# Разработка

Офлайн Flutter-клиент словаря Пунжиной. Продуктовое описание — в [`README.md`](../README.md).

Данные и сайт — sibling **`../punzh-dict`** (экспорт sqlite, `/mobile-pack/`, Django).

| Тема | Где |
|------|-----|
| Функции v1 | [`FEATURES-V1.md`](FEATURES-V1.md) |
| Беклог следующей версии | [`BACKLOG.md`](BACKLOG.md) |
| Семантика клиента | [`DICTIONARY.md`](DICTIONARY.md) |
| Ручной регресс | [`MANUAL-REGRESSION.md`](MANUAL-REGRESSION.md) |
| Агентам (ветки, версия, магазины) | [`AGENTS.md`](../AGENTS.md) |
| Контракт пакета | [`../punzh-dict/docs/plans/mobile-pack-contract.md`](../../punzh-dict/docs/plans/mobile-pack-contract.md) |

Версия приложения — `version: X.Y.Z+N` в `pubspec.yaml`.  
Ветки: **`main`** — store/release (нужен `android/key.properties`); **`dev`** — USB/debug.

```bash
scripts/build_apk.sh           # release → APK + app-manifest.json на прод
flutter build appbundle --release   # AAB для RuStore
scripts/publish_downloads.sh   # заливка APK + app-manifest.json (если уже собран)
scripts/build_apk.sh --debug
scripts/debug_usb.sh           # hot reload на USB (удобнее с ветки dev)
scripts/sync_seed.sh           # export из punzh-dict → assets/dict.sqlite
scripts/gen_store_icon.sh      # 512×512 для RuStore (не в git)
```

Скачать APK (со счётчиком): <https://punzhina.krc.karelia.ru/app/apk/>  
Прямой файл: <https://punzhina.krc.karelia.ru/mobile-pack/punzh-dict-latest.apk>  
Манифест приложения: <https://punzhina.krc.karelia.ru/mobile-pack/app-manifest.json>  
Витрина: [`store/rustore/`](../store/rustore/) — staging под консоль; APK/AAB и `icon-512.png` локально.

## Обновление словаря (пакет данных)

Прод: `https://punzhina.krc.karelia.ru/mobile-pack/manifest.json`  
Публикация пакета — из **punzh-dict**: `scripts/publish_mobile_pack.sh`.

В меню приложения: «Проверить и загрузить обновление БД».

## Обновление приложения (APK, non-store)

`app-manifest.json` пишет **только** `scripts/publish_downloads.sh` при выгрузке
release APK (вместе с `punzh-dict-latest.apk`). Экспортёр словаря /
`publish_mobile_pack.sh` этот файл не трогает.

Клиент сравнивает **только** `version_code`. Кнопка проверки — в «О приложении»,
и только если установка не из RuStore/Play (см. F2 в [`BACKLOG.md`](BACKLOG.md)).

## Seed

`assets/dict.sqlite` в git не коммитится. Для тестов — `test/fixtures/mini.sqlite`.

```bash
# нужен запущенный Django-контейнер в punzh-dict
scripts/sync_seed.sh
```

## Тесты

```bash
flutter test
flutter analyze
```
