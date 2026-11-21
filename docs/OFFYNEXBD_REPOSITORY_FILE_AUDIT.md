# OFFYNEXBD — Repository File Audit

**Audited ref:** `94c18043b74ead0a1f4e38ea3e77a17a6ccdce9a`  
**Branch:** `work/writer-sheets-pdf-scan-completion-20261120`  
**Audit date:** 2026-11-21  
**Purpose:** Reconcile the actual tracked repository files with the ten-module completion blueprint. This is an inventory, not a claim that listed files or modules are complete.

## 1. Tracked-file baseline

| Area | Count |
|---|---:|
| All tracked files | 248 |
| Dart source and test files | 85 |
| Automated Dart test files | 42 |
| Bundled assets | 13 |
| Native platform files (Android/iOS/Windows/macOS) | 121 |
| Documentation/specification files | 15 |

The repository uses a generated Flutter project at its root and currently stores application Dart code under `lib/lib/`. Preserve this layout until imports, generation steps, workflows and tests are audited together.

## 2. Application source inventory

- `lib/lib/modules/pdf/pdf_reader_screen.dart`
- `lib/lib/modules/pdf/pdf_to_document_screen.dart`
- `lib/lib/modules/pdf/pdf_to_document_service.dart`
- `lib/lib/modules/sheets/sheets_analytics.dart`
- `lib/lib/modules/sheets/sheets_analytics_widgets.dart`
- `lib/lib/modules/sheets/sheets_csv_codec.dart`
- `lib/lib/modules/sheets/sheets_data_validation.dart`
- `lib/lib/modules/sheets/sheets_find_replace.dart`
- `lib/lib/modules/sheets/sheets_formula_engine.dart`
- `lib/lib/modules/sheets/sheets_import_safety.dart`
- `lib/lib/modules/sheets/sheets_pdf_export_service.dart`
- `lib/lib/modules/sheets/sheets_row_view.dart`
- `lib/lib/modules/sheets/sheets_screen.dart`
- `lib/lib/modules/sheets/sheets_workbook_codec.dart`
- `lib/lib/modules/sheets/sheets_workbook_limits.dart`
- `lib/lib/modules/sheets/sheets_xlsx_validation_codec.dart`
- `lib/lib/modules/workspace/database_field_codec.dart`
- `lib/lib/modules/workspace/database_rows_csv_codec.dart`
- `lib/lib/modules/workspace/database_rows_dialog.dart`
- `lib/lib/modules/workspace/forms_question_codec.dart`
- `lib/lib/modules/workspace/forms_response_csv_codec.dart`
- `lib/lib/modules/workspace/office_workspace_screen.dart`
- `lib/lib/modules/workspace/portable_workspace_backup_service.dart`
- `lib/lib/modules/workspace/scan_document_service.dart`
- `lib/lib/modules/workspace/slides_document_codec.dart`
- `lib/lib/modules/workspace/slides_editor_screen.dart`
- `lib/lib/modules/workspace/slides_pdf_export_service.dart`
- `lib/lib/modules/workspace/slides_preview_screen.dart`
- `lib/lib/modules/workspace/workspace_backup_codec.dart`
- `lib/lib/modules/workspace/workspace_record_codec.dart`
- `lib/lib/modules/writer/writer_content_metrics.dart`
- `lib/lib/modules/writer/writer_document_backup_service.dart`
- `lib/lib/modules/writer/writer_document_codec.dart`
- `lib/lib/modules/writer/writer_document_format_service.dart`
- `lib/lib/modules/writer/writer_docx_export_service.dart`
- `lib/lib/modules/writer/writer_page_break.dart`
- `lib/lib/modules/writer/writer_pdf_export_service.dart`
- `lib/lib/modules/writer/writer_screen.dart`
- `lib/lib/modules/writer/writer_table.dart`
- `lib/lib/modules/writer/writer_viewport.dart`
- `lib/lib/theme/offynex_theme.dart`
- `lib/main.dart`

## 3. Automated test inventory

