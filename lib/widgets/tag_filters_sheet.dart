import "dart:async";

import "package:material_ui/material_ui.dart";

import "../data/tag_filter_state.dart";
import "../theme.dart";

typedef TagFacetsLoader = Future<TagFacets> Function(TagFilterState filters);

/// Modal bottom sheet: website-style facets for the current KRL result base.
Future<void> showTagFiltersSheet({
  required BuildContext context,
  required TagFilterState filters,
  required TagFacetsLoader loadFacets,
}) {
  final height = MediaQuery.sizeOf(context).height * 0.75;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SizedBox(
        height: height,
        child: _TagFiltersSheetBody(filters: filters, loadFacets: loadFacets),
      );
    },
  );
}

class _TagFiltersSheetBody extends StatefulWidget {
  const _TagFiltersSheetBody({
    required this.filters,
    required this.loadFacets,
  });

  final TagFilterState filters;
  final TagFacetsLoader loadFacets;

  @override
  State<_TagFiltersSheetBody> createState() => _TagFiltersSheetBodyState();
}

class _TagFiltersSheetBodyState extends State<_TagFiltersSheetBody> {
  TagFacets? _facets;
  Object? _error;
  bool _loading = true;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    widget.filters.addListener(_onFiltersChanged);
    unawaited(_reload());
  }

  @override
  void dispose() {
    widget.filters.removeListener(_onFiltersChanged);
    super.dispose();
  }

  void _onFiltersChanged() => unawaited(_reload());

  Future<void> _reload() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final facets = await widget.loadFacets(widget.filters);
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _facets = facets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final facets = _facets;
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFADB5BD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Пометы",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: widget.filters.isEmpty
                      ? null
                      : () => widget.filters.clear(),
                  child: const Text("Сбросить"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Готово"),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading && facets == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null && facets == null
                    ? Center(child: Text("$_error"))
                    : _buildFacetList(
                        facets ??
                            const TagFacets(
                              optionsByType: {},
                              enabledTagIds: {},
                              showPhrase: false,
                              phraseEnabled: false,
                            ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacetList(TagFacets facets) {
    if (facets.isEmpty && widget.filters.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text("В текущей выдаче нет подходящих помет."),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        for (final type in krlTagGroupOrder) ...[
          if (facets.optionsForType(type).isNotEmpty) ...[
            Text(
              krlTagGroupTitles[type] ?? "Пометы",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF6C757D),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final tag in facets.optionsForType(type))
                  FilterChip(
                    label: Text(
                      tag.label,
                      style: const TextStyle(fontSize: 13, height: 1.1),
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    padding: EdgeInsets.zero,
                    selected:
                        widget.filters.selectedIdForType(type) == tag.id,
                    onSelected: facets.isTagEnabled(tag.id)
                        ? (_) => widget.filters.toggleTag(tag)
                        : null,
                    selectedColor:
                        PunzhColors.brand.withValues(alpha: 0.18),
                    checkmarkColor: PunzhColors.brand,
                    visualDensity: const VisualDensity(
                      horizontal: 0,
                      vertical: -4,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(
                      color: widget.filters.selectedIdForType(type) == tag.id
                          ? PunzhColors.brand
                          : const Color(0xFFCED4DA),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (facets.showPhrase)
          CheckboxListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            contentPadding: EdgeInsets.zero,
            value: widget.filters.phrase,
            onChanged: facets.phraseEnabled || widget.filters.phrase
                ? (_) => widget.filters.togglePhrase()
                : null,
            title: const Text(
              krlPhraseFilterLabel,
              style: TextStyle(fontSize: 13, height: 1.2),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: PunzhColors.brand,
          ),
      ],
    );
  }
}


/// Shown only when Karelian search has hits: open-filters control + active chips.
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.filters,
    required this.onOpenFilters,
    required this.onChanged,
  });

  final TagFilterState filters;
  final VoidCallback onOpenFilters;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: filters,
      builder: (context, _) {
        // Compact wrap under the alphabet — not a full-width scroll strip.
        const density = VisualDensity(horizontal: 0, vertical: -4);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  tooltip: "Выбрать пометы",
                  avatar: Icon(
                    filters.isEmpty
                        ? Icons.filter_alt_outlined
                        : Icons.filter_alt,
                    size: 16,
                    color: PunzhColors.brand,
                  ),
                  label: Text(
                    filters.isEmpty
                        ? "Пометы"
                        : "Пометы (${filters.activeCount})",
                    style: const TextStyle(fontSize: 13, height: 1.1),
                  ),
                  labelPadding: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  onPressed: onOpenFilters,
                  side: const BorderSide(color: PunzhColors.brand),
                  visualDensity: density,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                for (final id in filters.tagIds)
                  InputChip(
                    label: Text(
                      filters.tagById(id)?.label ?? "#$id",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.1),
                    ),
                    labelPadding: const EdgeInsets.only(left: 6),
                    padding: EdgeInsets.zero,
                    onDeleted: () {
                      filters.removeTagId(id);
                      onChanged();
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: density,
                    side: const BorderSide(color: PunzhColors.brand),
                  ),
                if (filters.phrase)
                  InputChip(
                    label: const Text(
                      krlPhraseFilterLabel,
                      style: TextStyle(fontSize: 13, height: 1.1),
                    ),
                    labelPadding: const EdgeInsets.only(left: 6),
                    padding: EdgeInsets.zero,
                    onDeleted: () {
                      filters.setPhrase(false);
                      onChanged();
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: density,
                    side: const BorderSide(color: PunzhColors.brand),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
