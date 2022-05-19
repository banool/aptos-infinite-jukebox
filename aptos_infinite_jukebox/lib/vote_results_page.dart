import 'package:flutter/material.dart';

import 'page_selector.dart';

class VoteResultsPage extends StatelessWidget {
  final PageSelectorController pageSelectorController;
  final bool success;
  final String explanation;

  const VoteResultsPage(
      this.pageSelectorController, this.success, this.explanation,
      {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    String resultsHeaderString = success ? "🤠 Success 🤠" : "😢 Error 😢";
    Widget body = Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              resultsHeaderString,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            Divider(height: 50),
            // TODO make this bit scrollabe
            Text(explanation),
          ],
        ));
    return buildTopLevelScaffold(pageSelectorController, body,
        title: "Vote Submission", isSubPage: true);
  }
}
