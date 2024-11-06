import 'package:collection/collection.dart';
import 'package:friend_private/backend/http/api/apps.dart';
import 'package:friend_private/backend/preferences.dart';
import 'package:friend_private/backend/schema/app.dart';
import 'package:friend_private/providers/base_provider.dart';
import 'package:friend_private/utils/alerts/app_dialog.dart';
import 'package:friend_private/utils/alerts/app_snackbar.dart';
import 'package:friend_private/utils/analytics/mixpanel.dart';

class AppProvider extends BaseProvider {
  List<App> apps = [];

  bool filterChat = true;
  bool filterMemories = true;
  bool filterExternal = true;
  String searchQuery = '';

  List<bool> appLoading = [];

  String selectedChatAppId = 'no_selected';

  bool isAppOwner = false;
  bool appPublicToggled = false;

  void setSelectedChatAppId(String? appId) {
    if (appId == null) {
      selectedChatAppId = SharedPreferencesUtil().selectedChatAppId;
    } else {
      selectedChatAppId = appId;
      SharedPreferencesUtil().selectedChatAppId = appId;
    }
    notifyListeners();
  }

  App? getSelectedApp() {
    return apps.firstWhereOrNull((p) => p.id == selectedChatAppId);
  }

  void setAppLoading(int index, bool value) {
    appLoading[index] = value;
    notifyListeners();
  }

  void clearSearchQuery() {
    searchQuery = '';
    notifyListeners();
  }

  Future getApps() async {
    setLoadingState(true);
    apps = await retrieveApps();
    updatePrefApps();
    setApps();
    appLoading = List.filled(apps.length, false);
    setLoadingState(false);
    notifyListeners();
  }

  Future checkIsAppOwner(String appId) async {
    if (appId.contains('private')) {
      isAppOwner = true;
      appPublicToggled = false;
    } else {
      var res = await checkIsAppOwnerServer(appId);
      isAppOwner = res;
      appPublicToggled = res;
    }

    notifyListeners();
  }

  Future deleteApp(String appId) async {
    var res = await deleteAppServer(appId);
    if (res) {
      apps.removeWhere((app) => app.id == appId);
      updatePrefApps();
      setApps();
      AppSnackbar.showSnackbarSuccess('App deleted successfully 🗑️');
    } else {
      AppSnackbar.showSnackbarError('Failed to delete app. Please try again later.');
    }
    notifyListeners();
  }

  void toggleAppPublic(String appId, bool value) {
    appPublicToggled = value;
    changeAppVisibilityServer(appId, value);
    getApps();
    apps.removeWhere((app) => app.id == appId);
    updatePrefApps();
    setApps();
    AppSnackbar.showSnackbarSuccess('App visibility changed successfully. It may take a few minutes to reflect.');
    notifyListeners();
  }

  bool isAppPublic(String appId) {
    if (appId.contains('private')) {
      return false;
    } else {
      return true;
    }
  }

  void setAppsFromCache() {
    if (SharedPreferencesUtil().appsList.isNotEmpty) {
      apps = SharedPreferencesUtil().appsList;
    }
    notifyListeners();
  }

  void updatePrefApps() {
    SharedPreferencesUtil().appsList = apps;
  }

  void setApps() {
    apps = SharedPreferencesUtil().appsList;
    notifyListeners();
  }

  void initialize(bool filterChatOnly) {
    if (filterChatOnly) {
      filterChat = true;
      filterMemories = false;
      filterExternal = false;
    }
    appLoading = List.filled(apps.length, false);

    getApps();
    notifyListeners();
  }

  Future<void> toggleApp(String appId, bool isEnabled, int idx) async {
    if (appLoading[idx]) return;
    appLoading[idx] = true;
    notifyListeners();
    var prefs = SharedPreferencesUtil();
    if (isEnabled) {
      var enabled = await enableAppServer(appId);
      if (!enabled) {
        AppDialog.show(
          title: 'Error activating the app',
          content: 'If this is an integration app, make sure the setup is completed.',
          singleButton: true,
        );

        appLoading[idx] = false;
        notifyListeners();

        return;
      }
      prefs.enableApp(appId);
      MixpanelManager().appEnabled(appId);
    } else {
      await disableAppServer(appId);
      prefs.disableApp(appId);
      MixpanelManager().appDisabled(appId);
    }
    appLoading[idx] = false;
    apps = SharedPreferencesUtil().appsList;
    notifyListeners();
  }

  // List<Plugin> get filteredPlugins {
  //   var pluginList = plugins
  //       .where((p) =>
  //           (p.worksWithChat() && filterChat) ||
  //           (p.worksWithMemories() && filterMemories) ||
  //           (p.worksExternally() && filterExternal))
  //       .toList();
  //
  //   return searchQuery.isEmpty
  //       ? pluginList
  //       : pluginList.where((plugin) => plugin.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
  // }

  void updateSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void toggleFilterChat() {
    filterChat = !filterChat;
    notifyListeners();
  }

  void toggleFilterMemories() {
    filterMemories = !filterMemories;
    notifyListeners();
  }

  void toggleFilterExternal() {
    filterExternal = !filterExternal;
    notifyListeners();
  }
}