- `test/app_info_screen_test.dart`
- `test/database_field_codec_test.dart`
- `test/database_rows_csv_codec_test.dart`
- `test/forms_question_codec_test.dart`
- `test/forms_response_csv_codec_test.dart`
- `test/office_workspace_test.dart`
- `test/offynex_theme_test.dart`
- `test/pdf_to_document_test.dart`
- `test/portable_workspace_backup_service_test.dart`
- `test/scan_document_service_test.dart`
- `test/sheets_analytics_test.dart`
- `test/sheets_csv_codec_test.dart`
- `test/sheets_data_validation_test.dart`
- `test/sheets_data_validation_widget_test.dart`
- `test/sheets_find_replace_test.dart`
- `test/sheets_formula_engine_test.dart`
- `test/sheets_freeze_top_row_test.dart`
- `test/sheets_import_safety_test.dart`
- `test/sheets_multi_worksheet_test.dart`
- `test/sheets_pdf_export_test.dart`
- `test/sheets_row_view_test.dart`
- `test/sheets_workbook_codec_test.dart`
- `test/sheets_workbook_limits_test.dart`
- `test/sheets_workbook_recovery_test.dart`
- `test/sheets_xlsx_round_trip_test.dart`
- `test/sheets_xlsx_validation_codec_test.dart`
- `test/slides_document_codec_test.dart`
- `test/slides_editor_screen_test.dart`
- `test/slides_pdf_export_test.dart`
- `test/widget_test.dart`
- `test/workspace_backup_codec_test.dart`
- `test/workspace_record_codec_test.dart`
- `test/writer_content_metrics_test.dart`
- `test/writer_document_backup_service_test.dart`
- `test/writer_document_codec_test.dart`
- `test/writer_document_format_service_regression_test.dart`
- `test/writer_document_format_service_test.dart`
- `test/writer_docx_export_test.dart`
- `test/writer_features_test.dart`
- `test/writer_library_recovery_test.dart`
- `test/writer_pdf_export_test.dart`
- `test/writer_viewport_test.dart`

Coverage inventory is not proof of feature completeness. Tests must be mapped to acceptance behavior; missing cases must be added with implementation.

## 4. Branding, typography and OCR assets

- `assets/branding/founder_profile.jpg`
- `assets/branding/offynexbd_app_icon.png`
- `assets/branding/offynexbd_icon.svg`
- `assets/branding/offynexbd_logo.svg`
- `assets/branding/offynexbd_splash.png`
- `assets/fonts/NotoSans.ttf`
- `assets/fonts/NotoSansBengali.ttf`
- `assets/fonts/NotoSerifBengali.ttf`
- `assets/fonts/OFL.txt`
- `assets/tessdata/.gitkeep`
- `assets/tessdata/ben.traineddata`
- `assets/tessdata/eng.traineddata`
- `assets/tessdata_config.json`

Preserve approved Option 2 branding, founder portrait and Bengali font/OCR assets. Verify licensing, shaping and rendered output separately; asset presence alone does not prove correct rendering.

## 5. Build, dependency and platform configuration

### Root and workflow configuration

- `.github/workflows/bootstrap.yml`
- `.gitignore`
- `WRITER_MASTER_REQUIREMENTS.md`
- `analysis_options.yaml`
- `backend/README.md`
- `database/README.md`
- `pubspec.lock`
- `pubspec.yaml`

### Native platform project files

