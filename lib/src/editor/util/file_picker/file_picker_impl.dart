import 'dart:typed_data';

import 'package:appflowy_editor/src/editor/util/file_picker/file_picker_service.dart';
import 'package:file_picker/file_picker.dart' as fp;

class FilePicker implements FilePickerService {
  @override
  Future<String?> getDirectoryPath({String? title}) {
    return fp.FilePicker.getDirectoryPath();
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    fp.FileType type = fp.FileType.any,
    List<String>? allowedExtensions,
    Function(fp.FilePickerStatus p1)? onFileLoading,
    bool allowMultiple = false,
    bool lockParentWindow = false,
  }) async {
    if (allowMultiple) {
      final result = await fp.FilePicker.pickFiles(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        onFileLoading: onFileLoading,
        windowsOptions: fp.WindowsOptions(lockParentWindow: lockParentWindow),
        linuxOptions: fp.LinuxOptions(lockParentWindow: lockParentWindow),
      );

      return FilePickerResult(result);
    } else {
      final result = await fp.FilePicker.pickFile(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        onFileLoading: onFileLoading,
        windowsOptions: fp.WindowsOptions(lockParentWindow: lockParentWindow),
        linuxOptions: fp.LinuxOptions(lockParentWindow: lockParentWindow),
      );

      if (result == null) return null;

      return FilePickerResult([result]);
    }
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
    String? initialDirectory,
    fp.FileType type = fp.FileType.any,
    List<String>? allowedExtensions,
    bool lockParentWindow = false,
  }) {
    return fp.FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
      type: type,
      allowedExtensions: allowedExtensions,
      windowsOptions: fp.WindowsOptions(lockParentWindow: lockParentWindow),
      linuxOptions: fp.LinuxOptions(lockParentWindow: lockParentWindow),
    );
  }
}
