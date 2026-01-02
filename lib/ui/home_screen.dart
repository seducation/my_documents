import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/editor_provider.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import '../models/file_system_item.dart';
import 'editor/editor_screen.dart';
import 'widgets/document_name_dialog.dart';
import 'widgets/document_tool_card.dart';
import 'widgets/responsive_layout.dart';
import '../services/share_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _currentFolderId;
  List<FileSystemItem> _breadcrumbs = [];
  int _selectedIndex = 0; // For BottomNavigationBar

  @override
  void initState() {
    super.initState();
    // Initialize PDF sharing listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShareService().init(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildTabletLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _buildMainContent(isMobile: true)),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          _buildSidebar(),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: SafeArea(child: _buildMainContent(isMobile: false))),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildSidebar() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        if (index == 1) {
          _pickAndConvertPdf();
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: Colors.black),
      unselectedIconTheme: const IconThemeData(color: Colors.grey),
      selectedLabelTextStyle:
          const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: const TextStyle(color: Colors.grey),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.folder_open_outlined),
          selectedIcon: Icon(Icons.folder_open),
          label: Text('Import PDF'),
        ),
      ],
    );
  }

  Widget _buildMainContent({required bool isMobile}) {
    return FutureBuilder<List<FileSystemItem>>(
      future: FileService.listFileSystemItems(parentId: _currentFolderId),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(isMobile)),
            if (_currentFolderId != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildBreadcrumbs(),
                ),
              ),
            if (items.isEmpty &&
                snapshot.connectionState != ConnectionState.waiting)
              _buildEmptyState()
            else
              isMobile ? _buildListView(items) : _buildGridView(items),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildSearchBar(),
          const SizedBox(height: 24),
          const Text(
            'Document tools',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87),
          ),
          const SizedBox(height: 16),
          _buildToolCards(),
          const SizedBox(height: 32),
          _buildNotesTitle(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 50,
      decoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: BorderRadius.circular(25)),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Search for documents',
                style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ),
          Icon(Icons.more_vert, color: Colors.grey[700]),
        ],
      ),
    );
  }

  Widget _buildToolCards() {
    return SizedBox(
      height: 110,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            DocumentToolCard(
              title: 'convert documents',
              icon: Icons.description_outlined,
              color: const Color(0xFF2E7D32),
              iconColor: Colors.white,
              backgroundColor: const Color(0xFFE8F5E9),
              onTap: () => _showConversionOptions(context),
            ),
            DocumentToolCard(
              title: 'use other documents type',
              icon: Icons.translate,
              color: const Color(0xFF1565C0),
              iconColor: Colors.white,
              backgroundColor: const Color(0xFFE3F2FD),
              onTap: () {},
            ),
            DocumentToolCard(
              title: 'convert image to pdf',
              icon: Icons.share,
              color: const Color(0xFFC62828),
              iconColor: Colors.white,
              backgroundColor: const Color(0xFFFFEBEE),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'notes',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.5),
        ),
        Row(
          children: [
            Text('Filter',
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(width: 4),
            Icon(Icons.filter_list, size: 18, color: Colors.grey[600]),
          ],
        )
      ],
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('No documents found',
                  style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<FileSystemItem> items) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          return FileSystemItemWidget(
            item: item,
            onTap: () => _handleItemTap(item),
            onDelete: () => _deleteItem(item),
            onRename: () => _renameItem(item),
          );
        },
        childCount: items.length,
      ),
    );
  }

  Widget _buildGridView(List<FileSystemItem> items) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: InkWell(
                onTap: () => _handleItemTap(item),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _buildItemIcon(item, isGrid: true),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        DateFormat('d MMM y').format(item.lastModified),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildItemIcon(FileSystemItem item, {bool isGrid = false}) {
    final isFolder = item.type == FileSystemItemType.folder;
    return Container(
      width: isGrid ? double.infinity : 50,
      height: isGrid ? double.infinity : 60,
      decoration: BoxDecoration(
        color: isFolder ? Colors.amber[100] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: isFolder
          ? const Center(
              child: Icon(Icons.folder, color: Colors.orange, size: 30))
          : (item.name.toLowerCase().contains("pdf")
              ? const Center(
                  child:
                      Icon(Icons.picture_as_pdf, color: Colors.red, size: 30))
              : const Center(
                  child:
                      Icon(Icons.description, color: Colors.blue, size: 30))),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () => _showCreateOptions(context),
      backgroundColor: const Color(0xFFFF9800),
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(Icons.edit, size: 28),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) async {
        if (index == 1) {
          _pickAndConvertPdf();
        } else {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.folder_open), label: 'All documents'),
      ],
    );
  }

  Future<void> _pickAndConvertPdf({String? parentId}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final newDoc = await PdfService.convertPdfToNoteDocument(file, fileName,
            parentId: parentId);
        await FileService.saveDocument(newDoc);

        if (!mounted) return;
        Navigator.pop(context);

        final editorProvider = context.read<EditorProvider>();
        editorProvider.setActiveDocument(newDoc);

        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EditorScreen()))
            .then((_) {
          if (mounted) setState(() {});
        });
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error converting PDF: $e')));
      }
    }
  }

  // --- Helpers & Logic ---

  Widget _buildBreadcrumbs() {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _breadcrumbs.length + 1,
        separatorBuilder: (context, index) =>
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        itemBuilder: (context, index) {
          if (index == 0) {
            return InkWell(
              onTap: () => _navigateToFolder(null),
              child: const Icon(Icons.home, color: Colors.grey, size: 20),
            );
          }
          final folder = _breadcrumbs[index - 1];
          return InkWell(
            onTap: () => _navigateToFolder(folder),
            child: Text(
              folder.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          );
        },
      ),
    );
  }

  void _navigateToFolder(FileSystemItem? folder) {
    setState(() {
      if (folder == null) {
        _currentFolderId = null;
        _breadcrumbs.clear();
      } else {
        final index = _breadcrumbs.indexOf(folder);
        if (index != -1) {
          _breadcrumbs = _breadcrumbs.sublist(0, index + 1);
        } else {
          _breadcrumbs.add(folder);
        }
        _currentFolderId = folder.id;
      }
    });
  }

  Future<void> _handleItemTap(FileSystemItem item) async {
    if (item.type == FileSystemItemType.folder) {
      _navigateToFolder(item);
    } else {
      final editorProvider = context.read<EditorProvider>();
      await editorProvider.loadDocument(item.id);
      if (mounted) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EditorScreen()))
            .then((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _showConversionOptions(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Convert Documents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Image to PDF'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: true,
                );
                if (result != null && parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Conversion of ${result.files.length} images to PDF simulated.')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Text to PDF'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['txt'],
                );
                if (result != null && parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                        content: Text('Text to PDF conversion simulated.')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.compare_arrows, color: Colors.green),
              title: const Text('Other Formats (Coming Soon)'),
              onTap: () {
                Navigator.pop(sheetContext);
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                        content: Text('More conversion options coming soon!')),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCreateOptions(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add, color: Colors.orange),
              title: const Text('New Document'),
              onTap: () {
                Navigator.pop(sheetContext);
                _createNewDocument(parentContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Import PDF'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndConvertPdf(parentId: _currentFolderId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder, color: Colors.blue),
              title: const Text('New Folder'),
              onTap: () {
                Navigator.pop(sheetContext);
                _createNewFolder(parentContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNewFolder(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const DocumentNameDialog(
          title: 'New Folder Name', label: 'Folder Name'),
    );
    if (name == null || name.isEmpty) return;
    await FileService.createFolder(name, _currentFolderId);
    setState(() {});
  }

  Future<void> _createNewDocument(BuildContext context) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => const DocumentNameDialog(
          title: 'New Document Name', label: 'Document Name'),
    );
    if (title == null || !context.mounted) return;
    final editorProvider = context.read<EditorProvider>();
    editorProvider.createNewDocumentWithTitle(title,
        parentId: _currentFolderId);
    if (context.mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const EditorScreen()))
          .then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _renameItem(FileSystemItem item) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => DocumentNameDialog(
          title: 'Rename', label: 'New Name', initialValue: item.name),
    );
    if (newName == null || newName.isEmpty) return;
    await FileService.renameItem(item.id, newName);
    setState(() {});
  }

  Future<void> _deleteItem(FileSystemItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${item.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      if (item.type == FileSystemItemType.folder) {
        await FileService.deleteFolder(item.id, recursive: true);
      } else {
        await FileService.deleteDocument(item.id);
      }
      setState(() {});
    }
  }
}

