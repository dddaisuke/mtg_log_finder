import 'dart:async';
import 'dart:html';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_browser.dart' as auth;
import 'package:intl/intl.dart';
//import 'package:dart_config/default_browser.dart';

final identifier = new auth.ClientId("205730641287-cnq8o1231krttqtssiru8ddj0i985ml3.apps.googleusercontent.com", null);

final scopes = [drive.DriveApi.DriveMetadataReadonlyScope, drive.DriveApi.DriveReadonlyScope];

class File {
  drive.File driveFile;
  bool isHidden;
  String icon;
  String timestamp;
  String title;
  bool isFolder;

  File(drive.File _file, bool _isHidden, String _icon) {
    driveFile = _file;
    icon = _icon;
    isHidden = _isHidden;
    title = _file.name.toString();
    isFolder = (_file.mimeType == 'application/vnd.google-apps.folder');

    bool isMatch = new RegExp(r"^\d{8}").hasMatch(title);
    if (isMatch) {
      timestamp = title.substring(0, 8);
    } else {
      DivElement divError = querySelector('#error');
      divError.appendHtml("「" + title + "」が不正なタイトルです。");
      divError.append(new BRElement());
      timestamp = null;
    }
  }
}

class Folder {
  String hash;
  bool isHidden;
  String imagePath;
  String memo;

  Folder(String _hash, bool _isHidden, String _imagePath, String _memo) {
    this.hash = _hash;
    this.isHidden = _isHidden;
    this.imagePath = _imagePath;
    this.memo = _memo;
  }
}

List<File> toFileList(List<drive.File> _files, bool _isHidden, String _icon) {
  List<File> files = new List<File>();
  for (drive.File driveFile in _files) {
    File file = new File(driveFile, _isHidden, _icon);
    if (file.timestamp != null) {
      files.add(file);
    }
  }
  return files;
}

List<File> filter(List<File> _files, Pattern pattern) {
  List<File> result = new List<File>();
  for (File file in _files) {
    if (file.driveFile.name.contains(pattern)) {
      result.add(file);
    }
  }
  return result;
}

void main() {
  InputElement loginButton = querySelector('#login_button');

  authorizedClient(loginButton, identifier, scopes).then((client) {
    drive.DriveApi api = new drive.DriveApi(client);

    DivElement main = querySelector('#main');
    main.remove();

    List<File> files = new List<File>();
    int pageSize = 100;

    List<Folder> folders = new List<Folder>();
    folders.add(new Folder('1YdzV1HFp2gT4mwuAVZtvt_lvnHpPpfIg', false, null, 'manabo/MtgLogs/2017/2017_4Q'));
    folders.add(new Folder('0B7gIZmKENAt5d0dhODhNbkZNUnM', false, null, 'manabo/MtgLogs/2017/2017_3Q'));
//    folders.add(new Folder('0B7gIZmKENAt5SERvaW9uVGhPd1k', false, null, 'manabo/MtgLogs/2017/2017_2Q'));
//    folders.add(new Folder('0B4oiy9QA-HVNaEp2ejdWamlHVzg', true, 'images/ethereum-16.png', 'ICO/MtgLogs'));
    folders.add(new Folder('1fuimW9T80vOV1MvWE2UJRCfZJhmVp9qh', true, 'images/private-16.png',
        'Confidentials/ConfidentialMtgLogs/2017/2017_4Q'));
    folders.add(new Folder('0B2t1uXRrSZ4SQXpZd3JoYjFKaTQ', true, 'images/private-16.png',
        'Confidentials/ConfidentialMtgLogs/2017/2017_3Q'));
//    folders.add(new Folder('0B7gIZmKENAt5ejZKOFR0b2hQVU0', true, 'images/private-16.png', 'Confidentials/ConfidentialMtgLogs/2017/2017_2Q'));
    folders.add(new Folder('1FZr34hrkpzeNuVNXNEmM5SRDvUmIoilv', true, 'images/up-16.png', '取締役会議事録'));
    folders.add(new Folder('0B2t1uXRrSZ4SMnA5SWFDWHd0WGs', true, 'images/private-16.png', 'エンジニア面談'));
    insertFilterView(api, folders, files, pageSize);
    insertSearchView(files);

    loadDriveFiles(api, folders, files, pageSize);
  });
}

void insertSearchView(List<File> files) {
  var search = querySelector('#search');

  SpanElement span = new SpanElement();
  span.setInnerHtml('絞り込み');
  search.append(span);

  TextInputElement input = new TextInputElement();
  input.onInput.listen((e) {
    removeDocument();
    List<File> filteredFiles = filter(files, input.value);
    loadDocuments(filteredFiles);
  });
  window.onKeyUp.listen((KeyboardEvent e) {
    if (e.keyCode == KeyCode.SLASH) {
      input.focus();
    }
  });
  search.append(input);
}

