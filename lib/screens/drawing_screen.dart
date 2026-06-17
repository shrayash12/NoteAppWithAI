import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../utils/storage_helper.dart';
import '../utils/file_helper.dart' as file_helper;

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<DrawingPoint?> _points = [];
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _isEraser = false;
  bool _isSaving = false;
  bool _isFullscreen = false;
  String? _selectedFolderId;

  // Folders that users can assign notes to
  static final List<Folder> _assignableFolders = Folder.defaultFolders
      .where((f) => ['work', 'personal', 'ideas'].contains(f.id))
      .toList();

  // Color palette matching the design screenshot
  final List<Color> _colors = [
    const Color(0xFF1A1A1A), // Black
    const Color(0xFFE57373), // Coral/Red
    const Color(0xFF4DB6AC), // Teal
    const Color(0xFF64B5F6), // Blue
    const Color(0xFFFFB74D), // Orange
    const Color(0xFF81C784), // Light green
    const Color(0xFFFFD54F), // Yellow
    const Color(0xFFBA68C8), // Purple/Lavender
    const Color(0xFF90CAF9), // Light blue
    const Color(0xFFFFE082), // Light yellow/gold
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header (hidden in fullscreen)
                if (!_isFullscreen) ...[
                  _buildHeader(),
                  const Divider(height: 1),
                ],
                // Drawing area
                Expanded(
                  child: _isFullscreen ? _buildFullscreenDrawingArea() : _buildDrawingArea(),
                ),
                // Tools (hidden in fullscreen)
                if (!_isFullscreen) _buildToolsSection(),
              ],
            ),
            // Fullscreen toggle button (always visible)
            Positioned(
              top: _isFullscreen ? 16 : null,
              bottom: _isFullscreen ? null : 280,
              right: 16,
              child: GestureDetector(
                onTap: () => setState(() => _isFullscreen = !_isFullscreen),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isFullscreen ? Colors.black.withOpacity(0.7) : const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            // Quick tools in fullscreen mode
            if (_isFullscreen)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildFullscreenQuickTools(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenDrawingArea() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: RepaintBoundary(
        key: _canvasKey,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              painter: DrawingPainter(points: _points),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenQuickTools() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pen
          _buildQuickToolButton(
            icon: Icons.edit,
            isSelected: !_isEraser,
            onTap: () => setState(() => _isEraser = false),
          ),
          // Eraser
          _buildQuickToolButton(
            icon: Icons.auto_fix_high,
            isSelected: _isEraser,
            onTap: () => setState(() => _isEraser = true),
          ),
          // Color indicator
          GestureDetector(
            onTap: _showColorPicker,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _selectedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
          // Clear
          _buildQuickToolButton(
            icon: Icons.delete_outline,
            isSelected: false,
            onTap: _clearCanvas,
          ),
          // Save
          _buildQuickToolButton(
            icon: Icons.check,
            isSelected: false,
            onTap: _isSaving ? null : _saveDrawing,
            color: const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickToolButton({
    required IconData icon,
    required bool isSelected,
    VoidCallback? onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : (color ?? Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Select Color',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _colors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                      _isEraser = false;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _clearCanvas() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Canvas'),
        content: const Text('Are you sure you want to clear the drawing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _points.clear());
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Draw & Sketch',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF8B5CF6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Card header with sparkle icon
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Draw & Sketch',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Canvas area
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: RepaintBoundary(
                key: _canvasKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      painter: DrawingPainter(points: _points),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pen and Eraser buttons
          Row(
            children: [
              Expanded(
                child: _buildToolButton(
                  icon: Icons.edit,
                  label: 'Pen',
                  isSelected: !_isEraser,
                  onTap: () => setState(() => _isEraser = false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToolButton(
                  icon: Icons.auto_fix_high,
                  label: 'Eraser',
                  isSelected: _isEraser,
                  onTap: () => setState(() => _isEraser = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Color label
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Color',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Color palette
          _buildColorPalette(),
          const SizedBox(height: 16),
          // Brush Size
          _buildBrushSizeSlider(),
          const SizedBox(height: 16),
          // Folder selection
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Folder',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFolderChip(
                  name: 'None',
                  icon: Icons.folder_off_outlined,
                  color: Colors.grey,
                  isSelected: _selectedFolderId == null,
                  onTap: () => setState(() => _selectedFolderId = null),
                ),
                ..._assignableFolders.map((folder) => _buildFolderChip(
                  name: folder.name,
                  icon: folder.icon,
                  color: folder.color,
                  isSelected: _selectedFolderId == folder.id,
                  onTap: () => setState(() => _selectedFolderId = folder.id),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Save button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveDrawing,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Save Drawing',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderChip({
    required String name,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _colors.map((color) {
        final isSelected = _selectedColor == color && !_isEraser;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedColor = color;
              _isEraser = false;
            });
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBrushSizeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Brush Size',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '${_strokeWidth.toInt()}px',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF1A1A1A),
            inactiveTrackColor: Colors.grey.shade300,
            thumbColor: const Color(0xFF1A1A1A),
            overlayColor: const Color(0xFF1A1A1A).withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _strokeWidth,
            min: 1,
            max: 20,
            onChanged: (value) {
              setState(() {
                _strokeWidth = value;
              });
            },
          ),
        ),
      ],
    );
  }

  void _onPanStart(DragStartDetails details) {
    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);

    setState(() {
      _points.add(DrawingPoint(
        offset: localPosition,
        paint: Paint()
          ..color = _isEraser ? Colors.white : _selectedColor
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _isEraser ? 20.0 : _strokeWidth
          ..style = PaintingStyle.stroke,
      ));
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);

    setState(() {
      _points.add(DrawingPoint(
        offset: localPosition,
        paint: Paint()
          ..color = _isEraser ? Colors.white : _selectedColor
          ..strokeCap = StrokeCap.round
          ..strokeWidth = _isEraser ? 20.0 : _strokeWidth
          ..style = PaintingStyle.stroke,
      ));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _points.add(null); // Add null to separate strokes
    });
  }

  Future<void> _saveDrawing() async {
    debugPrint('DrawingScreen: _saveDrawing called');
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw something first')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      debugPrint('DrawingScreen: Capturing drawing as image...');
      // Capture the drawing as an image
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not capture drawing');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      debugPrint('DrawingScreen: Image captured, converting to bytes...');
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Could not convert drawing to image');
      }

      final bytes = byteData.buffer.asUint8List();
      debugPrint('DrawingScreen: Got ${bytes.length} bytes');
      final fileName = 'drawing_${DateTime.now().millisecondsSinceEpoch}.png';
      String imagePath;

      // Upload to Firebase Storage on all platforms
      debugPrint('DrawingScreen: Uploading to Firebase Storage...');
      imagePath = await StorageHelper.uploadToFirebase(
        bytes,
        'drawings/$fileName',
        'image/png',
      );
      debugPrint('DrawingScreen: Upload complete! URL: $imagePath');
      if (!kIsWeb) {
        // Also save locally for offline access
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        await file_helper.writeFileBytes(filePath, bytes);
      }

      // Create note
      final now = DateTime.now();
      final note = Note(
        id: const Uuid().v4(),
        title: 'Drawing ${now.day}/${now.month}/${now.year}',
        content: 'Hand-drawn sketch',
        type: NoteType.drawing,
        createdAt: now,
        updatedAt: now,
        imagePath: imagePath,
        folderId: _selectedFolderId,
      );

      // Save note
      if (mounted) {
        final provider = Provider.of<NotesProvider>(context, listen: false);
        await provider.addNote(note);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Drawing saved successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving drawing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({required this.offset, required this.paint});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Draw all points
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current != null && next != null) {
        canvas.drawLine(current.offset, next.offset, current.paint);
      } else if (current != null && next == null) {
        // Draw a dot for single points
        canvas.drawPoints(ui.PointMode.points, [current.offset], current.paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

// Function to show drawing screen
void showDrawingScreen(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const DrawingScreen(),
      fullscreenDialog: true,
    ),
  );
}