class FileSystemItemWidget extends StatelessWidget {
  final FileSystemItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const FileSystemItemWidget({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final isFolder = item.type == FileSystemItemType.folder;
    final dateStr = DateFormat('d MMM y').format(item.lastModified);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            // Thumbnail / Icon
            Container(
              width: 50,
              height: 60,
              decoration: BoxDecoration(
                color: isFolder ? Colors.amber[100] : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                image: !isFolder && item.name.endsWith('.pdf')
                    ? const DecorationImage(
                        image: AssetImage('assets/pdf_placeholder.png'),
                        fit: BoxFit.cover)
                    : null, // Mockup logic
              ),
              child: isFolder
                  ? const Center(
                      child: Icon(Icons.folder, color: Colors.orange, size: 30))
                  : (item.name.toLowerCase().contains("pdf")
                      ? const Center(
                          child: Icon(Icons.picture_as_pdf,
                              color: Colors.red, size: 30))
                      : const Center(
                          child: Icon(Icons.description,
                              color: Colors.blue, size: 30))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              onPressed: () {
                // Show standard modal or popup
                showModalBottomSheet(
                    context: context,
                    builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('Rename'),
                              onTap: () {
                                Navigator.pop(context);
                                onRename();
                              },
                            ),
                            ListTile(
                              leading:
                                  const Icon(Icons.delete, color: Colors.red),
                              title: const Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                              onTap: () {
                                Navigator.pop(context);
                                onDelete();
                              },
                            ),
                          ],
                        ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
