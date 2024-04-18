# Microsoft Azure Custom Translator for Flutter/Dart applications (Yaml Files)

Steps to use:
1. Make a folder called l10n in `lib/l10n`
2. Copy the `en.arb` file which contains the english translations.
3. Add your Microsoft Azure Api Key in a file called "apikey" at the root directory. Heirachy: "auto_translate/apikey" which contains the api key pasted as text.
4. Run dart run.

## Properties to edit:
There are various properties you may need to modify according to your needs:
1. Modify the languages that you need to translate to: https://github.com/abhineetchandan/auto_translate/blob/7ea0e5c5bd1648bacd16a1a4aa007313a5996f1d/lib/auto_translate.dart#L30-L47
> **_Note:_** sub-language code supported by Azure are in the format "zh-CN" but flutter uses "zh_CN" so after running translate you may need to edit the generated file to support that.
2. You can choose where the generated files are stored and their names are generated:
https://github.com/abhineetchandan/auto_translate/blob/7ea0e5c5bd1648bacd16a1a4aa007313a5996f1d/lib/auto_translate.dart#L138-L139
3. Choose from which language to tranlsate: Edit the following lines:
https://github.com/abhineetchandan/auto_translate/blob/7ea0e5c5bd1648bacd16a1a4aa007313a5996f1d/lib/auto_translate.dart#L142
https://github.com/abhineetchandan/auto_translate/blob/7ea0e5c5bd1648bacd16a1a4aa007313a5996f1d/lib/auto_translate.dart#L203
4. Edit category, region and other properties according to need in lib/auto_translate.dart:
https://github.com/abhineetchandan/auto_translate/blob/7ea0e5c5bd1648bacd16a1a4aa007313a5996f1d/lib/auto_translate.dart#L232-L238
https://github.com/abhineetchandan/auto_translate/blob/7ea0e5c5bd1648bacd16a1a4aa007313a5996f1d/lib/auto_translate.dart#L246
