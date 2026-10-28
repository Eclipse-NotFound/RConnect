# Build the released A version

The canonical release source is `src/`, not a build cache or B experiment. The language catalog is `locales/messages.json`; `tools/generate_locales.py` generates its embedded AS3 form and checks all nine languages, placeholders and line breaks.

Requirements: Python 3.9+, Java 11+, Apache Flex with an AIR SDK installed in the same SDK directory. SDKs, game files and native assets are not included.

```powershell
python tools/generate_locales.py --check
python tools/build_a.py --sdk C:/Tools/FlexAIR --java C:/Tools/Java/bin/java.exe
```

Output: `build/a-release/RConnectMod.swf`, compile log, source/declaration hashes and SWF SHA256 in `manifest.json`. Use a new `--output` directory for each build. This never installs the output. `tools/stubs/` contains compile-only native declarations; they are externally linked and must never become runtime game replacements.

To edit translations, update all nine values in the JSON, run the generator without `--check`, then rebuild. Native aliases `uk/ja/zh-TW/zh-Hant` map to the game's `ua/jp/tw` IDs. Unknown language codes use English. Player-authored text is passed through untouched. Fixed labels shrink only when needed; explanations scroll inside the compact panel.

Historical build/patch scripts predate this source and are not the release build entry. Do not run them against installed game files. The package script accepts an already validated SWF and checks it against its manifest.
