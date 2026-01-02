import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/editor_provider.dart';
import '../services/file_service.dart';
import '../models/file_system_item.dart';
import 'editor/editor_screen.dart';
import 'widgets/document_name_dialog.dart';
import 'widgets/document_tool_card.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      body: SafeArea(
        child: FutureBuilder<List<FileSystemItem>>(
          future: FileService.listFileSystemItems(parentId: _currentFolderId),
          builder: (context, snapshot) {
            // Handle loading/error states cleanly in UI or just show empty/loading indicators
            final items = snapshot.data ?? [];

            return CustomScrollView(
              slivers: [
                // 1. Top Section: Search Bar & Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        // Search Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: Colors.grey[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Search for documents',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Icon(Icons.more_vert,
                                  color: Colors.grey[700]), // Menu dots
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // "Document tools" Header
                        const Text(
                          'Document tools',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tools ScrollView
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              DocumentToolCard(
                                title: 'convert documents',
                                icon: Icons.description_outlined,
                                color: const Color(0xFF2E7D32), // Dark Green
                                iconColor: Colors.white,
                                backgroundColor:
                                    const Color(0xFFE8F5E9), // Light Green
                                onTap: () {}, // TODO: Implement
                              ),
                              DocumentToolCard(
                                title: 'use other documents type',
                                icon: Icons.translate, // Placeholder icon
                                color: const Color(0xFF1565C0), // Dark Blue
                                iconColor: Colors.white,
                                backgroundColor:
                                    const Color(0xFFE3F2FD), // Light Blue
                                onTap: () {},
                              ),
                              DocumentToolCard(
                                title: 'convert image to pdf',
                                icon: Icons.share, // Placeholder
                                color: const Color(0xFFC62828), // Dark Red
                                iconColor: Colors.white,
                                backgroundColor:
                                    const Color(0xFFFFEBEE), // Light Red
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // "notes" Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'notes',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Filter',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.filter_list,
                                    size: 18, color: Colors.grey[600]),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // 2. Breadcrumbs (if not root)
                if (_currentFolderId != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: _buildBreadcrumbs(),
                    ),
                  ),

                // 3. Document List (SliverList)
                if (items.isEmpty &&
                    snapshot.connectionState != ConnectionState.waiting)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.folder_open,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('No documents found',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
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
                  ),

                // Extra padding at bottom for FAB
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            // Handle navigation logic if needed (e.g., reset folder for "All documents")
            if (index == 1) {
              // Usually "All Documents" or "Files" might mean Root or Tree view
              // For now just UI switching
            }
          });
        },
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open),
            label: 'All documents',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptions(context),
        backgroundColor: const Color(0xFFFF9800), // Orange
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.edit, size: 28),
      ),
    );
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
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditorScreen()),
        );
      }
    }
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add, color: Colors.orange),
              title: const Text('New Document'),
              onTap: () {
                Navigator.pop(context);
                _createNewDocument(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder, color: Colors.blue),
              title: const Text('New Folder'),
              onTap: () {
                Navigator.pop(context);
                _createNewFolder(context);
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
          .push(MaterialPageRoute(builder: (_) => const EditorScreen()));
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
