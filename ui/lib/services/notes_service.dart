import 'api_service.dart';

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

  static Note fromJson(Map<String, dynamic> j) {
    // Support both API (ISO strings) and legacy local (epoch ints) formats
    int _toEpoch(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      try {
        return DateTime.parse(v as String).millisecondsSinceEpoch;
      } catch (_) {
        return 0;
      }
    }

    return Note(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      createdAt: _toEpoch(j['created_at'] ?? j['createdAt']),
      updatedAt: _toEpoch(j['updated_at'] ?? j['updatedAt']),
    );
  }
}

class NotesService {
  final String tripId;
  final _api = ApiService();

  NotesService({required this.tripId});

  Future<List<Note>> loadNotes() async {
    final data = await _api.get('/notes/$tripId');
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => Note.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Note> createNote({String? title, String? body}) async {
    final data = await _api.post('/notes', body: {
      'tripId': tripId,
      'title': title ?? '',
      'body': body ?? '',
    });
    return Note.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> updateNote(Note note) async {
    await _api.put('/notes/${note.id}', body: {
      'title': note.title,
      'body': note.body,
    });
  }

  Future<void> deleteNote(String id) async {
    await _api.delete('/notes/$id');
  }
}
