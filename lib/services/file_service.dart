import 'package:file_picker/file_picker.dart';
import 'package:secure_lan_messenger/services/chat_service.dart';

class FileService {
  final ChatService chatService;

  FileService({required this.chatService});

  Future<void> pickAndSendFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final pickedFile = result.files.single;

    if (pickedFile.path == null) {
      throw Exception('Percorso file non disponibile');
    }

    await chatService.sendFile(
      filePath: pickedFile.path!,
      fileName: pickedFile.name,
    );
  }
}
