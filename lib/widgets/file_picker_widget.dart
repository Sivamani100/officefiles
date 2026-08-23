import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class FilePickerWidget extends StatelessWidget {
  final Future<void> Function(PlatformFile file) onFilePicked;

  const FilePickerWidget({super.key, required this.onFilePicked});

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: true,
    );
    if (result?.files.first != null) {
      await onFilePicked(result!.files.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.folder_open),
      label: const Text('Open .docx'),
      onPressed: () => _pickFile(context),
    );
  }
}
