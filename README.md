# punzh-dict-mobile

Офлайн-приложение «Словарь карельского языка (тверские говоры)» Пунжиной.

Данные и сайт — sibling **`../punzh-dict`** (экспорт sqlite, `/mobile-pack/`, Django).  
Семантика клиента: [`docs/DICTIONARY.md`](docs/DICTIONARY.md).  
Агентам: [`AGENTS.md`](AGENTS.md).  
Контракт пакета: [`../punzh-dict/docs/plans/mobile-pack-contract.md`](../punzh-dict/docs/plans/mobile-pack-contract.md).

Версия приложения — `version: X.Y.Z+N` в `pubspec.yaml`.

```bash
scripts/build_apk.sh           # release → punzh-dict-X.Y.Z-N-release.apk
scripts/build_apk.sh --debug
scripts/debug_usb.sh           # hot reload на USB
scripts/sync_seed.sh           # export из punzh-dict → assets/dict.sqlite
```

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
