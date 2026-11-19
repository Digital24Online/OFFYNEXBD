import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'lib/modules/writer/writer_screen.dart';
import 'lib/modules/sheets/sheets_screen.dart';
import 'lib/modules/pdf/pdf_to_document_screen.dart';
import 'lib/modules/workspace/office_workspace_screen.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/theme/offynex_theme.dart';

void main() {
  runApp(const OFFYNEXBDApp());
}

class OFFYNEXBDApp extends StatelessWidget {
  const OFFYNEXBDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OFFYNEXBD',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        ...FlutterQuillLocalizations.localizationsDelegates,
      ],
      supportedLocales:
          FlutterQuillLocalizations.supportedLocales,
      theme: OFFYNEXTheme.light,
      home: const HomeScreen(),
    );
  }
}

class OfficeModule {
  final String name;
  final String banglaName;
  final String description;
  final String banglaDescription;
  final IconData icon;
  final Color color;

  const OfficeModule({
    required this.name,
    required this.banglaName,
    required this.description,
    required this.banglaDescription,
    required this.icon,
    required this.color,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isBangla = true;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('offynex_language_bangla_v1');
    if (saved != null && mounted) setState(() => isBangla = saved);
  }

  Future<void> _toggleLanguage() async {
    final next = !isBangla;
    setState(() => isBangla = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offynex_language_bangla_v1', next);
  }

  final List<OfficeModule> modules = const [
    OfficeModule(
      name: 'Writer',
      banglaName: 'রাইটার',
      description: 'Create and edit documents',
      banglaDescription: 'ডকুমেন্ট তৈরি ও সম্পাদনা',
      icon: Icons.description_rounded,
      color: Color(0xFF2878DB),
    ),
    OfficeModule(
      name: 'Sheets',
      banglaName: 'শিটস',
      description: 'Spreadsheets and calculations',
      banglaDescription: 'হিসাব ও স্প্রেডশিট',
      icon: Icons.table_chart_rounded,
      color: Color(0xFF159B68),
    ),
    OfficeModule(
      name: 'Slides',
      banglaName: 'স্লাইডস',
      description: 'Create presentations',
      banglaDescription: 'প্রেজেন্টেশন তৈরি',
      icon: Icons.slideshow_rounded,
      color: Color(0xFFE58A28),
    ),
    OfficeModule(
      name: 'PDF',
      banglaName: 'পিডিএফ',
      description: 'Read, edit and manage PDFs',
      banglaDescription: 'পিডিএফ পড়া ও সম্পাদনা',
      icon: Icons.picture_as_pdf_rounded,
      color: Color(0xFFE34B50),
    ),
    OfficeModule(
      name: 'Fonts',
      banglaName: 'ফন্টস',
      description: 'Fonts and typography',
      banglaDescription: 'ফন্ট ব্যবস্থাপনা',
      icon: Icons.font_download_rounded,
      color: Color(0xFF8055D9),
    ),
    OfficeModule(
      name: 'AI Assistant',
      banglaName: 'এআই সহকারী',
      description: 'Smart productivity assistant',
      banglaDescription: 'স্মার্ট কাজের সহকারী',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF0C9CA6),
    ),
    OfficeModule(
      name: 'Cloud',
      banglaName: 'ক্লাউড',
      description: 'Store and sync your files',
      banglaDescription: 'ফাইল সংরক্ষণ ও সিঙ্ক',
      icon: Icons.cloud_rounded,
      color: Color(0xFF4386D9),
    ),
    OfficeModule(
      name: 'Forms',
      banglaName: 'ফর্মস',
      description: 'Create digital forms',
      banglaDescription: 'ডিজিটাল ফর্ম তৈরি',
      icon: Icons.dynamic_form_rounded,
      color: Color(0xFFCB7B35),
    ),
    OfficeModule(
      name: 'Scan',
      banglaName: 'স্ক্যান',
      description: 'Scan documents and OCR',
      banglaDescription: 'ডকুমেন্ট স্ক্যান ও OCR',
      icon: Icons.document_scanner_rounded,
      color: Color(0xFF347F9D),
    ),
    OfficeModule(
      name: 'Database',
      banglaName: 'ডেটাবেস',
      description: 'Organize and manage data',
      banglaDescription: 'তথ্য সংরক্ষণ ও ব্যবস্থাপনা',
      icon: Icons.storage_rounded,
      color: Color(0xFF6875B8),
    ),
  ];

  
void openModule(OfficeModule module) {
  if (module.name == 'Writer') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriterScreen(isBangla: isBangla),
      ),
    );
    return;
  }

  if (module.name == 'PDF') {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PdfToDocumentScreen(isBangla: isBangla)));
    return;
  }

  if (module.name == 'Sheets') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SheetsScreen(isBangla: isBangla),
      ),
    );
    return;
  }

  if (const ['Slides', 'Fonts', 'AI Assistant', 'Cloud', 'Forms', 'Scan', 'Database']
      .contains(module.name)) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfficeWorkspaceScreen(
          module: module.name,
          isBangla: isBangla,
        ),
      ),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        isBangla
            ? '${module.banglaName} মডিউলের কাজ শিগগিরই শুরু হবে।'
            : '${module.name} module is coming soon.',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
  

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 900 ? 36.0 : 20.0;

    return Scaffold(
      backgroundColor: OFFYNEXTheme.canvas,
      appBar: AppBar(
        backgroundColor: OFFYNEXTheme.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: horizontalPadding,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: OFFYNEXTheme.border),
              ),
              child: SvgPicture.asset('assets/branding/offynexbd_icon.svg', fit: BoxFit.contain),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('OFFYNEXBD', style: TextStyle(color: OFFYNEXTheme.ink, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.35)),
                Text('OFFICE PRODUCTIVITY SUITE', style: TextStyle(color: OFFYNEXTheme.muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.05)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isBangla ? 'অ্যাপ ইনফো' : 'App Info',
            icon: const Icon(Icons.info_outline_rounded, color: OFFYNEXTheme.ink),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AppInfoScreen(isBangla: isBangla)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: OutlinedButton.icon(
              onPressed: _toggleLanguage,
              icon: const Icon(Icons.language_rounded, size: 17),
              label: Text(isBangla ? 'English' : 'বাংলা'),
              style: OutlinedButton.styleFrom(
                foregroundColor: OFFYNEXTheme.ink,
                side: const BorderSide(color: OFFYNEXTheme.border),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          key: const ValueKey('offynex-home-scroll'),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 30),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(width >= 600 ? 30 : 23),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF142C55), Color(0xFF1769B5), Color(0xFF2389C8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF174F91).withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 14)),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -34,
                          top: -52,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 25),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 42,
                          bottom: -82,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.055)),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                              ),
                              child: Text(
                                isBangla ? 'আপনার স্মার্ট ওয়ার্কস্পেস' : 'YOUR SMART WORKSPACE',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                              ),
                            ),
                            const SizedBox(height: 19),
                            Text(
                              isBangla ? 'আপনার সব কাজ,\nএক জায়গায়।' : 'Everything you need.\nAll in one place.',
                              style: TextStyle(color: Colors.white, fontSize: width >= 600 ? 34 : 29, height: 1.16, fontWeight: FontWeight.w800, letterSpacing: -0.55),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Text(
                                isBangla
                                    ? 'ডকুমেন্ট, হিসাব, প্রেজেন্টেশন, PDF ও আরও অনেক কিছু—একটি সমন্বিত প্ল্যাটফর্মে।'
                                    : 'Documents, spreadsheets, presentations, PDF and more in one connected productivity suite.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 14, height: 1.55),
                              ),
                            ),
                            const SizedBox(height: 21),
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD27A), size: 17),
                                const SizedBox(width: 8),
                                Text('OFFYNEXBD  •  The Future of Office Productivity', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isBangla ? 'আপনার অ্যাপস' : 'Your Applications', style: const TextStyle(color: OFFYNEXTheme.ink, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.35)),
                            const SizedBox(height: 5),
                            Text(isBangla ? 'কাজ শুরু করতে একটি টুল নির্বাচন করুন' : 'Choose a tool to get started', style: const TextStyle(color: OFFYNEXTheme.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(color: OFFYNEXTheme.blueSoft, borderRadius: BorderRadius.circular(20)),
                        child: Text(isBangla ? '১০টি টুল' : '10 TOOLS', style: const TextStyle(color: OFFYNEXTheme.blue, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760 ? 4 : constraints.maxWidth >= 560 ? 3 : 2;
                      return GridView.builder(
                        key: const ValueKey('offynex-module-grid'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: modules.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: columns == 4 ? 1.18 : 1.22,
                        ),
                        itemBuilder: (context, index) {
                          final module = modules[index];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => openModule(module),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: OFFYNEXTheme.border),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFF243B5A).withValues(alpha: 0.035), blurRadius: 15, offset: const Offset(0, 6)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(color: module.color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(15)),
                                          child: Icon(module.icon, color: module.color, size: 25),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.arrow_outward_rounded, size: 17, color: OFFYNEXTheme.muted.withValues(alpha: 0.7)),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      isBangla ? module.banglaName : module.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: OFFYNEXTheme.ink, fontSize: 15, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      isBangla ? module.banglaDescription : module.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: OFFYNEXTheme.muted, fontSize: 11, height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Column(
                      children: [
                        const Text('OFFYNEXBD  •  The Future of Office Productivity', textAlign: TextAlign.center, style: TextStyle(color: OFFYNEXTheme.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 7),
                        Text(isBangla ? 'একটি সমন্বিত প্রোডাক্টিভিটি অভিজ্ঞতা' : 'One connected productivity experience', textAlign: TextAlign.center, style: const TextStyle(color: OFFYNEXTheme.muted, fontSize: 10)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key, required this.isBangla});

  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF14233B);
    const muted = Color(0xFF66758B);
    const blue = Color(0xFF1769B5);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: Text(isBangla ? 'অ্যাপ ইনফো' : 'App Info'),
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF082B68), Color(0xFF0877C9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: SvgPicture.asset(
                      'assets/branding/offynexbd_icon.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'OFFYNEXBD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The Future of Office Productivity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFFD66B),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isBangla
                        ? 'একটি সমন্বিত অফিস প্রোডাক্টিভিটি প্ল্যাটফর্ম'
                        : 'An integrated office productivity platform',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE3EAF3)),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(80),
                    child: Image.memory(
                      base64Decode(_founderPortraitBase64),
                      width: 116,
                      height: 116,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 116,
                        height: 116,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE7F0FC),
                        ),
                        child: const Text(
                          'MD',
                          style: TextStyle(
                            color: blue,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'MD PIYARUL ISLAM',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isBangla ? 'প্রতিষ্ঠাতা ও মূল নির্মাতা' : 'Founder & Original Creator',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: muted),
                      SizedBox(width: 4),
                      Text('Rajshahi, Bangladesh', style: TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE3EAF3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, color: blue, size: 20),
                      const SizedBox(width: 9),
                      Text(
                        isBangla ? 'নির্মাতার ঘোষণা' : 'Creator Statement',
                        style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isBangla
                        ? 'OFFYNEXBD-এর মূল ধারণা, পরিকল্পনা ও নির্মাণ উদ্যোগের স্রষ্টা MD PIYARUL ISLAM। এই পরিচয় অ্যাপের নির্মাতা-স্বীকৃতি হিসেবে সংরক্ষিত।'
                        : 'MD PIYARUL ISLAM is the originator of the OFFYNEXBD concept and the initiative behind its planning and development. This in-app statement records the declared creator attribution.',
                    style: const TextStyle(color: muted, fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                '© 2026 OFFYNEXBD. All Rights Reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

const String _founderPortraitBase64 = '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';
