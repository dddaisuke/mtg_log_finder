import 'dart:async';
import 'dart:html';

import 'file.dart';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_browser.dart' as auth;
import 'package:intl/intl.dart';
//import 'package:dart_config/default_browser.dart';

// server side
final identifier = new auth.ClientId("205730641287-cnq8o1231krttqtssiru8ddj0i985ml3.apps.googleusercontent.com", null);
// localhost
//final identifier = new auth.ClientId("205730641287-b74p81rbe4np53rp120inn39mlve3jq5.apps.googleusercontent.com", null);

final scopes = [drive.DriveApi.DriveMetadataReadonlyScope, drive.DriveApi.DriveReadonlyScope];

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

List<MtgFile> toFileList(List<drive.File> _files, bool _isHidden, String _icon) {
  List<MtgFile> files = new List<MtgFile>();
  for (drive.File driveFile in _files) {
    MtgFile file = new MtgFile(driveFile, _isHidden, _icon);
    if (file.timestamp != null) {
      files.add(file);
    } else if (file.isFolder) {
      files.add(file);
    }
  }
  return files;
}

List<MtgFile> filter(List<MtgFile> _files, Pattern pattern) {
  List<MtgFile> result = new List<MtgFile>();
  for (MtgFile file in _files) {
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

    DivElement login = querySelector('#login');
    login.remove();

    List<MtgFile> files = new List<MtgFile>();
    int pageSize = 100;

    List<Folder> folders = new List<Folder>();
    folders.add(new Folder('1jHZasBcxbUarzCx3k6xtl-Y6DY4IHtGu', false, null, 'manabo/MtgLogs/2018/2018_2Q'));
    folders.add(new Folder('10PM5DJr3uc6mSWChFzPEahEYviWx3LzV', false, null, 'manabo/MtgLogs/2018/2018_1Q'));
//    folders.add(new Folder('1YdzV1HFp2gT4mwuAVZtvt_lvnHpPpfIg', false, null, 'manabo/MtgLogs/2017/2017_4Q'));
//    folders.add(new Folder('0B7gIZmKENAt5d0dhODhNbkZNUnM', false, null, 'manabo/MtgLogs/2017/2017_3Q'));
//    folders.add(new Folder('0B7gIZmKENAt5SERvaW9uVGhPd1k', false, null, 'manabo/MtgLogs/2017/2017_2Q'));
//    folders.add(new Folder('0B4oiy9QA-HVNaEp2ejdWamlHVzg', true, 'images/ethereum-16.png', 'ICO/MtgLogs'));
    folders.add(new Folder('1GPcwnLVzMhhU3jjrJA0Rdi6Vw2YQHCrw', true, 'images/private-16.png', 'Confidentials/ConfidentialMtgLogs/2018/2018_2Q'));
    folders.add(new Folder('1nllhepAqxccAKI87FjBkkt4zcIQ6Y9YT', true, 'images/private-16.png', 'Confidentials/ConfidentialMtgLogs/2018/2018_1Q'));
//    folders.add(new Folder('1fuimW9T80vOV1MvWE2UJRCfZJhmVp9qh', true, 'images/private-16.png', 'Confidentials/ConfidentialMtgLogs/2017/2017_4Q'));
//    folders.add(new Folder('0B2t1uXRrSZ4SQXpZd3JoYjFKaTQ', true, 'images/private-16.png', 'Confidentials/ConfidentialMtgLogs/2017/2017_3Q'));
//    folders.add(new Folder('0B7gIZmKENAt5ejZKOFR0b2hQVU0', true, 'images/private-16.png', 'Confidentials/ConfidentialMtgLogs/2017/2017_2Q'));
    folders.add(new Folder('1FZr34hrkpzeNuVNXNEmM5SRDvUmIoilv', true, 'images/up-16.png', '取締役会議事録'));
    folders.add(new Folder('0B2t1uXRrSZ4SMnA5SWFDWHd0WGs', true, 'images/private-16.png', 'エンジニア面談'));

    setupMainView();

    insertFilterView(api, folders, files, pageSize);
    insertSearchView(files);

    loadDriveFiles(api, folders, files, pageSize);
  });
}

void insertSearchView(List<MtgFile> files) {
  var search = querySelector('#search');

  SpanElement span = new SpanElement();
  span.setInnerHtml('絞り込み');
  search.append(span);

  TextInputElement input = new TextInputElement();
  input.onInput.listen((e) {
    removeDocument();
    List<MtgFile> filteredFiles = filter(files, input.value);
    loadDocuments(filteredFiles);
  });
  window.onKeyUp.listen((KeyboardEvent e) {
    if (e.keyCode == KeyCode.SLASH) {
      input.focus();
    }
  });
  search.append(input);
}

