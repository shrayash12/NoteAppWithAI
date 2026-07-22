import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../l10n/app_localizations.dart';


class GradientHeader extends StatefulWidget {
  final String title;
  final String? subtitle;
  final SearchBarWidget? searchBar;
  final double height;
  final bool isGridView;
  final VoidCallback? onViewToggle;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilters;
  final bool showFilter;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.searchBar,
    this.height = 180,
    this.isGridView = false,
    this.onViewToggle,
    this.onFilterTap,
    this.hasActiveFilters = false,
    this.showFilter = true,
  });

  @override
  State<GradientHeader> createState() => _GradientHeaderState();
}

class _GradientHeaderState extends State<GradientHeader> {
  bool _showSearch = false;

  void _closeSearch() {
    setState(() => _showSearch = false);
    context.read<NotesProvider>().clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final colorIndex = context.watch<NotesProvider>().themeColorIndex;
    final gradientColors = AppTheme.accentGradient(colorIndex);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientColors[0], gradientColors[1]],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_showSearch && widget.searchBar != null)
            Expanded(
              child: SearchBarWidget(
                hintText: widget.searchBar!.hintText,
                onChanged: widget.searchBar!.onChanged,
                onNoteSelected: widget.searchBar!.onNoteSelected,
                autofocus: true,
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          Row(
            children: [
              if (widget.searchBar != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (_showSearch) {
                      _closeSearch();
                    } else {
                      setState(() => _showSearch = true);
                    }
                  },
                  icon: Icon(
                    _showSearch ? Icons.close : Icons.search,
                    color: Colors.white,
                  ),
                ),
              if (!_showSearch) ...[
                if (widget.onViewToggle != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    onPressed: widget.onViewToggle,
                    icon: Icon(
                      widget.isGridView ? Icons.view_list : Icons.grid_view,
                      color: Colors.white,
                    ),
                  ),
                if (widget.showFilter)
                  Stack(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: widget.onFilterTap,
                        icon: const Icon(
                          Icons.filter_list,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.hasActiveFilters)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class SearchBarWidget extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final Function(Note)? onNoteSelected;
  final bool autofocus;

  const SearchBarWidget({
    super.key,
    this.hintText = '',
    this.onChanged,
    this.onNoteSelected,
    this.autofocus = false,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Note> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _showSuggestions = false;
  }

  void _updateSuggestions(String query) {
    final notesProvider = context.read<NotesProvider>();
    setState(() {
      _suggestions = notesProvider.searchNotes(query);
      _showSuggestions = query.isNotEmpty && _suggestions.isNotEmpty;
    });

    if (_showSuggestions) {
      _showOverlay();
    } else {
      _removeOverlay();
    }

    widget.onChanged?.call(query);
    notesProvider.setSearchQuery(query);
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 40,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _suggestions.length > 5 ? 5 : _suggestions.length,
                itemBuilder: (context, index) {
                  final note = _suggestions[index];
                  return _SuggestionItem(
                    note: note,
                    searchQuery: _controller.text,
                    onTap: () {
                      _controller.clear();
                      _removeOverlay();
                      _focusNode.unfocus();
                      context.read<NotesProvider>().clearSearch();
                      widget.onNoteSelected?.call(note);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _clearSearch() {
    _controller.clear();
    _removeOverlay();
    context.read<NotesProvider>().clearSearch();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                onChanged: _updateSuggestions,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText.isNotEmpty ? widget.hintText : AppLocalizations.of(context).searchNotes,
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              GestureDetector(
                onTap: _clearSearch,
                child: Icon(
                  Icons.close,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionItem extends StatelessWidget {
  final Note note;
  final String searchQuery;
  final VoidCallback onTap;

  const _SuggestionItem({
    required this.note,
    required this.searchQuery,
    required this.onTap,
  });

  IconData _getNoteTypeIcon() {
    switch (note.type) {
      case NoteType.text:
        return Icons.description;
      case NoteType.voice:
        return Icons.mic;
      case NoteType.drawing:
        return Icons.brush;
      case NoteType.photo:
        return Icons.photo_camera;
      case NoteType.checklist:
        return Icons.checklist;
      case NoteType.document:
        return Icons.picture_as_pdf;
    }
  }

  Color _getNoteTypeColor() {
    switch (note.type) {
      case NoteType.text:
        return const Color(0xFF3B82F6);
      case NoteType.voice:
        return const Color(0xFF06B6D4);
      case NoteType.drawing:
        return const Color(0xFF8B5CF6);
      case NoteType.photo:
        return const Color(0xFFEC4899);
      case NoteType.checklist:
        return const Color(0xFFF59E0B);
      case NoteType.document:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = note.title.isNotEmpty ? note.title : AppLocalizations.of(context).untitled;
    final content = note.content;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getNoteTypeColor().withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getNoteTypeIcon(),
                color: _getNoteTypeColor(),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightedText(
                    text: title,
                    query: searchQuery,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _HighlightedText(
                      text: content,
                      query: searchQuery,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.north_west,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final startIndex = lowerText.indexOf(lowerQuery);

    if (startIndex == -1) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final endIndex = startIndex + query.length;
    final beforeMatch = text.substring(0, startIndex);
    final match = text.substring(startIndex, endIndex);
    final afterMatch = text.substring(endIndex);

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: beforeMatch),
          TextSpan(
            text: match,
            style: style.copyWith(
              backgroundColor: Colors.yellow.shade200,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: afterMatch),
        ],
      ),
    );
  }
}
