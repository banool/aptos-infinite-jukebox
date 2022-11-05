import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/material.dart';

import 'page_selector.dart';

class VoteResultsPage extends StatelessWidget {
  final PageSelectorController pageSelectorController;
  final FullTransactionResult transactionResult;

  const VoteResultsPage(this.pageSelectorController, this.transactionResult,
      {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    String resultsHeaderString =
        transactionResult.committed ? "🤠  Success  🤠" : "😢  Error  😢";
    List<Widget> textBodyChildren = [];
    if (transactionResult.transaction != null) {
      textBodyChildren += [
        Text(
          "Transaction",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        Divider(
          indent: 100,
          endIndent: 100,
        ),
        Text(transactionResult.transaction!.toString()),
        Divider(height: 50),
        Padding(
          padding: EdgeInsets.only(top: 20),
        )
      ];
    }
    if (transactionResult.errorString != null) {
      textBodyChildren += [
        Text("Error", style: TextStyle(fontWeight: FontWeight.w500)),
        Divider(
          indent: 100,
          endIndent: 100,
        ),
        Text(transactionResult.errorString!)
      ];
    }
    Widget body = Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              resultsHeaderString,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            Divider(height: 50),
            Expanded(
                child: SingleChildScrollView(
                    child: Column(
              children: textBodyChildren,
            ))),
          ],
        ));
    return buildTopLevelScaffold(pageSelectorController, body,
        title: "Vote Submission", isSubPage: true);
  }
}
