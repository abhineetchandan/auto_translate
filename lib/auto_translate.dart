import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

void runWithArguments(List<String> arguments) {
  Translator().translate();
}

class Translator {
  Translator();
  final _complexMap = <String, String>{};
  // expression for finding variables in simple arb strings (wrapped in {})
  final _arbVarExp = RegExp(r'{.*}');

  // exprssion for finding variables in complex arb string
  final _complexArbVarExp = RegExp(r'\$\w*');

  // expression used for storing variables in simple arb strings
  final _simpleVarExp = RegExp(r'\[VAR_\d*\]');

  // expression used for storing variables in complex arb strings
  final _complexVarExp = RegExp(r'\[CVAR_\d*\]');

  // map for storing simple arb string variables
  final _variableMap = <String, String>{};

  Set<String> languages = const {
    "en",
    "ar",
    "bn",
    "de",
    "es",
    "fr",
    "hi",
    "ja",
    "ko",
    "pt",
    "ru",
    "tr",
    "ur",
    "zh-CN",
    "zh-TW",
  };

  String _createComplexVariable(String value) {
    final variableName = '[CVAR_${_complexMap.length}]';
    _complexMap[variableName] = value;
    return variableName;
  }

  String _createVariable(String value) {
    final variableName = '[VAR_${_variableMap.length}]';
    _variableMap[variableName] = value;
    return variableName;
  }

  String _encodeComplexString(String string) {
    final prefix =
        string.substring(0, string.indexOf(',', string.indexOf(',') + 1) + 1);
    final replacementPrefix = _createComplexVariable(prefix);
    string = string.replaceFirst(prefix, replacementPrefix);
    final complexStrings = string
        .substring(replacementPrefix.length, string.length - 1)
        .trim()
        .split(r'}');
    for (final complexString in complexStrings) {
      final parts = complexString.trim().split('{');
      final name = parts[0];
      string =
          string.replaceFirst('$name{', '${_createComplexVariable(name)}{');
    }
    final variables = _complexArbVarExp.allMatches(string).toList().reversed;
    for (final variable in variables) {
      final replacement = _createComplexVariable(
          string.substring(variable.start, variable.end));
      string = string.replaceRange(variable.start, variable.end, replacement);
    }
    return string;
  }

  String _encodeString(String string) {
    final firstMatch = _arbVarExp.firstMatch(string);
    if (firstMatch != null &&
        string.substring(firstMatch.start, firstMatch.end).contains(',')) {
      return _encodeComplexString(string.substring(1, string.length - 1));
    }

    final variables = _arbVarExp.allMatches(string).toList().reversed;
    for (final variable in variables) {
      final replacement =
          _createVariable(string.substring(variable.start, variable.end));
      string = string.replaceRange(variable.start, variable.end, replacement);
    }
    return string;
  }

  String _decodeSimpleString(String string) {
    // reverse variable list so locations in string are not affected
    // during manipulation
    final variables = _simpleVarExp.allMatches(string).toList().reversed;
    for (final variable in variables) {
      final replacement =
          _variableMap[string.substring(variable.start, variable.end)];
      if (replacement != null) {
        string = string.replaceRange(variable.start, variable.end, replacement);
      }
    }
    return string;
  }

  String _decodeComplexString(String string) {
    final variables = _complexVarExp.allMatches(string).toList().reversed;
    for (final variable in variables) {
      var replacement =
          _complexMap[string.substring(variable.start, variable.end)];
      if (replacement != null) {
        // some language translations (i.e. Japanese) may remove spaces
        // that are part of the arb spacing, so correct for those changes
        if (replacement[0] != '\$' &&
            variable.start != 0 &&
            string[variable.start - 1] != ' ') {
          replacement = ' $replacement';
        }
        string = string.replaceRange(variable.start, variable.end, replacement);
      }
    }
    return '{$string}';
  }

  String _decodeString(String string) => string.startsWith(_complexVarExp)
      ? _decodeComplexString(string)
      : _decodeSimpleString(string);

