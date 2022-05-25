import 'package:aptos_infinite_jukebox/player_selector.dart';
import 'package:aptos_infinite_jukebox/voting_page.dart';
import 'package:flutter/material.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'constants.dart';
import 'settings_page.dart';

class PageSelector extends StatefulWidget {
  const PageSelector({Key? key}) : super(key: key);

  @override
  State<PageSelector> createState() => PageSelectorState();
}

class TabInformation {
  final BottomNavigationBarItem bottomNavBarItem;
  final Widget tabBody;

  TabInformation(this.bottomNavBarItem, this.tabBody);
}

enum TunedInState {
  tunedOut,
  tuningIn,
  tunedIn,
}

// This class contains information that only makes sense to be stored
// above each tab. This includes stuff that needs to remembered between
// each tab, since they lose their state when tabbing between each.
//
// See this stackoverflow answer for an explanation as to why the variables
// in this class are defined as late:
// https://stackoverflow.com/questions/68717452/why-cant-non-nullable-fields-be-initialized-in-a-constructor-body-in-dart
class PageSelectorController {
  late int currentNavBarIndex;
  late List<TabInformation> tabs;
  late void Function() refresh;
  TunedInState tunedInState = TunedInState.tunedOut;

  void goToTab(int index) {
    currentNavBarIndex = index;
    refresh();
  }

  void onNavBarItemTapped(int index) {
    currentNavBarIndex = index;
    refresh();
  }

  List<TabInformation> getTabs() {
    List<TabInformation> items = [
      TabInformation(
          BottomNavigationBarItem(
            icon: Icon(Icons.play_arrow),
            label: "Play",
          ),
          PlayerSelector(pageSelectorController: this)),
      TabInformation(
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "Vote",
          ),
          VotingPage(pageSelectorController: this)),
      TabInformation(
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
          SettingsPage(pageSelectorController: this)),
    ];
    return items;
  }

  List<BottomNavigationBarItem> getBottomNavBarItems() {
    return tabs.map((e) => e.bottomNavBarItem).toList();
  }

  Widget getCurrentScaffold() {
    return tabs[currentNavBarIndex].tabBody;
  }

  PageSelectorController.fromInit(void Function() r) {
    currentNavBarIndex = 0;
    tabs = getTabs();
    refresh = r;
  }

  PageSelectorController(
      {required this.currentNavBarIndex,
      required this.tabs,
      required this.refresh});
}

class PageSelectorState extends State<PageSelector> {
  bool advisoryShownOnce = false;

  late PageSelectorController controller;

  @override
  void initState() {
    super.initState();
    controller = PageSelectorController.fromInit(refresh);
  }

  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionStatus>(
        stream: SpotifySdk.subscribeConnectionStatus(),
        builder: (context, snapshot) {
          return InheritedSpotifyConnectionStatus(
              connectionStatus: snapshot.data,
              child: controller.getCurrentScaffold());
        });
  }
}

// This helps us keep the ConnectionStatus at the root of the tree while
// allowing children to access it easily without passing it down.
class InheritedSpotifyConnectionStatus extends InheritedWidget {
  final ConnectionStatus? connectionStatus;

  const InheritedSpotifyConnectionStatus(
      {required this.connectionStatus, required Widget child, Key? key})
      : super(child: child, key: key);

  @override
  bool updateShouldNotify(InheritedSpotifyConnectionStatus oldWidget) {
    if (connectionStatus != oldWidget.connectionStatus) {
      return true;
    }
    return false;
  }

  static InheritedSpotifyConnectionStatus of(BuildContext context) {
    final InheritedSpotifyConnectionStatus? result = context
        .dependOnInheritedWidgetOfExactType<InheritedSpotifyConnectionStatus>();
    return result!;
  }
}

// TODO: On web, show a sidebar down the left instead of a bottom tab bar.
Scaffold buildTopLevelScaffold(PageSelectorController controller, Widget body,
    {Widget? floatingActionButton,
    String? title,
    bool isSubPage = false,
    List<Widget>? appBarActions,
    Widget? leadingAppBarButton}) {
  AppBar? appBar;
  if (title != null) {
    appBar = AppBar(
      leading: leadingAppBarButton,
      title: Text(title),
      centerTitle: true,
      actions: appBarActions,
    );
  }
  BottomNavigationBar? bottomNavigationBar;
  if (!isSubPage) {
    bottomNavigationBar = BottomNavigationBar(
      items: controller.getBottomNavBarItems(),
      currentIndex: controller.currentNavBarIndex,
      selectedItemColor: spotifyGreen,
      onTap: controller.onNavBarItemTapped,
      type: BottomNavigationBarType.fixed,
    );
  }
  return Scaffold(
    body: body,
    appBar: appBar,
    floatingActionButton: floatingActionButton,
    bottomNavigationBar: bottomNavigationBar,
  );
}
