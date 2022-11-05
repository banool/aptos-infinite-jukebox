import 'package:flutter/material.dart';

import 'constants.dart';
import 'globals.dart';

Widget getConnectionButton(String text, void Function() onPressed) {
  Border? border;
  return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
      decoration: BoxDecoration(
          color: spotifyGreen,
          border: border,
          borderRadius: BorderRadius.all(Radius.circular(20))),
      child: TextButton(
          onPressed: onPressed,
          style: ButtonStyle(
            foregroundColor: MaterialStateProperty.all(Colors.white),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: 18),
          )));
}

String buildResourceType({String? structName}) {
  String moduleAddress =
      sharedPreferences.getString(keyModuleAddress) ?? defaultModuleAddress;
  String moduleName =
      sharedPreferences.getString(keyModuleName) ?? defaultModuleName;
  structName = structName ??
      sharedPreferences.getString(keyStructName) ??
      defaultStructName;

  return "0x$moduleAddress::$moduleName::$structName";
}