  Future<void> translate() async {
    String arbDirPath = "lib/l10n/";
    String templateFileName = "intl_";
    final keyFile = File("apikey");
    final apiKey = keyFile.readAsStringSync();
    final mainFile = File("lib/l10n/intl_en.arb");
    final mainArb =
        jsonDecode(mainFile.readAsStringSync()) as Map<String, dynamic>;
    final arbOptions = Map.from(mainArb)
      ..removeWhere((key, value) => !key.startsWith('@'));
    mainArb.removeWhere((key, value) => key.startsWith('@'));
    const encoder = JsonEncoder.withIndent('  ');

    for (final entry in mainArb.entries) {
      mainArb[entry.key] = _encodeString(entry.value);
    }

    // for (String language in languages) {
    //   if (language == "en") continue;
    //   final arbFile = File("$arbDirPath$templateFileName$language.arb");
    //   arbFile.writeAsString('{"@@locale": "$language"}', mode: FileMode.write);
    // }

    final translations = <String, String>{};

    for (final language in languages) {
      final toTranslate = List<MapEntry<String, dynamic>>.from(mainArb.entries);
      final arbFile = File('$arbDirPath/intl_$language.arb');
      if (arbFile.existsSync()) {
        // do not translate previously translated phrases
        // unless marked force
        final prevTranslations =
            jsonDecode(arbFile.readAsStringSync()).cast<String, String>();
        toTranslate.removeWhere((element) =>
            prevTranslations.containsKey(element.key) &&
            !(arbOptions['@${element.key}']?['translator']?['force'] ?? false));
        translations.addAll(prevTranslations);
      }

      if (toTranslate.isEmpty) {
        stdout.writeln('No changes to app_$language.arb');
        continue;
      }

      stdout.write('Translating to $language...');

      // Most Translate API requests are limited to 128 strings & 5k characters,
      // so iterate through in chunks if necessary
      var start = 0;
      while (start < toTranslate.length) {
        final sublist =
            toTranslate.sublist(start, min(start + 500, toTranslate.length));

        final values = sublist.map<String>((e) => e.value).toList();

        var charCount = values.fold<int>(
            0, (previousValue, element) => previousValue + element.length);
        while (charCount > 25000) {
          sublist.removeLast();
          final removedEntry = values.removeLast();
          charCount -= removedEntry.length;
        }
        final client = http.Client();
        final result = await _translate(
          client: client,
          content: values,
          source: "en",
          target: language,
          apiKey: apiKey,
        );
        if (result != null) {
          final keys = sublist.map((e) => e.key).toList();
          for (var i = 0; i < keys.length; i++) {
            translations[keys[i]] = _decodeString(result[i]);
          }
        } else {
          print("null result from api");
        }
        start += sublist.length;
      }

      if (translations.isNotEmpty) {
        arbFile.writeAsStringSync(encoder.convert(translations));
      }
      stdout.writeln('done.');
    }
  }

  Future<List<String>?> _translate({
    required http.Client client,
    required List<String> content,
    required String source,
    required String target,
    required String apiKey,
  }) async {
    final url =
        Uri.https("api-apc.cognitive.microsofttranslator.com", "/translate", {
      'api-version': '3.0',
      'from': source,
      'to': [target],
      'category': "8957401b-ec2f-49ff-984c-bc4a5101d4c1-INTERNT",
    });
    final response = await client.post(
      url,
      headers: {
        'Ocp-Apim-Subscription-Key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-ClientTraceId': Uuid().v4().toString(),
        "Ocp-Apim-Subscription-Region": "centralindia",
      },
      body: jsonEncode(
        content.map((e) => {'Text': e}).toList(),
      ),
    );

    print(response.statusCode);
    print(response.body);
    print(response.headers);

    if (response.body.isEmpty) {
      print("null response");
      print(response);
      return null;
    }
    final json = jsonDecode(response.body);

    // print(json);
    return json
        .map((e) {
          return (e['translations'])[0]['text'] as String;
        })
        .toList()
        .cast<String>();
  }
}
