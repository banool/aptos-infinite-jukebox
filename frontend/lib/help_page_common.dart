import 'package:aptos_infinite_jukebox/page_selector.dart';
import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  final String title;
  final Map<String, List<String>> items;
  final PageSelectorController pageSelectorController;

  const HelpPage(
      {Key? key,
      required this.pageSelectorController,
      required this.title,
      required this.items})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> tiles = [];
    for (MapEntry<String, List<String>> e in items.entries) {
      tiles.add(Card(
        child: ListTile(
          title: Text(
            e.key,
            textAlign: TextAlign.start,
            style: TextStyle(fontSize: 14),
          ),
          onTap: () async => showDialog(
              context: context,
              builder: (BuildContext context) {
                List<Widget> children = [];
                for (String s in e.value) {
                  children.add(Text(
                    s,
                    strutStyle: StrutStyle(fontSize: 15),
                  ));
                  children.add(Padding(
                    padding: EdgeInsets.only(top: 20),
                  ));
                }
                children.removeLast();
                return SimpleDialog(
                  contentPadding: EdgeInsets.all(20),
                  children: children,
                );
              }),
        ),
      ));
    }

    Widget body = ListView(children: tiles);
    return buildTopLevelScaffold(pageSelectorController, body,
        title: title, isSubPage: true);
  }
}
