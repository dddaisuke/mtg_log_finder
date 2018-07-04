import 'dart:html';
import 'package:googleapis/drive/v3.dart' as drive;

class MtgFile {
  drive.File driveFile;
  bool isHidden;
  String icon;
  String timestamp;
  String originalTitle;
  String title;
  bool isFolder;

  MtgFile(drive.File _file, bool _isHidden, String _icon) {
    driveFile = _file;
    icon = _icon;
    isHidden = _isHidden;
    originalTitle = _file.name.toString();
    isFolder = (_file.mimeType == 'application/vnd.google-apps.folder');

    bool isMatch = new RegExp(r"^\d{8}").hasMatch(originalTitle);
    if (isMatch) {
      timestamp = originalTitle.substring(0, 8);
      title = originalTitle.substring(8);
    } else if (isFolder) {
      // 不正なタイトルでも許容する
      timestamp = null;
      title = null;
    } else {
      DivElement divError = querySelector('#error');
      divError.appendHtml("「" + originalTitle + "」が不正なタイトルです。");
      divError.append(new BRElement());
      timestamp = null;
      title = null;
    }
  }
}
