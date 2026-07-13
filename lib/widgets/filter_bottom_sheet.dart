import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

void showFilterBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const FilterBottomSheet(),
  );
}

class FilterBottomSheet extends StatelessWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<NotesProvider>(
      builder: (context, notesProvider, child) {
        final filter = notesProvider.filter;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.getDividerColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.filterNotes,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimaryColor(context),
                    ),
                  ),
                  if (filter.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        notesProvider.clearFilters();
                      },
                      child: Text(
                        l10n.clearAll,
                        style: const TextStyle(
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Note Type Section
              Text(
                l10n.noteType,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: l10n.typeText,
                    icon: Icons.description,
                    color: const Color(0xFF3B82F6),
                    isSelected: filter.noteTypes.contains(NoteType.text),
                    onTap: () => notesProvider.toggleNoteTypeFilter(NoteType.text),
                  ),
                  _FilterChip(
                    label: l10n.navVoice,
                    icon: Icons.mic,
                    color: const Color(0xFF06B6D4),
                    isSelected: filter.noteTypes.contains(NoteType.voice),
                    onTap: () => notesProvider.toggleNoteTypeFilter(NoteType.voice),
                  ),
                  _FilterChip(
                    label: l10n.typeDrawing,
                    icon: Icons.brush,
                    color: const Color(0xFF8B5CF6),
                    isSelected: filter.noteTypes.contains(NoteType.drawing),
                    onTap: () => notesProvider.toggleNoteTypeFilter(NoteType.drawing),
                  ),
                  _FilterChip(
                    label: l10n.typePhoto,
                    icon: Icons.photo_camera,
                    color: const Color(0xFFEC4899),
                    isSelected: filter.noteTypes.contains(NoteType.photo),
                    onTap: () => notesProvider.toggleNoteTypeFilter(NoteType.photo),
                  ),
                  _FilterChip(
                    label: l10n.typeChecklist,
                    icon: Icons.checklist,
                    color: const Color(0xFFF59E0B),
                    isSelected: filter.noteTypes.contains(NoteType.checklist),
                    onTap: () => notesProvider.toggleNoteTypeFilter(NoteType.checklist),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Status Section
              Text(
                l10n.status,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: l10n.filterPinned,
                    icon: Icons.push_pin,
                    color: Colors.orange,
                    isSelected: filter.isPinned == true,
                    onTap: () => notesProvider.togglePinnedFilter(),
                  ),
                  _FilterChip(
                    label: l10n.filterFavorites,
                    icon: Icons.star,
                    color: Colors.amber,
                    isSelected: filter.isFavorite == true,
                    onTap: () => notesProvider.toggleFavoriteFilter(),
                  ),
                  _FilterChip(
                    label: l10n.filterLocked,
                    icon: Icons.lock,
                    color: Colors.grey,
                    isSelected: filter.isLocked == true,
                    onTap: () => notesProvider.toggleLockedFilter(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sort Section
              Text(
                l10n.sortBy,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: l10n.sortNewest,
                    icon: Icons.arrow_downward,
                    color: AppTheme.primaryPurple,
                    isSelected: filter.sortOrder == SortOrder.newest,
                    onTap: () => notesProvider.setSortOrder(SortOrder.newest),
                  ),
                  _FilterChip(
                    label: l10n.sortOldest,
                    icon: Icons.arrow_upward,
                    color: AppTheme.primaryPurple,
                    isSelected: filter.sortOrder == SortOrder.oldest,
                    onTap: () => notesProvider.setSortOrder(SortOrder.oldest),
                  ),
                  _FilterChip(
                    label: l10n.sortAZ,
                    icon: Icons.sort_by_alpha,
                    color: AppTheme.primaryPurple,
                    isSelected: filter.sortOrder == SortOrder.alphabetical,
                    onTap: () => notesProvider.setSortOrder(SortOrder.alphabetical),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.applyFilters,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : AppTheme.getIconColor(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : AppTheme.getTextSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
