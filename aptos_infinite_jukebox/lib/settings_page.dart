import 'package:aptos_infinite_jukebox/troubleshooting_help_page.dart';
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
                "Aptos FullNode URL",
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                bool confirmed = await showChangeStringSharedPrefDialog(context,
                    "Aptos FullNode URL", keyAptosNodeUrl, defaultAptosNodeUrl);
                if (confirmed) {
                  setState(() {});
                }
              }),
          SettingsTile.navigation(
              title: getText(
                "Jukebox address",
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                bool confirmed = await showChangeStringSharedPrefDialog(context,
                    "Jukebox address", keyPublicAddress, defaultPublicAddress);
                if (confirmed) {
                  setState(() {});
                }
              }),
          SettingsTile.navigation(
              title: getText(
                "Module address",
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                bool confirmed = await showChangeStringSharedPrefDialog(context,
                    "Module address", keyModuleAddress, defaultModuleAddress);
                if (confirmed) {
                  setState(() {});
                }
              }),
          SettingsTile.navigation(
              title: getText(
                "Module name",
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                bool confirmed = await showChangeStringSharedPrefDialog(
                    context, "Module name", keyModuleName, defaultModuleName);
                if (confirmed) {
                  setState(() {});
                }
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
              'App FAQ',
            ),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              return await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => getTroubleshootingHelpPage(
                        widget.pageSelectorController),
                  ));
            },
          )
        ],
        margin: margin,
      ),
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

Future<bool> showChangeStringSharedPrefDialog(
    BuildContext context, String title, String key, String defaultValue,
    {String cancelText = "Cancel", String confirmText = "Confirm"}) async {
  bool confirmed = false;
  String currentValue = sharedPreferences.getString(key) ?? defaultValue;
  TextEditingController textController =
      TextEditingController(text: currentValue);
  // TODO allow this function to take in something that changes the type
  // of text it is, e.g. for URL vs regular stuff.
  TextField textField = TextField(
    controller: textController,
  );
  // ignore: deprecated_member_use
  Widget cancelButton = FlatButton(
    child: Text(cancelText),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );
  // ignore: deprecated_member_use
  Widget continueButton = FlatButton(
    child: Text(confirmText),
    onPressed: () async {
      String newValue = textController.text;
      await sharedPreferences.setString(key, newValue);
      print("Set $key to $newValue");
      confirmed = true;
      Navigator.of(context).pop();
    },
  );
  AlertDialog alert = AlertDialog(
    title: Row(children: [
      Text(title),
      Spacer(),
      IconButton(
          onPressed: () {
            textController.text = defaultValue;
          },
          icon: Icon(Icons.restore))
    ]),
    content: textField,
    actions: [
      cancelButton,
      continueButton,
    ],
  );
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
  return confirmed;
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
