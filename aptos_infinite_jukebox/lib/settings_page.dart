import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';

import 'constants.dart';
import 'globals.dart';
import 'page_selector.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  bool advisoryShownOnce = false;

  @override
  Widget build(BuildContext context) {
    EdgeInsetsDirectional margin =
        EdgeInsetsDirectional.only(start: 15, end: 15, top: 10, bottom: 10);

    // TODO In the alerts for the text boxes, offer a reset option that sets
    // the value back to its default.

    List<AbstractSettingsSection?> sections = [
      SettingsSection(
        title: Text('Aptos Connection Settings'),
        tiles: [
          SettingsTile.navigation(
              title: getText(
                'Aptos FullNode URL',
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                // TODO: Pop up alert with text box for entering alternative value.
              }),
        ],
        margin: margin,
      ),
      SettingsSection(
        title: Text('Legal Information'),
        tiles: [
          SettingsTile.navigation(
            title: getText(
              'See legal information',
            ),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              return await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LegalInformationPage(
                        pageSelectorController: widget.pageSelectorController),
                  ));
            },
          )
        ],
        margin: margin,
      ),
      SettingsSection(
          title: Text('Community'),
          tiles: [
            SettingsTile.navigation(
              title: getText(
                'Report issue with app',
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {},
            ),
          ],
          margin: margin),
    ];

    List<AbstractSettingsSection> nonNullSections = [];
    for (AbstractSettingsSection? section in sections) {
      if (section != null) {
        nonNullSections.add(section);
      }
    }

    Widget body = SettingsList(sections: nonNullSections);
    return buildTopLevelScaffold(widget.pageSelectorController, body,
        title: "Settings");
  }
}

Text getText(String s, {bool larger = false}) {
  double size = 15;
  if (larger) {
    size = 18;
  }
  return Text(
    s,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: size),
  );
}

class LegalInformationPage extends StatelessWidget {
  const LegalInformationPage({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(
        padding: EdgeInsets.only(bottom: 10, left: 20, right: 32, top: 20),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: const [
              Text(
                  "This app is the sole work of the developer. "
                  "It is in no way affiliated with Aptos Labs / Matonee.\n",
                  textAlign: TextAlign.center),
              Text(
                  "The author of this app accepts no responsibility for its "
                  "use. As it stands now, the app is designed for use with "
                  "the Aptos dev / test networks. It should not be used with "
                  "the main network when it launches in its current state.",
                  textAlign: TextAlign.center),
            ]));
    return buildTopLevelScaffold(pageSelectorController, body,
        title: "Legal Information");
  }
}
