import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Note {
  final String id;
  String title;
  String body;
  final int createdAt;
  int updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static Note fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        createdAt: j['createdAt'] as int? ?? 0,
        updatedAt: j['updatedAt'] as int? ?? 0,
      );
}

class NotesService {
  static const _key = 'user_notes';

  Future<List<Note>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((e) => Note.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(notes.map((n) => n.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<Note> createNote({String? title, String? body}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final note = Note(
      id: now.toString(),
      title: title ?? '',
      body: body ?? '',
      createdAt: now,
      updatedAt: now,
    );
    final notes = await loadNotes();
    notes.insert(0, note);
    await saveNotes(notes);
    return note;
  }

  Future<void> updateNote(Note note) async {
    final notes = await loadNotes();
    final idx = notes.indexWhere((n) => n.id == note.id);
    if (idx >= 0) {
      note.updatedAt = DateTime.now().millisecondsSinceEpoch;
      notes[idx] = note;
      await saveNotes(notes);
    }
  }

  Future<void> deleteNote(String id) async {
    final notes = await loadNotes();
    notes.removeWhere((n) => n.id == id);
    await saveNotes(notes);
  }
}
