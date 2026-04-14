import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:triplan_ai_front/common/constants/app_constants.dart';

import '../../services/notes_service.dart';
import '../../shared/widgets/snackbar_helper.dart';

class NotesPage extends StatefulWidget {
  final String tripId;
  final bool isReadOnly;
  final String? readOnlyMessage;

  const NotesPage({
    super.key,
    required this.tripId,
    this.isReadOnly = false,
    this.readOnlyMessage,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final NotesService _service = NotesService(tripId: widget.tripId);
  List<Note> _notes = [];
  bool _loading = true;

  void _showReadOnlyFeedback() {
    final customMessage = widget.readOnlyMessage?.trim() ?? '';
    final message = customMessage.isNotEmpty
        ? customMessage
        : 'offline.read_only_mode'.tr();
    SnackBarHelper.showWarning(context, message);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await _service.loadNotes();
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _create() async {
    if (widget.isReadOnly) {
      _showReadOnlyFeedback();
      return;
    }

    final note = await _service.createNote(title: '', body: '');
    if (note == null) return;
    await _edit(note);
    await _load();
  }

  Future<void> _edit(Note note) async {
    if (widget.isReadOnly) {
      _showReadOnlyFeedback();
      return;
    }

    final edited = await Navigator.push<Note?>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorPage(note: note)),
    );
    if (edited != null) {
      await _service.updateNote(edited);
      await _load();
    }
  }

  Future<void> _delete(String id) async {
    if (widget.isReadOnly) {
      _showReadOnlyFeedback();
      return;
    }

    await _service.deleteNote(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.notesTitle.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _create,
            tooltip: AppConstants.notesNewNote.tr(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.note_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(AppConstants.notesNoNotes.tr()),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _create,
                    child: Text(AppConstants.notesCreateOne.tr()),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = _notes[index];
                final subtitle = n.body.isNotEmpty
                    ? (n.body.length > 80
                          ? n.body.substring(0, 80) + '…'
                          : n.body)
                    : AppConstants.notesNotePlaceholder.tr();
                return ListTile(
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  title: Text(
                    n.title.isNotEmpty
                        ? n.title
                        : AppConstants.notesUntitled.tr(),
                  ),
                  subtitle: Text(subtitle),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') await _edit(n);
                      if (v == 'delete') await _delete(n.id);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(AppConstants.edit.tr()),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(AppConstants.delete.tr()),
                      ),
                    ],
                  ),
                  onTap: () => _edit(n),
                  leading: const Icon(Icons.note),
                );
              },
            ),
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  final Note note;
  const NoteEditorPage({super.key, required this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _bodyCtrl = TextEditingController(text: widget.note.body);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = Note(
      id: widget.note.id,
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text,
      createdAt: widget.note.createdAt,
      updatedAt: now,
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.note.title.isEmpty
              ? AppConstants.notesNewNote.tr()
              : widget.note.title,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: AppConstants.notesSave.tr(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: AppConstants.notesUntitled.tr(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _bodyCtrl,
                decoration: InputDecoration(
                  hintText: AppConstants.notesNotePlaceholder.tr(),
                ),
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
