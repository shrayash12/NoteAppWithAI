import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/note.dart';
import 'storage_helper.dart';

class ShareHelper {
  /// Share a note. Handles all note types.
  static Future<void> shareNote(BuildContext context, Note note) async {
    switch (note.type) {
      case NoteType.text:
        await _shareText(note);
        break;
      case NoteType.checklist:
        await _shareChecklist(note);
        break;
      case NoteType.voice:
        await _shareVoice(note);
        break;
      case NoteType.photo:
      case NoteType.drawing:
        await _shareImage(note);
        break;
      case NoteType.document:
        await _shareDocument(note);
        break;
    }
  }

  static Future<void> _shareText(Note note) async {
    final buffer = StringBuffer();
    buffer.writeln(note.title);
    if (note.content.isNotEmpty) {
      buffer.writeln();
      buffer.write(note.content);
    }
    await Share.share(buffer.toString(), subject: note.title);
  }

  static Future<void> _shareChecklist(Note note) async {
    final buffer = StringBuffer();
    buffer.writeln(note.title);
    if (note.checklistItems != null && note.checklistItems!.isNotEmpty) {
      buffer.writeln();
      for (final item in note.checklistItems!) {
        final check = item.isChecked ? '☑' : '☐';
        buffer.writeln('$check ${item.text}');
      }
    }
    await Share.share(buffer.toString(), subject: note.title);
  }

  static Future<void> _shareVoice(Note note) async {
    if (note.voicePath == null) {
      await Share.share(note.title, subject: note.title);
      return;
    }
    final file = await _resolveFile(note.voicePath!);
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)], subject: note.title);
    } else {
      await Share.share(note.title, subject: note.title);
    }
  }

  static Future<void> _shareImage(Note note) async {
    if (note.imagePath == null) {
      await Share.share(note.title, subject: note.title);
      return;
    }
    final file = await _resolveFile(note.imagePath!);
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)], subject: note.title);
    } else {
      await Share.share(note.title, subject: note.title);
    }
  }

  static Future<void> _shareDocument(Note note) async {
    if (note.pdfPath == null) {
      await Share.share(note.title, subject: note.title);
      return;
    }
    final file = await _resolveFile(note.pdfPath!);
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)], subject: note.title);
    } else {
      await Share.share(note.title, subject: note.title);
    }
  }

  /// Returns a local File for the given path or URL.
  /// Downloads remote URLs to a temp file first.
  static Future<File?> _resolveFile(String path) async {
    try {
      if (StorageHelper.isUrl(path)) {
        final response = await http.get(Uri.parse(path));
        if (response.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          final ext = path.contains('.') ? path.split('.').last.split('?').first : 'bin';
          final file = File('${dir.path}/share_temp.$ext');
          await file.writeAsBytes(response.bodyBytes);
          return file;
        }
        return null;
      } else {
        final file = File(path);
        return await file.exists() ? file : null;
      }
    } catch (_) {
      return null;
    }
  }
}