void insertFilterView(drive.DriveApi api, List<Folder> folders, List<MtgFile> files, int pageSize) {
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

void loadDriveFiles(drive.DriveApi api, List<Folder> folders, List<MtgFile> files, int pageSize) {
  folders.forEach((Folder folder) {
    api.files.list(orderBy: 'createdTime desc', q: "'" + folder.hash + "' in parents", pageSize: pageSize).then((list) {
      window.console.log(folder.hash);
      files.addAll(toFileList(list.files, folder.isHidden, folder.imagePath));

      files.sort((a, b) => b.originalTitle.compareTo(a.originalTitle));
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
//  DivElement mainDiv = querySelector('#main');
//  mainDiv.innerHtml = '';

  DivElement folderDocuments = querySelector('#folder_documents');
  folderDocuments.innerHtml = '';
  DivElement todayDocuments = querySelector('#today_documents');
  todayDocuments.innerHtml = '';
  DivElement lastWeek = querySelector('#last_week_documents');
  lastWeek.innerHtml = '';
  DivElement futureDocuments = querySelector('#future_documents');
  futureDocuments.innerHtml = '';
  DivElement searched = querySelector('#serached_documents');
  searched.innerHtml = '';
}

void setupMainView() {
  DivElement mainDiv = querySelector('#main');

  DivElement errorDiv = new DivElement();
  errorDiv.setAttribute('id', 'error');
  mainDiv.append(errorDiv);
  DivElement filterDiv = new DivElement();
  filterDiv.setAttribute('id', 'filter');
  mainDiv.append(filterDiv);
  DivElement searchDiv = new DivElement();
  searchDiv.setAttribute('id', 'search');
  mainDiv.append(searchDiv);

  UListElement folderDocuments = new UListElement();
  folderDocuments.setAttribute('id', 'folder_documents');
  mainDiv.append(folderDocuments);
  UListElement todayDocuments = new UListElement();
  todayDocuments.setAttribute('id', 'today_documents');
  mainDiv.append(todayDocuments);
  UListElement lastWeek = new UListElement();
  lastWeek.setAttribute('id', 'last_week_documents');
  mainDiv.append(lastWeek);
  UListElement futureDocuments = new UListElement();
  futureDocuments.setAttribute('id', 'future_documents');
  mainDiv.append(futureDocuments);
  UListElement searched = new UListElement();
  searched.setAttribute('id', 'serached_documents');
  mainDiv.append(searched);
}

void loadDocuments(List<MtgFile> files) {
  DivElement folderDocuments = querySelector('#folder_documents');
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
  for (MtgFile file in files) {
    String name = file.driveFile.name.toString();
    if (name.startsWith(new RegExp(r'^' + today))) {
      todayDocuments.append(createAnchorElement(file));
    } else if (name.startsWith(new RegExp(r'^' + oneWeekAgo))) {
      lastWeek.append(createAnchorElement(file));
    } else if (file.timestamp != null && int.parse(file.timestamp) > int.parse(today)) {
      futureDocuments.append(createAnchorElement(file));
    } else if (file.timestamp == null && file.isFolder) {
      folderDocuments.append(createAnchorElement(file));
    } else {
      searched.append(createAnchorElement(file));
    }
  }
}

Element createAnchorElement(MtgFile file) {
  LIElement li = new LIElement();
  if (file.isFolder) {
    li.setAttribute('class', 'link hidden');
    ImageElement img = new ImageElement(src: 'images/folder-16.png');
    img.setAttribute('class', 'private');
    li.append(img);
  } else if (file.isHidden) {
    li.setAttribute('class', 'link hidden');
    ImageElement img = new ImageElement(src: file.icon);
    img.setAttribute('class', 'private');
    li.append(img);
  } else {
    li.setAttribute('class', 'link public');
  }

  AnchorElement aElement = new AnchorElement();
  aElement.appendText(file.driveFile.name.toString());
  if (file.isFolder) {
    aElement.href = "https://drive.google.com/drive/folders/" + file.driveFile.id.toString();
  } else {
    aElement.href = "https://docs.google.com/a/manabo.com/document/d/" + file.driveFile.id.toString() + "/edit";
  }
  aElement.target = '_blank';
  li.append(aElement);
  return li;
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
