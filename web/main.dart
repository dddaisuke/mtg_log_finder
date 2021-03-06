import 'dart:async';
import 'dart:html';
import 'dart:js' as js;

import 'file.dart';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_browser.dart' as auth;
import 'package:intl/intl.dart';

final identifier = new auth.ClientId("205730641287-cnq8o1231krttqtssiru8ddj0i985ml3.apps.googleusercontent.com", null);

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
  setupBackground();
  DivElement header = querySelector('#header');
  ImageElement gearElement = new ImageElement(src: "images/gear-16.png");
  header.append(gearElement);

  DivElement menu = querySelector('#popup_menu');
  ButtonElement saveButton = new ButtonElement();
  saveButton.text = "保存";
  InputElement input = new InputElement();
  input.onKeyPress.listen((e) {
    if(e.keyCode == KeyCode.ENTER) {
      saveButton.click();
    }
  });

  menu.append(input);
  menu.append(saveButton);
  saveButton.onClick.listen((e) {
    window.localStorage['photoSearchWord'] = input.value;
    closePopupWindow();
    if(input.value != "") {
      updateBackground(input.value);
    }
  });

  DivElement grayPanel = querySelector('#gray_panel');
  grayPanel.onClick.listen((e) {
    closePopupWindow();
  });

  js.context.callMethod(r'$', ['#gray_panel'])
    .callMethod('css', [new js.JsObject.jsify({
    "background" : "#000",
    "opacity"  : "0.5",
    "width"   : "100%",
    "height"  : 99999,
    "position"  : "fixed",
    "top"   : "0",
    "left"   : "0",
    "display"  : "none",
    "z-index"  : "101"
  })]);

  gearElement.onClick.listen((e) {
    openPopupWindow();
  });

  InputElement loginButton = querySelector('#login_button');

  authorizedClient(loginButton, identifier, scopes).then((client) {
    drive.DriveApi api = new drive.DriveApi(client);

    DivElement login = querySelector('#login');
    login.remove();

    List<MtgFile> files = new List<MtgFile>();
    int pageSize = 100;

    List<Folder> folders = new List<Folder>();

    setupMainView();

    List<Future<Folder>> listMtgLogs = findFolders(api, '0B2t1uXRrSZ4Sb3N3RUZYS0R2dGM', false, null); // MtgLogs
    List<Future<Folder>> listConfidentialMtgLogs = findFolders(api, '0B4oiy9QA-HVNa3dHNnIwcWlHbFk', true, 'images/private-16.png'); // ConfidentialMtgLogs

    List<Future<Folder>> list = new List<Future<Folder>>();
    list.addAll(listMtgLogs);
    list.addAll(listConfidentialMtgLogs);

    var futureFolderList = Future.wait(list);
    futureFolderList.then((List<Folder> folderList) {
      folders.addAll(folderList);

      insertFilterView(api, folders, files, pageSize);
      insertSearchView(files);

      loadDriveFiles(api, folders, files, pageSize);
    });
  });
}

List<Future<Folder>> findFolders(drive.DriveApi api, String rootFolderId, bool isHidden, String imagePath) {
  int pageSize = 100;
  List<List<String>> months = getMonths();

  List<Future<Folder>> asyncFolderList = new List<Future<Folder>>();
  months.forEach((targetFolder) {
    Future<Folder> folder = api.files.list(orderBy: 'createdTime desc', q: "'" + rootFolderId + "' in parents AND name = '" + targetFolder.first + "'", pageSize: pageSize).then((list) {
      drive.File folderYear = list.files.first;
      if(folderYear == null) {
        DivElement divError = querySelector('#error');
        divError.appendHtml("「${targetFolder.first}」フォルダーが見つかりませんでした。");
        divError.append(new BRElement());
        return null;
      }

      var asyncFunc = api.files.list(orderBy: 'createdTime desc', q: "'" + folderYear.id + "' in parents AND name = '" + targetFolder.last + "'", pageSize: pageSize).then((list) {
        if(list.files.length == 0) {
          DivElement divError = querySelector('#error');
          divError.appendHtml("「${targetFolder.last}」フォルダーが見つかりませんでした。");
          divError.append(new BRElement());
          return null;
        }
        return new Folder(list.files.first.id, isHidden, imagePath, "${targetFolder.first}/${targetFolder.last}");
      });
      return asyncFunc;
    });

    asyncFolderList.add(folder);
  });
  return asyncFolderList;
}

