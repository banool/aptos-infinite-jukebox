import 'package:flutter/material.dart';

import 'common.dart';
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
    Widget body = Container();
    return buildTopLevelScaffold(widget.pageSelectorController, body);
  }
}
