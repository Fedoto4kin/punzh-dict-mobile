import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:punzh_dict/data/tag_filter_state.dart";
import "package:punzh_dict/widgets/tag_filters_sheet.dart";

void main() {
  testWidgets("filter sheet opens and shows facets", (tester) async {
    final filters = TagFilterState()
      ..setCatalog([
        const DictTag(
          id: 33,
          tag: "s",
          name: "substantivum",
          type: 2,
          level: 0,
          sorting: 1,
        ),
        const DictTag(
          id: 36,
          tag: "v",
          name: "verbum",
          type: 2,
          level: 0,
          sorting: 2,
        ),
      ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showTagFiltersSheet(
                    context: context,
                    filters: filters,
                    loadFacets: (_) async => TagFacets(
                      optionsByType: {
                        2: filters.tagsOfType(2),
                      },
                      enabledTagIds: {
                        for (final tag in filters.tagsOfType(2)) tag.id,
                      },
                      showPhrase: true,
                      phraseEnabled: true,
                    ),
                  );
                },
                child: const Text("open"),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
    expect(find.text("Пометы"), findsOneWidget);
    expect(find.text("substantivum"), findsOneWidget);
    await tester.tap(find.text("substantivum"));
    await tester.pumpAndSettle();
    expect(filters.tagIds, [33]);
  });
}
