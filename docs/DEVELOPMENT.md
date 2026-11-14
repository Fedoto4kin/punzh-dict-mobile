# Разработка

Офлайн Flutter-клиент словаря Пунжиной. Продуктовое описание — в [`README.md`](../README.md).

Данные и сайт — sibling **`../punzh-dict`** (экспорт sqlite, `/mobile-pack/`, Django).

| Тема | Где |
|------|-----|
| Семантика клиента | [`DICTIONARY.md`](DICTIONARY.md) |
| Ручной регресс | [`MANUAL-REGRESSION.md`](MANUAL-REGRESSION.md) |
| Агентам (ветки, версия, магазины) | [`AGENTS.md`](../AGENTS.md) |
| Контракт пакета | [`../punzh-dict/docs/plans/mobile-pack-contract.md`](../../punzh-dict/docs/plans/mobile-pack-contract.md) |

Версия приложения — `version: X.Y.Z+N` в `pubspec.yaml`.  
Ветки: **`main`** — store/release (нужен `android/key.properties`); **`dev`** — USB/debug.

```bash
scripts/build_apk.sh           # release → APK + scp на прод как punzh-dict-latest.apk
flutter build appbundle --release   # AAB для RuStore / AppGallery
scripts/publish_downloads.sh   # только заливка APK на сервер (если уже собран)
scripts/build_apk.sh --debug
scripts/debug_usb.sh           # hot reload на USB (удобнее с ветки dev)
scripts/sync_seed.sh           # export из punzh-dict → assets/dict.sqlite
```

Скачать APK: <https://punzhina.krc.karelia.ru/mobile-pack/punzh-dict-latest.apk>  
Витрины: [`store/rustore/`](../store/rustore/), [`store/huawei/`](../store/huawei/).

## Обновление словаря (пакет данных)

Прод: `https://punzhina.krc.karelia.ru/mobile-pack/manifest.json`  
Публикация пакета — из **punzh-dict**: `scripts/publish_mobile_pack.sh`.

В меню приложения: «Проверить и загрузить обновление БД».

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
