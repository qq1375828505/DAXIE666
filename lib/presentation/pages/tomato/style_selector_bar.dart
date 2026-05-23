import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_ide/core/constants.dart';
import 'package:novel_ide/data/models/tomato_preset_model.dart';
import 'package:novel_ide/presentation/state/app_providers.dart';

class StyleSelectorBar extends ConsumerWidget {
  final Function(TomatoPreset?) onPresetSelected;

  const StyleSelectorBar({super.key, required this.onPresetSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(tomatoPresetsProvider);
    final currentPreset = ref.watch(currentPresetProvider);
    final selectedCategory = ref.watch(categoryFilterProvider);

    final categories = {
      'all': '全部',
      'urban': '都市',
      'fantasy': '玄幻',
      '穿越': '穿越',
      '悬疑': '悬疑',
      'female': '女频',
    };

    final filteredPresets = selectedCategory == 'all'
        ? presets
        : presets.where((p) => p.category == selectedCategory).toList();

    return Container(
      height: 88,
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final entry = categories.entries.elementAt(index);
                final isSelected = selectedCategory == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: AppColors.tomatoRed.withOpacity(0.15),
                    backgroundColor: Colors.grey[100],
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      ref.read(categoryFilterProvider.notifier).state = entry.key;
                    },
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filteredPresets.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = currentPreset == null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('默认', style: TextStyle(fontSize: 12)),
                      selected: isSelected,
                      selectedColor: Colors.grey[300],
                      checkmarkColor: Colors.grey[700],
                      onSelected: (_) {
                        ref.read(currentPresetProvider.notifier).state = null;
                        onPresetSelected(null);
                      },
                    ),
                  );
                }
                final preset = filteredPresets[index - 1];
                final isSelected = currentPreset?.id == preset.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(preset.name, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: AppColors.tomatoRed.withOpacity(0.2),
                    backgroundColor: Colors.grey[100],
                    side: isSelected ? BorderSide(color: AppColors.tomatoRed.withOpacity(0.5)) : BorderSide.none,
                    onSelected: (_) {
                      ref.read(currentPresetProvider.notifier).state = preset;
                      onPresetSelected(preset);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