void insertFilterView(drive.DriveApi api, List<Folder> folders, List<File> files, int pageSize) {
  var filterDiv = querySelector('#filter');

  SpanElement divCount = new SpanElement();
  divCount.setInnerHtml('表示件数');
  filterDiv.append(divCount);

  SelectElement select = new SelectElement();
  OptionElement option100 = new OptionElement(data: '100', value: '100');
  OptionElement option75 = new OptionElement(data: '75', value: '75');
  OptionElement option50 = new OptionElement(data: '50', value: '50');
  OptionElement option25 = new OptionElement(data: '25', value: '25');
  select.append(option100);
  select.append(option75);
  select.append(option50);
  select.append(option25);

  select.onChange.listen((e) {
    pageSize = int.parse(select.value);
    files.clear();
    loadDriveFiles(api, folders, files, pageSize);
  });
  filterDiv.append(select);
}

void loadDriveFiles(drive.DriveApi api, List<Folder> folders, List<File> files, int pageSize) {
  folders.forEach((Folder folder) {
    api.files.list(orderBy: 'createdTime desc', q: "'" + folder.hash + "' in parents", pageSize: pageSize).then((list) {
      window.console.log(folder.hash);
      files.addAll(toFileList(list.files, folder.isHidden, folder.imagePath));

      files.sort((a, b) => b.title.compareTo(a.title));
      removeDocument();
      loadDocuments(files);
    });
  });
}

String getToday() {
  var now = new DateTime.now();
  var formatter = new DateFormat('yyyyMMdd');
  String today = formatter.format(now);
  return today;
}

String getOneWeekAgo() {
  var oneWeekAgo = new DateTime.now();
  oneWeekAgo = oneWeekAgo.subtract(new Duration(days: 7));
  var formatter = new DateFormat('yyyyMMdd');
  return formatter.format(oneWeekAgo);
}

void removeDocument() {
  DivElement todayDocuments = querySelector('#today_documents');
  todayDocuments.innerHtml = '';
  DivElement lastWeek = querySelector('#last_week_documents');
  lastWeek.innerHtml = '';
  DivElement futureDocuments = querySelector('#future_documents');
  futureDocuments.innerHtml = '';
  DivElement searched = querySelector('#serached_documents');
  searched.innerHtml = '';
}

void loadDocuments(List<File> files) {
  DivElement todayDocuments = querySelector('#today_documents');
  DivElement lastWeek = querySelector('#last_week_documents');
  DivElement futureDocuments = querySelector('#future_documents');
  DivElement searched = querySelector('#serached_documents');

  var title1 = new DivElement();
  title1.text = "■ 本日の資料";
  title1.setAttribute('class', 'title');
  todayDocuments.append(title1);
  var title2 = new DivElement();
  title2.text = "■ 先週の資料";
  title2.setAttribute('class', 'title');
  lastWeek.append(title2);
  var titleFuture = new DivElement();
  titleFuture.text = "■ 未来の資料";
  titleFuture.setAttribute('class', 'title');
  futureDocuments.append(titleFuture);
  var title3 = new DivElement();
  title3.text = "■ 直近の資料";
  title3.setAttribute('class', 'title');
  searched.append(title3);

  String today = getToday();
  String oneWeekAgo = getOneWeekAgo();

  for (File file in files) {
    String name = file.driveFile.name.toString();
    if (name.startsWith(new RegExp(r'^' + today))) {
      todayDocuments.append(createAnchorElement(file));
    } else if (name.startsWith(new RegExp(r'^' + oneWeekAgo))) {
      lastWeek.append(createAnchorElement(file));
    } else if (int.parse(file.timestamp) > int.parse(today)) {
      futureDocuments.append(createAnchorElement(file));
    } else {
      searched.append(createAnchorElement(file));
    }
  }
}

Element createAnchorElement(File file) {
  DivElement div = new DivElement();
  if (file.isFolder) {
    div.setAttribute('class', 'link hidden');
    ImageElement img = new ImageElement(src: 'images/folder-16.png');
    img.setAttribute('class', 'private');
    div.append(img);
  } else if (file.isHidden) {
    div.setAttribute('class', 'link hidden');
    ImageElement img = new ImageElement(src: file.icon);
    img.setAttribute('class', 'private');
    div.append(img);
  } else {
    div.setAttribute('class', 'link public');
  }

  AnchorElement aElement = new AnchorElement();
  aElement.appendText(file.driveFile.name.toString());
  if (file.isFolder) {
    aElement.href = "https://drive.google.com/drive/folders/" + file.driveFile.id.toString();
  } else {
    aElement.href = "https://docs.google.com/a/manabo.com/document/d/" + file.driveFile.id.toString() + "/edit";
  }
  aElement.target = '_blank';
  div.append(aElement);
  return div;
}

// Obtain an authenticated HTTP client which can be used for accessing Google
// APIs.
Future authorizedClient(InputElement loginButton, auth.ClientId id, scopes) {
  return auth.createImplicitBrowserFlow(id, scopes).then((auth.BrowserOAuth2Flow flow) {
    return flow.clientViaUserConsent(immediate: false).catchError((_) {
      return loginButton.onClick.first.then((_) {
        return flow.clientViaUserConsent(immediate: true);
      });
    }, test: (error) => error is auth.UserConsentException);
  });
}
