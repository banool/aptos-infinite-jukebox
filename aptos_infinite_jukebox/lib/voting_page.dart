import 'package:flutter/material.dart';

import 'constants.dart';
import 'page_selector.dart';

class VotingPage extends StatefulWidget {
  const VotingPage({Key? key, required this.pageSelectorController})
      : super(key: key);

  final PageSelectorController pageSelectorController;

  @override
  State<VotingPage> createState() => VotingPageState();
}

class VotingPageState extends State<VotingPage> {
  bool advisoryShownOnce = false;

  @override
  Widget build(BuildContext context) {
    Widget body = Container();
    return buildTopLevelScaffold(widget.pageSelectorController, body);
  }
}
