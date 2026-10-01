import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'database.dart';
import 'security_service.dart';

class HomePage extends StatelessWidget {
  final VoidCallback onLock;
  const HomePage({super.key, required this.onLock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Manager'),
        actions: [
          IconButton(
            tooltip: 'Lock now',
            onPressed: onLock,
            icon: const Icon(Icons.lock),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Choose a module', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Your secure tools stay separated by purpose.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _ModuleCard(
              icon: Icons.folder_lock_outlined,
              title: 'Document Vault',
              subtitle: 'Store, search, edit, share and back up encrypted documents.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DocumentVaultPage(onLock: onLock)),
              ),
            ),
            const SizedBox(height: 14),
            _ModuleCard(
              icon: Icons.event_available_outlined,
              title: 'Event Management',
              subtitle: 'Event scheduling module — next module to be added.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventManagementPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(radius: 28, child: Icon(icon, size: 30)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class EventManagementPage extends StatelessWidget {
  const EventManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Management')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note, size: 64),
              SizedBox(height: 16),
              Text('Event Management module'),
              SizedBox(height: 8),
              Text(
                'The module entry point is ready. Event scheduling features will be added in the next development step.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DocumentVaultPage extends StatefulWidget {
  final VoidCallback onLock;
  const DocumentVaultPage({super.key, required this.onLock});

  @override
  State<DocumentVaultPage> createState() => _DocumentVaultPageState();
}

class _DocumentVaultPageState extends State<DocumentVaultPage> {
  int index = 0;
  int refreshToken = 0;

  void _changed() => setState(() => refreshToken++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DocumentsPage(key: ValueKey('docs-$refreshToken'), onChanged: _changed),
      AddDocumentPage(key: ValueKey('add-$refreshToken'), onSaved: () {
        _changed();
        setState(() => index = 0);
      }),
      DocumentTypesPage(key: ValueKey('types-$refreshToken'), onChanged: _changed),
      SettingsPage(onDataChanged: _changed, onLock: widget.onLock),
    ];
    final titles = ['Documents', 'Add Document', 'Document Types', 'Settings'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[index]),
        actions: [
          IconButton(
            tooltip: 'Lock now',
            onPressed: widget.onLock,
            icon: const Icon(Icons.lock),
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Documents'),
          NavigationDestination(icon: Icon(Icons.add_photo_alternate_outlined), selectedIcon: Icon(Icons.add_photo_alternate), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: 'Types'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class AddDocumentPage extends StatefulWidget {
  final VoidCallback onSaved;
  const AddDocumentPage({super.key, required this.onSaved});

  @override
  State<AddDocumentPage> createState() => _AddDocumentPageState();
}

class _AddDocumentPageState extends State<AddDocumentPage> {
  final owner = TextEditingController();
  final picker = ImagePicker();
  List<DocumentType> types = [];
  int? selectedType;
  final List<PickedImageData> images = [];
  bool busy = false;
  bool powerSaver = true;

  @override
  void initState() {
    super.initState();
    loadTypes();
    _loadPowerSaver();
  }

  @override
  void dispose() {
    owner.dispose();
    super.dispose();
  }


  Future<void> _loadPowerSaver() async {
    final enabled = await SecurityService.instance.isPowerSaverEnabled();
    if (mounted) setState(() => powerSaver = enabled);
  }

  int get _remainingPictures => 5 - images.length;

  Future<void> loadTypes() async {
    final data = await AppDatabase.instance.getDocumentTypes();
    if (!mounted) return;
    setState(() {
      types = data;
      if (selectedType == null || !data.any((t) => t.id == selectedType)) {
        selectedType = data.isEmpty ? null : data.first.id;
      }
    });
  }

  Future<void> _addFromGallery() async {
    if (_remainingPictures <= 0) {
      _msg('Maximum 5 pictures per document.');
      return;
    }
    try {
      final picked = await picker.pickMultiImage(
        imageQuality: powerSaver ? 68 : 88,
        maxWidth: powerSaver ? 1600 : 2400,
        maxHeight: powerSaver ? 1600 : 2400,
        limit: _remainingPictures,
      );
      if (picked.isEmpty) return;
      final added = <PickedImageData>[];
      for (final file in picked.take(_remainingPictures)) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        added.add(PickedImageData(
          bytes: bytes,
          fileName: file.name,
          mimeType: file.mimeType,
        ));
      }
      if (added.isEmpty) {
        _msg('The selected picture could not be read. Please choose another picture.');
        return;
      }
      if (!mounted) return;
      setState(() => images.addAll(added));
    } on PlatformException catch (e) {
      _msg('Gallery could not be opened: ${e.message ?? e.code}');
    } catch (e) {
      _msg('Could not add picture: ${_cleanError(e)}');
    }
  }

  Future<void> _addFromCamera() async {
    if (_remainingPictures <= 0) {
      _msg('Maximum 5 pictures per document.');
      return;
    }
    try {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: powerSaver ? 68 : 88,
        maxWidth: powerSaver ? 1600 : 2400,
        maxHeight: powerSaver ? 1600 : 2400,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _msg('The captured picture could not be read. Please try again.');
        return;
      }
      if (!mounted) return;
      setState(() => images.add(PickedImageData(
        bytes: bytes,
        fileName: file.name,
        mimeType: file.mimeType,
      )));
    } on PlatformException catch (e) {
      _msg('Camera could not be opened: ${e.message ?? e.code}');
    } catch (e) {
      _msg('Could not add picture: ${_cleanError(e)}');
    }
  }

  Future<void> _chooseImageSource() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _addFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _addFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> save() async {
    if (busy) return;
    if (owner.text.trim().isEmpty || selectedType == null || images.isEmpty || images.length > 5) {
      _msg('Enter owner, choose a document type, and add between 1 and 5 pictures.');
      return;
    }
    final selectedId = selectedType!;
    setState(() => busy = true);
    try {
      if (!await AppDatabase.instance.documentTypeExists(selectedId)) {
        await loadTypes();
        _msg('That document type is no longer available. Please select the type again.');
        return;
      }
      final ref = await AppDatabase.instance.createDocument(
        ownerName: owner.text,
        documentTypeId: selectedId,
        images: List<PickedImageData>.from(images),
      );
      owner.clear();
      images.clear();
      if (mounted) setState(() {});
      _msg('Document saved securely. Reference: $ref');
      widget.onSaved();
    } catch (e) {
      _msg('Save failed: ${_cleanError(e)}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadTypes,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: types.isEmpty ? null : () async {
              final picked = await _pickDocumentType(context, types, selectedType);
              if (picked != null && mounted) setState(() => selectedType = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Document Type',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                _typeName(types, selectedType),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: owner,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Document Owner Name'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy || images.length >= 5 ? null : _chooseImageSource,
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Add Pictures'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('${images.length}/5 pictures selected • Minimum 1 picture required')),
              if (powerSaver) const Chip(avatar: Icon(Icons.battery_saver, size: 16), label: Text('Power saver')),
            ],
          ),
          const SizedBox(height: 12),
          if (images.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: images.length,
              itemBuilder: (_, i) => Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(images[i].bytes, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton.filledTonal(
                      tooltip: 'Remove',
                      onPressed: () => setState(() => images.removeAt(i)),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                  Positioned(
                    left: 5,
                    bottom: 5,
                    child: CircleAvatar(
                      radius: 13,
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : save,
            icon: const Icon(Icons.save),
            label: Text(busy ? 'Saving...' : 'Save Document'),
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pictures are compressed by the picker and stored as BLOB data inside the encrypted SQLCipher database. No document image is intentionally saved as a separate app file.',
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
}

class DocumentTypesPage extends StatefulWidget {
  final VoidCallback onChanged;
  const DocumentTypesPage({super.key, required this.onChanged});

  @override
  State<DocumentTypesPage> createState() => _DocumentTypesPageState();
}

class _DocumentTypesPageState extends State<DocumentTypesPage> {
  final search = TextEditingController();
  List<DocumentType> types = [];
  bool loading = true;

  List<DocumentType> get filteredTypes {
    final q = search.text.trim().toLowerCase();
    if (q.isEmpty) return types;
    return types.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final data = await AppDatabase.instance.getDocumentTypes();
    if (mounted) setState(() { types = data; loading = false; });
  }

  Future<void> edit([DocumentType? type]) async {
    final c = TextEditingController(text: type?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(type == null ? 'Add Document Type' : 'Edit Document Type'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Type name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.isEmpty) return;
    try {
      if (type == null) {
        await AppDatabase.instance.addDocumentType(name);
      } else {
        await AppDatabase.instance.editDocumentType(type.id, name);
      }
      await load();
      widget.onChanged();
    } catch (e) {
      _msg('Could not save document type: ${_cleanError(e)}');
    }
  }

  Future<void> remove(DocumentType type) async {
    if (type.recordCount > 0) {
      _msg('Cannot delete "${type.name}" because ${type.recordCount} document(s) use it.');
      return;
    }
    final yes = await _confirmDialog(
      context,
      'Delete document type?',
      'Delete "${type.name}"? This cannot be undone.',
      action: 'Delete',
    );
    if (!yes) return;
    final ok = await AppDatabase.instance.deleteDocumentType(type.id);
    if (!ok) _msg('Delete blocked because a document now uses this type.');
    await load();
    widget.onChanged();
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Search document types',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty ? null : IconButton(
                  onPressed: () { search.clear(); setState(() {}); },
                  icon: const Icon(Icons.clear),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (filteredTypes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: Text('No matching document types.')),
              )
            else
              ...filteredTypes.map((t) {
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.category)),
                      title: Text(t.name),
                      subtitle: Text('${t.recordCount} saved document(s)'),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(tooltip: 'Edit', onPressed: () => edit(t), icon: const Icon(Icons.edit)),
                          IconButton(
                            tooltip: t.recordCount == 0 ? 'Delete' : 'In use — cannot delete',
                            onPressed: t.recordCount == 0 ? () => remove(t) : null,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
              }),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Type'),
      ),
    );
  }
}

class DocumentsPage extends StatefulWidget {
  final VoidCallback onChanged;
  const DocumentsPage({super.key, required this.onChanged});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final search = TextEditingController();
  List<DocumentListItem> docs = [];
  List<DocumentType> types = [];
  int? typeId;
  bool loading = true;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () => load());
    setState(() {});
  }

  Future<void> load() async {
    final results = await Future.wait([
      AppDatabase.instance.getDocuments(query: search.text, typeId: typeId),
      AppDatabase.instance.getDocumentTypes(),
    ]);
    if (!mounted) return;
    setState(() {
      docs = results[0] as List<DocumentListItem>;
      types = results[1] as List<DocumentType>;
      if (typeId != null && !types.any((t) => t.id == typeId)) typeId = null;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              labelText: 'Search owner, reference or type',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () { search.clear(); load(); },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            initialValue: typeId,
            decoration: const InputDecoration(labelText: 'Filter by type'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All types')),
              ...types.map((t) => DropdownMenuItem<int?>(value: t.id, child: Text(t.name))),
            ],
            onChanged: (v) { setState(() => typeId = v); load(); },
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 70),
              child: Column(
                children: [
                  Icon(Icons.folder_off_outlined, size: 64),
                  SizedBox(height: 12),
                  Text('No matching documents.'),
                ],
              ),
            )
          else
            ...docs.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(d.ownerName),
                  subtitle: Text('${d.documentType} • ${d.imageCount} pictures\n${d.referenceNo}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DocumentDetailPage(documentId: d.id)),
                    );
                    await load();
                    widget.onChanged();
                  },
                ),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class DocumentDetailPage extends StatefulWidget {
  final int documentId;
  const DocumentDetailPage({super.key, required this.documentId});

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentListItem? doc;
  List<StoredImage> images = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final loaded = await AppDatabase.instance.getDocument(widget.documentId);
    if (loaded == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final imgs = await AppDatabase.instance.getImages(widget.documentId);
    if (mounted) setState(() { doc = loaded; images = imgs; loading = false; });
  }

  Future<void> _edit() async {
    if (doc == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditDocumentPage(documentId: widget.documentId)),
    );
    await load();
  }

  Future<void> _delete() async {
    final yes = await _confirmDialog(
      context,
      'Delete document?',
      'Delete this document and all of its stored pictures? This cannot be undone.',
      action: 'Delete',
    );
    if (!yes) return;
    await AppDatabase.instance.deleteDocument(widget.documentId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareStoredImage(StoredImage image, DocumentListItem document) async {
    try {
      final safeName = (image.fileName == null || image.fileName!.trim().isEmpty)
          ? '${document.referenceNo}-picture-${image.order}.jpg'
          : image.fileName!;
      await Share.shareXFiles(
        [XFile.fromData(image.bytes, mimeType: image.mimeType ?? 'image/jpeg', name: safeName)],
        text: '${document.documentType} • ${document.ownerName} • ${document.referenceNo}',
        subject: 'Secure Docs picture',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: ${_cleanError(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading || doc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final d = doc!;
    return Scaffold(
      appBar: AppBar(
        title: Text(d.ownerName),
        actions: [
          IconButton(tooltip: 'Edit', onPressed: _edit, icon: const Icon(Icons.edit)),
          IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.documentType, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  SelectableText(d.referenceNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('${d.imageCount} pictures stored'),
                  Text('Created: ${_friendlyDate(d.createdAt)}'),
                  Text('Updated: ${_friendlyDate(d.updatedAt)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < images.length; i++) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImageViewerPage(images: images, initialIndex: i),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.memory(images[i].bytes, width: double.infinity, fit: BoxFit.fitWidth),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Picture ${images[i].order} • SHA-256 ${images[i].sha256Value.substring(0, 12)}…'),
                          ),
                          IconButton(
                            tooltip: 'Share picture (WhatsApp, Gmail, Drive, etc.)',
                            onPressed: () => _shareStoredImage(images[i], d),
                            icon: const Icon(Icons.share_outlined),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class EditDocumentPage extends StatefulWidget {
  final int documentId;
  const EditDocumentPage({super.key, required this.documentId});

  @override
  State<EditDocumentPage> createState() => _EditDocumentPageState();
}

class _EditDocumentPageState extends State<EditDocumentPage> {
  final owner = TextEditingController();
  final picker = ImagePicker();
  DocumentListItem? doc;
  List<DocumentType> types = [];
  List<StoredImage> images = [];
  int? typeId;
  bool loading = true;
  bool busy = false;
  bool powerSaver = true;

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() { owner.dispose(); super.dispose(); }

  Future<void> load() async {
    powerSaver = await SecurityService.instance.isPowerSaverEnabled();
    final d = await AppDatabase.instance.getDocument(widget.documentId);
    if (d == null) { if (mounted) Navigator.pop(context); return; }
    final results = await Future.wait([
      AppDatabase.instance.getDocumentTypes(),
      AppDatabase.instance.getImages(widget.documentId),
    ]);
    if (!mounted) return;
    setState(() {
      doc = d;
      owner.text = d.ownerName;
      typeId = d.documentTypeId;
      types = results[0] as List<DocumentType>;
      images = results[1] as List<StoredImage>;
      loading = false;
    });
  }

  Future<void> _saveMetadata() async {
    if (owner.text.trim().isEmpty || typeId == null) {
      _msg('Owner and document type are required.');
      return;
    }
    setState(() => busy = true);
    try {
      await AppDatabase.instance.updateDocument(
        id: widget.documentId,
        ownerName: owner.text,
        documentTypeId: typeId!,
      );
      _msg('Document details updated.');
      await load();
    } catch (e) {
      _msg('Update failed: ${_cleanError(e)}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addGallery() async {
    final remaining = 5 - images.length;
    if (remaining <= 0) { _msg('Maximum 5 pictures per document.'); return; }
    try {
      final picked = await picker.pickMultiImage(
        imageQuality: powerSaver ? 68 : 88,
        maxWidth: powerSaver ? 1600 : 2400,
        maxHeight: powerSaver ? 1600 : 2400,
        limit: remaining,
      );
      if (picked.isEmpty) return;
      final add = <PickedImageData>[];
      for (final file in picked.take(remaining)) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        add.add(PickedImageData(bytes: bytes, fileName: file.name, mimeType: file.mimeType));
      }
      if (add.isEmpty) {
        _msg('The selected picture could not be read.');
        return;
      }
      await AppDatabase.instance.addImages(widget.documentId, add);
      await load();
    } on PlatformException catch (e) {
      _msg('Gallery could not be opened: ${e.message ?? e.code}');
    } catch (e) {
      _msg('Could not add picture: ${_cleanError(e)}');
    }
  }

  Future<void> _addCamera() async {
    if (images.length >= 5) { _msg('Maximum 5 pictures per document.'); return; }
    try {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: powerSaver ? 68 : 88,
        maxWidth: powerSaver ? 1600 : 2400,
        maxHeight: powerSaver ? 1600 : 2400,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _msg('The captured picture could not be read.');
        return;
      }
      await AppDatabase.instance.addImages(widget.documentId, [
        PickedImageData(bytes: bytes, fileName: file.name, mimeType: file.mimeType),
      ]);
      await load();
    } on PlatformException catch (e) {
      _msg('Camera could not be opened: ${e.message ?? e.code}');
    } catch (e) {
      _msg('Could not add picture: ${_cleanError(e)}');
    }
  }

  Future<void> _deleteImage(StoredImage img) async {
    final deletingLast = images.length == 1;
    final yes = await _confirmDialog(
      context,
      deletingLast ? 'Delete entire document?' : 'Remove picture?',
      deletingLast
          ? 'This is the last picture. Removing it will delete the complete document record. This cannot be undone.'
          : 'Remove picture ${img.order} from this document?',
      action: deletingLast ? 'Delete Document' : 'Remove',
    );
    if (!yes) return;
    final result = await AppDatabase.instance.deleteImage(img.id, widget.documentId);
    if (result == DeleteImageResult.notFound) {
      _msg('Picture or document could not be found.');
      return;
    }
    if (result == DeleteImageResult.documentDeleted) {
      if (mounted) Navigator.pop(context, true);
      return;
    }
    await load();
  }

  Future<void> _move(StoredImage img, int delta) async {
    await AppDatabase.instance.moveImage(widget.documentId, img.id, delta);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Document')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: types.isEmpty ? null : () async {
              final picked = await _pickDocumentType(context, types, typeId);
              if (picked != null && mounted) setState(() => typeId = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Document Type',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Text(_typeName(types, typeId)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: owner, decoration: const InputDecoration(labelText: 'Document Owner Name')),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : _saveMetadata,
            icon: const Icon(Icons.save),
            label: const Text('Save Details'),
          ),
          const SizedBox(height: 24),
          Text('Pictures (${images.length})', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: images.length >= 5 ? null : _addGallery, icon: const Icon(Icons.photo_library), label: const Text('Gallery'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: images.length >= 5 ? null : _addCamera, icon: const Icon(Icons.camera_alt), label: const Text('Camera'))),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < images.length; i++)
            Card(
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(images[i].bytes, width: 60, height: 60, fit: BoxFit.cover),
                ),
                title: Text('Picture ${i + 1}'),
                subtitle: Text(images[i].sha256Value.substring(0, 16)),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(tooltip: 'Move up', onPressed: i == 0 ? null : () => _move(images[i], -1), icon: const Icon(Icons.arrow_upward)),
                    IconButton(tooltip: 'Move down', onPressed: i == images.length - 1 ? null : () => _move(images[i], 1), icon: const Icon(Icons.arrow_downward)),
                    IconButton(
                      tooltip: 'Share picture',
                      onPressed: () async {
                        final d = doc;
                        if (d == null) return;
                        try {
                          final image = images[i];
                          final safeName = (image.fileName == null || image.fileName!.trim().isEmpty)
                              ? '${d.referenceNo}-picture-${image.order}.jpg'
                              : image.fileName!;
                          await Share.shareXFiles(
                            [XFile.fromData(image.bytes, mimeType: image.mimeType ?? 'image/jpeg', name: safeName)],
                            text: '${d.documentType} • ${d.ownerName} • ${d.referenceNo}',
                          );
                        } catch (e) {
                          _msg('Share failed: ${_cleanError(e)}');
                        }
                      },
                      icon: const Icon(Icons.share_outlined),
                    ),
                    IconButton(tooltip: 'Remove', onPressed: () => _deleteImage(images[i]), icon: const Icon(Icons.delete_outline)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
}

class ImageViewerPage extends StatefulWidget {
  final List<StoredImage> images;
  final int initialIndex;
  const ImageViewerPage({super.key, required this.images, required this.initialIndex});

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController controller = PageController(initialPage: widget.initialIndex);
  late int index = widget.initialIndex;

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Picture ${index + 1} of ${widget.images.length}'),
        actions: [
          IconButton(
            tooltip: 'Share picture',
            onPressed: () async {
              final image = widget.images[index];
              try {
                await Share.shareXFiles([
                  XFile.fromData(
                    image.bytes,
                    mimeType: image.mimeType ?? 'image/jpeg',
                    name: image.fileName ?? 'secure-doc-picture-${image.order}.jpg',
                  ),
                ]);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Share failed: ${_cleanError(e)}')),
                );
              }
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: widget.images.length,
        onPageChanged: (v) => setState(() => index = v),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(child: Image.memory(widget.images[i].bytes, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final VoidCallback onDataChanged;
  final VoidCallback onLock;
  const SettingsPage({super.key, required this.onDataChanged, required this.onLock});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool biometric = false;
  bool biometricAvailable = false;
  bool powerSaver = true;
  DatabaseStats? stats;
  bool busy = false;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final sec = SecurityService.instance;
    final results = await Future.wait([
      sec.isBiometricEnabled(),
      sec.canUseBiometrics(),
      AppDatabase.instance.getStats(),
      sec.isPowerSaverEnabled(),
    ]);
    if (!mounted) return;
    setState(() {
      biometric = results[0] as bool;
      biometricAvailable = results[1] as bool;
      stats = results[2] as DatabaseStats;
      powerSaver = results[3] as bool;
    });
  }


  Future<void> _togglePowerSaver(bool value) async {
    await SecurityService.instance.setPowerSaverEnabled(value);
    if (mounted) setState(() => powerSaver = value);
    widget.onDataChanged();
    _msg(value
        ? 'Power saver enabled. New pictures use reduced processing and memory.'
        : 'Power saver disabled. New pictures use higher image quality.');
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final ok = await LocalBiometricPrompt.verify();
      if (!ok) { _msg('Biometric verification was not completed.'); return; }
    }
    await SecurityService.instance.setBiometricEnabled(value);
    if (mounted) setState(() => biometric = value);
  }

  Future<void> _changePin() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change PIN / Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Current PIN / Password')),
              const SizedBox(height: 10),
              TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New PIN / Password')),
              const SizedBox(height: 10),
              TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new PIN / Password')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Change')),
        ],
      ),
    );
    if (ok != true) { current.dispose(); next.dispose(); confirm.dispose(); return; }
    if (next.text != confirm.text) {
      _msg('New PIN/password entries do not match.');
    } else {
      try {
        await SecurityService.instance.changePin(current.text, next.text);
        _msg('PIN/password changed successfully.');
      } catch (e) {
        _msg(_cleanError(e));
      }
    }
    current.dispose(); next.dispose(); confirm.dispose();
  }

  Future<String?> _requestBackupPassword({required bool confirm}) async {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(confirm ? 'Create Backup Password' : 'Backup Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: p1, obscureText: true, decoration: const InputDecoration(labelText: 'Backup password')),
            if (confirm) ...[
              const SizedBox(height: 10),
              TextField(controller: p2, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm backup password')),
            ],
            const SizedBox(height: 10),
            const Text('Use at least 8 characters. Keep this password safe; the backup cannot be restored without it.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (p1.text.length < 8) { _msg('Backup password must be at least 8 characters.'); return; }
              if (confirm && p1.text != p2.text) { _msg('Backup passwords do not match.'); return; }
              Navigator.pop(context, p1.text);
            },
            child: Text(confirm ? 'Create Backup' : 'Continue'),
          ),
        ],
      ),
    );
    p1.dispose(); p2.dispose();
    return result;
  }

  Future<void> _backup() async {
    final password = await _requestBackupPassword(confirm: true);
    if (password == null) return;
    setState(() => busy = true);
    try {
      final file = await AppDatabase.instance.createEncryptedBackup(password);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Secure Docs encrypted backup. Save this file to Gmail, Google Drive, OneDrive, Dropbox, or another trusted location. Keep the backup password separately.',
      );
      _msg('Encrypted backup created. Choose Gmail, Drive, or another app in the share sheet.');
    } catch (e) {
      _msg('Backup failed: ${_cleanError(e)}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sdbak'],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    final password = await _requestBackupPassword(confirm: false);
    if (password == null || !mounted) return;
    final yes = await _confirmDialog(
      context,
      'Restore backup?',
      'Current documents will be replaced by the selected encrypted backup. A temporary safety copy is kept until restore validation succeeds.',
      action: 'Restore',
    );
    if (!yes) return;
    setState(() => busy = true);
    try {
      await AppDatabase.instance.restoreEncryptedBackup(path, password);
      await load();
      widget.onDataChanged();
      _msg('Backup restored successfully.');
    } catch (e) {
      _msg('Restore failed. The selected password/file may be wrong: ${_cleanError(e)}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _msg(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Secure Vault', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (s != null) ...[
                  Text('${s.documents} documents'),
                  Text('${s.images} stored pictures'),
                  Text('${s.types} document types'),
                  Text('Encrypted database size: ${_formatBytes(s.bytes)}'),
                ] else
                  const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.battery_saver),
                title: const Text('Power saver'),
                subtitle: const Text('Reduces image size/processing and avoids unnecessary database searches while typing.'),
                value: powerSaver,
                onChanged: busy ? null : _togglePowerSaver,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Biometric unlock'),
                subtitle: Text(biometricAvailable ? 'Use fingerprint/biometrics after app PIN setup.' : 'Biometrics are not available on this device.'),
                value: biometric && biometricAvailable,
                onChanged: biometricAvailable && !busy ? _toggleBiometric : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Change PIN / Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy ? null : _changePin,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Lock now'),
                onTap: widget.onLock,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Create encrypted backup'),
                subtitle: const Text('Creates an encrypted .sdbak file and opens Android Share so you can save it to Gmail, Google Drive, OneDrive, Dropbox, Files, or another installed app.'),
                onTap: busy ? null : _backup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Restore encrypted backup'),
                subtitle: const Text('Replaces current vault after password verification.'),
                onTap: busy ? null : _restore,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacy & Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('• No application backend or cloud account is required.'),
                Text('• SQLCipher encrypts the local SQLite database at rest.'),
                Text('• Photos are stored as database BLOBs.'),
                Text('• App PIN/password verification uses PBKDF2-HMAC-SHA256.'),
                Text('• The database key is stored with platform secure storage.'),
                Text('• The app relocks after returning from background.'),
                Text('• Backup files are additionally encrypted with AES-256-GCM using your backup password.'),
              ],
            ),
          ),
        ),
        if (busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 30),
      ],
    );
  }
}


String _typeName(List<DocumentType> types, int? id) {
  for (final type in types) {
    if (type.id == id) return type.name;
  }
  return 'Search and choose type';
}

Future<int?> _pickDocumentType(
  BuildContext context,
  List<DocumentType> types,
  int? selectedId,
) async {
  final search = TextEditingController();
  final result = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final q = search.text.trim().toLowerCase();
        final filtered = q.isEmpty
            ? types
            : types.where((t) => t.name.toLowerCase().contains(q)).toList();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.68,
              child: Column(
                children: [
                  Text('Choose Document Type', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: search,
                    autofocus: true,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search document type',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: search.text.isEmpty ? null : IconButton(
                        onPressed: () { search.clear(); setSheetState(() {}); },
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No matching document type.'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final t = filtered[i];
                              return Card(
                                child: ListTile(
                                  leading: Icon(t.id == selectedId ? Icons.check_circle : Icons.category_outlined),
                                  title: Text(t.name),
                                  subtitle: Text('${t.recordCount} saved document(s)'),
                                  onTap: () => Navigator.pop(sheetContext, t.id),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  search.dispose();
  return result;
}

class LocalBiometricPrompt {
  static Future<bool> verify() async {
    // Temporarily enable the setting so SecurityService can reuse its hardened
    // biometric authentication path, then restore the original flag.
    final security = SecurityService.instance;
    final old = await security.isBiometricEnabled();
    try {
      await security.setBiometricEnabled(true);
      return await security.authenticateBiometric();
    } finally {
      await security.setBiometricEnabled(old);
    }
  }
}

Future<bool> _confirmDialog(
  BuildContext context,
  String title,
  String body, {
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}


String _cleanError(Object error) => error
    .toString()
    .replaceFirst('Invalid argument(s): ', '')
    .replaceFirst('Bad state: ', '')
    .replaceFirst('FormatException: ', '');

String _friendlyDate(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  final h = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$day-$m-$y $h:$min';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}
