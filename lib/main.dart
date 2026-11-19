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
              child: SvgPicture.asset('assets/branding/offynexbd_logo.svg', fit: BoxFit.contain),
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
                      'assets/branding/offynexbd_logo.svg',
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
                    'Work Smart, Be Productive',
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
                      errorBuilder: (_, __, ___) => Container(
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
