import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// A dropdown that searches as you type.
///
/// Replaces the mix of free-text fields, bare dropdowns and modal sheets the
/// app used for "pick one of these" inputs. Free text is only ever a fallback
/// here: every field that has a known set of options should use this so the
/// stored value is one of the real options rather than a typo.
class SearchableSelect<T> extends StatelessWidget {
  const SearchableSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    this.searchBuilder,
    this.onChanged,
    this.icon,
    this.helperText,
    this.emptyLabel = 'Nothing matches that search.',
    this.isRequired = false,
    this.validator,
  });

  final String label;
  final T? value;
  final List<T> items;

  /// Shown in the closed button and in each result row.
  final String Function(T) labelBuilder;

  /// Matches the query. Defaults to a case-insensitive prefix match on
  /// [labelBuilder], which is what people expect from a select box.
  final bool Function(T, String)? searchBuilder;

  final ValueChanged<T?>? onChanged;
  final IconData? icon;
  final String? helperText;
  final String emptyLabel;
  final bool isRequired;
  final String? Function(String?)? validator;

  bool _defaultMatch(T item, String query) {
    if (query.isEmpty) return true;
    final String haystack = labelBuilder(item).toLowerCase();
    final String needle = query.toLowerCase().trim();
    return haystack.contains(needle);
  }

  void _open(BuildContext context) {
    final SearchableSelect<T> self = this;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Bounded so the sheet can never exceed the viewport; the list scrolls.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (BuildContext context) =>
          _SearchableSelectSheet<T>(select: self),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? currentLabel =
        value == null ? null : labelBuilder(value as T);

    return FormField<T>(
      initialValue: value,
      validator: (T? v) {
        if (isRequired && v == null) return 'Choose $label.';
        return validator?.call(v == null ? null : labelBuilder(v));
      },
      builder: (FormFieldState<T> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Filled rather than underlined so long labels ellipsize instead
            // of forcing the row wider than the screen.
            InkWell(
              onTap: () => _open(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InputDecorator(
                isEmpty: value == null,
                decoration: InputDecoration(
                  labelText: label,
                  helperText: helperText,
                  errorText: field.errorText,
                  prefixIcon: icon == null ? null : Icon(icon),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  currentLabel ?? 'Choose $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: value == null
                      ? theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchableSelectSheet<T> extends StatefulWidget {
  const _SearchableSelectSheet({required this.select});

  final SearchableSelect<T> select;

  @override
  State<_SearchableSelectSheet<T>> createState() =>
      _SearchableSelectSheetState<T>();
}

class _SearchableSelectSheetState<T> extends State<_SearchableSelectSheet<T>> {
  final TextEditingController _query = TextEditingController();
  late List<T> _results = _filter('');

  List<T> _filter(String q) {
    final SearchableSelect<T> s = widget.select;
    final bool Function(T, String) match = s.searchBuilder ?? s._defaultMatch;
    return s.items.where((T item) => match(item, q)).toList();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SearchableSelect<T> s = widget.select;

    return Padding(
      // Lift above the keyboard so results stay visible while typing.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text('Choose ${s.label}', style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (String v) => setState(() => _results = _filter(v)),
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _query.clear();
                          setState(() => _results = _filter(''));
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      s.emptyLabel,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (BuildContext context, int i) {
                      final T item = _results[i];
                      final bool selected = item == s.value;
                      return ListTile(
                        title: Text(
                          s.labelBuilder(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: selected
                            ? Icon(Icons.check, color: theme.colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          s.onChanged?.call(item);
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}