# Project Behavioral Rules & Guidelines

## 1. Strict Full-Stack Completion Mandate
- Whenever implementing, migrating, or integrating a new feature, module, or database entity, you MUST implement the feature across BOTH the Flutter mobile application and the PHP web administration panel.
- Do not stop after completing only the mobile app or only the APIs. You must proactively generate the corresponding UI screens, forms, and reporting pages on the web panel to ensure feature parity.
- Verification: Before concluding a feature-level task, explicitly verify that both ends (Mobile + Web UI + Web API) are complete and functional.

## 2. File Reading & Searching Tool Preference
- Use built-in tools only: Always use `view_file` to read file contents, `grep_search` to search within files, and `find_by_name` to search for files by name.
- NEVER use `run_command` for file I/O (no python -c, cat, grep, Get-Content, Select-String). `run_command` should only be used for actual compilation, testing, building, or running application code.

## 3. Strict Version Control & Release Automation Protocol (Minaret Modern)
- **Version Bumping on Every Update**:
  - For every feature addition or user-requested change, bump the semantic version in `flutter_app/pubspec.yaml` (format: `MAJOR.MINOR.PATCH+BUILD`).
  - Every compiled release build must increment the `+BUILD` code (e.g. `1.1.0+2`).
  - Document all additions, modifications, and fixes in `CHANGELOG.md`.
- **Professional Release Brand Assets**:
  - Always set localized descriptive label in `AndroidManifest.xml` (e.g. `Minaret Modern - اوقاتِ نماز و قبلہ`).
  - Provide a branded, themed dark splash background (`launch_background.xml` with color `#0A0F1D` and centered vector logo).
  - Provide adaptive launcher icons with vector foreground and themed background.
- **Production Artifacts Organization**:
  - Every compiled release APK must be placed in the project root with both a versioned filename (`Minaret_Modern_vX.Y.Z.apk`) and a standard filename (`Minaret_Modern.apk`).
