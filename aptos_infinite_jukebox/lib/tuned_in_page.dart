import 'package:flutter/material.dart';

import 'constants.dart';
import 'page_selector.dart';

class TunedInPage extends StatefulWidget {
  const TunedInPage({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  State<TunedInPage> createState() => TunedInPageState();
}

class TunedInPageState extends State<TunedInPage> {
  bool advisoryShownOnce = false;

  @override
  Widget build(BuildContext context) {
    Widget body = Container();

    FloatingActionButton floatingActionButton = FloatingActionButton(
        backgroundColor: Color.fromARGB(255, 177, 0, 0),
        child: Icon(Icons.exit_to_app),
        onPressed: () {
          widget.pageSelectorController.tunedIn = false;
          widget.pageSelectorController.refresh();
        });

    return buildTopLevelScaffold(widget.pageSelectorController, body,
        floatingActionButton: floatingActionButton);
  }
}