List<List<String>> getMonths() {
  DateTime now = new DateTime.now();
  window.console.log("aaa ${now.month}");
  switch(now.month) {
    case 4:
    case 5:
    case 6:
      return [["${now.year-1}", "${now.year}_4Q"], ["${now.year}", "${now.year}_1Q"]];
    case 7:
    case 8:
    case 9:
      return [["${now.year}", "${now.year}_1Q"], ["${now.year}", "${now.year}_2Q"]];
    case 10:
    case 11:
    case 12:
      return [["${now.year}", "${now.year}_2Q"], ["${now.year}", "${now.year}_3Q"]];
    case 1:
    case 2:
    case 3:
      return [["${now.year}", "${now.year}_3Q"], ["${now.year}", "${now.year}_4Q"]];
    default:
      throw new Error();
  }
}

void setupBackground() {
  String keyword = window.localStorage['photoSearchWord'];
  if(keyword != null) {
    window.console.log("[load] "+keyword);
  } else {
    keyword = "summer";
  }
  updateBackground(keyword);
}

void updateBackground(String photoSearchKeyWord) {
  DivElement body = querySelector("#body");
  body.style.setProperty("background-image", "url('//source.unsplash.com/1024x768?" + photoSearchKeyWord + "')");
}

void openPopupWindow() {
  js.context.callMethod(r'$', ['#gray_panel'])
    .callMethod('fadeIn', ["slow"]);

  DivElement body = querySelector("#body");
  DivElement menu = querySelector('#popup_menu');
  var position = (body.offsetWidth / 2) - (menu.offsetWidth / 2);
  window.console.log(position);

  js.context.callMethod(r'$', ['#popup_menu'])
    .callMethod('css', [new js.JsObject.jsify({
    "z-index"  : "102",
    "position"  : "fixed",
    "top"   : "270px",
    "left"   : position,
  })]);
  js.context.callMethod(r'$', ['#popup_menu'])
    .callMethod('fadeIn', ["slow"]);
}

void closePopupWindow() {
  js.context.callMethod(r'$', ['#popup_menu'])
    .callMethod('fadeOut', ["slow"]);
  js.context.callMethod(r'$', ['#gray_panel'])
    .callMethod('fadeOut', ["slow"]);
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
    if(folder != null) {
      api.files.list(orderBy: 'createdTime desc', q: "'" + folder.hash + "' in parents", pageSize: pageSize).then((list) {
        //window.console.log(folder.hash);
        files.addAll(toFileList(list.files, folder.isHidden, folder.imagePath));

        files.sort((a, b) => b.originalTitle.compareTo(a.originalTitle));
        removeDocument();
        loadDocuments(files);
      });
    }
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

  UListElement folderDocuments = querySelector('#folder_documents');
  folderDocuments.innerHtml = '';
  UListElement todayDocuments = querySelector('#today_documents');
  todayDocuments.innerHtml = '';
  UListElement lastWeek = querySelector('#last_week_documents');
  lastWeek.innerHtml = '';
  UListElement futureDocuments = querySelector('#future_documents');
  futureDocuments.innerHtml = '';
  UListElement searched = querySelector('#serached_documents');
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
  folderDocuments.setAttribute('class', 'documents');
  mainDiv.append(folderDocuments);
  UListElement todayDocuments = new UListElement();
  todayDocuments.setAttribute('id', 'today_documents');
  todayDocuments.setAttribute('class', 'documents');
  mainDiv.append(todayDocuments);
  UListElement lastWeek = new UListElement();
  lastWeek.setAttribute('id', 'last_week_documents');
  lastWeek.setAttribute('class', 'documents');
  mainDiv.append(lastWeek);
  UListElement futureDocuments = new UListElement();
  futureDocuments.setAttribute('id', 'future_documents');
  futureDocuments.setAttribute('class', 'documents');
  mainDiv.append(futureDocuments);
  UListElement searched = new UListElement();
  searched.setAttribute('id', 'serached_documents');
  searched.setAttribute('class', 'documents');
  mainDiv.append(searched);
}

void loadDocuments(List<MtgFile> files) {
  UListElement folderDocuments = querySelector('#folder_documents');
  UListElement todayDocuments = querySelector('#today_documents');
  UListElement lastWeek = querySelector('#last_week_documents');
  UListElement futureDocuments = querySelector('#future_documents');
  UListElement searched = querySelector('#serached_documents');

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