- `android/.gitignore`
- `android/app/build.gradle.kts`
- `android/app/src/debug/AndroidManifest.xml`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/offynexbd/offynexbd/MainActivity.kt`
- `android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png`
- `android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png`
- `android/app/src/main/res/drawable-nodpi/offynexbd_splash.png`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png`
- `android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png`
- `android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png`
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable/offynexbd_launcher_icon.xml`
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- `android/app/src/main/res/values-night/styles.xml`
- `android/app/src/main/res/values/colors.xml`
- `android/app/src/main/res/values/offynexbd_colors.xml`
- `android/app/src/main/res/values/styles.xml`
- `android/app/src/profile/AndroidManifest.xml`
- `android/build.gradle.kts`
- `android/gradle.properties`
- `android/gradle/wrapper/gradle-wrapper.properties`
- `android/settings.gradle.kts`
- `ios/.gitignore`
- `ios/Flutter/AppFrameworkInfo.plist`
- `ios/Flutter/Debug.xcconfig`
- `ios/Flutter/Release.xcconfig`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`
- `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`
- `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- `ios/Runner.xcworkspace/contents.xcworkspacedata`
- `ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`
- `ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `ios/Runner/Base.lproj/Main.storyboard`
- `ios/Runner/Info.plist`
- `ios/Runner/Runner-Bridging-Header.h`
- `ios/Runner/SceneDelegate.swift`
- `ios/RunnerTests/RunnerTests.swift`
- `macos/.gitignore`
- `macos/Flutter/Flutter-Debug.xcconfig`
- `macos/Flutter/Flutter-Release.xcconfig`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `macos/Runner.xcodeproj/project.pbxproj`
- `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`
- `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- `macos/Runner.xcworkspace/contents.xcworkspacedata`
- `macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist`
- `macos/Runner/AppDelegate.swift`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png`
- `macos/Runner/Base.lproj/MainMenu.xib`
- `macos/Runner/Configs/AppInfo.xcconfig`
- `macos/Runner/Configs/Debug.xcconfig`
- `macos/Runner/Configs/Release.xcconfig`
- `macos/Runner/Configs/Warnings.xcconfig`
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Info.plist`
- `macos/Runner/MainFlutterWindow.swift`
- `macos/Runner/Release.entitlements`
- `macos/RunnerTests/RunnerTests.swift`
- `windows/.gitignore`
- `windows/CMakeLists.txt`
- `windows/flutter/CMakeLists.txt`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugin_registrant.h`
- `windows/flutter/generated_plugins.cmake`
- `windows/runner/CMakeLists.txt`
- `windows/runner/Runner.rc`
- `windows/runner/flutter_window.cpp`
- `windows/runner/flutter_window.h`
- `windows/runner/main.cpp`
- `windows/runner/resource.h`
- `windows/runner/resources/app_icon.ico`
- `windows/runner/runner.exe.manifest`
- `windows/runner/utils.cpp`
- `windows/runner/utils.h`
- `windows/runner/win32_window.cpp`
- `windows/runner/win32_window.h`

Android CI does not establish iOS, Windows or macOS build/runtime acceptance. Keep those platform gates open until independently built and tested.

## 6. Specification and project documentation

- `docs/OFFYNEXBD_COMPLETION_BLUEPRINT.md`
- `docs/OFFYNEXBD_GLOBAL_DESIGN_SYSTEM.md`
- `docs/OFFYNEXBD_REPOSITORY_FILE_AUDIT.md`
- `modules/ai/README.md`
- `modules/cloud/README.md`
- `modules/database/README.md`
- `modules/fonts/README.md`
- `modules/forms/README.md`
- `modules/pdf/README.md`
- `modules/scan/README.md`
- `modules/sheets/README.md`
- `modules/slides/README.md`
- `modules/writer/README.md`
- `modules/writer/writer_table.dart`
- `security/README.md`

Also retain root `README.md`, `OFFYNEXBD_MASTER_PROGRESS.md` and `WRITER_MASTER_REQUIREMENTS.md` as project navigation/history/requirements records.

## 7. Cross-check findings and rules

- Root `pubspec.yaml` declares Flutter dependencies and bundled branding, Bengali fonts and OCR data. Dependency upgrades require compatibility and license review.
- CI generates font/OCR and branding assets, runs Analyze and configured tests, then signs and verifies an Android APK. Check workflow success on the exact final source commit.
- The application entry point exposes all ten modules. Slides, Fonts, AI Assistant, Cloud, Forms, Scan and Database still share `office_workspace_screen.dart`; a shared workspace shell or local records do not establish full module capability.
- Slides has a dedicated editable text-slide workflow and versioned storage with legacy newline compatibility. The object/canvas editor and PPTX/ODP remain open.
- Existing Writer, Sheets, PDF, Scan, backup/recovery, branding and App Info work must be preserved while remaining capabilities are implemented.
- Backend and database architecture documents are planning records; they do not establish a provisioned backend, remote database, authentication or cloud service.
- Module specifications and the completion blueprint remain the authoritative feature backlog. Refresh this inventory whenever files are added, removed or moved.

## 8. Integrated implementation gate

Before declaring a module complete, connect every user-visible control to a real operation, preserve existing data formats and backward compatibility, add regression tests for changed behavior, run Analyze and the complete test suite, build and verify the signed Android package on the same commit, and record physical-device / interoperability / platform acceptance separately.
