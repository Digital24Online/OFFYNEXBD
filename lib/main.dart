import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'lib/modules/writer/writer_screen.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations;

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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1677E8),
        scaffoldBackgroundColor: const Color(0xFFF5F8FD),
        fontFamily: 'Roboto',
      ),
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
        builder: (context) => const WriterScreen(),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: SvgPicture.asset(
                'assets/branding/offynexbd_logo.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'OFFYNEXBD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                fontSize: 19,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                isBangla = !isBangla;
              });
            },
            child: Text(
              isBangla ? 'English' : 'বাংলা',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1677E8),
                      Color(0xFF174A9A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBangla
                          ? 'আপনার কাজের নতুন ঠিকানা'
                          : 'Your Workspace, Reimagined',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      isBangla
                          ? 'এক জায়গায় সব অফিস ও প্রোডাক্টিভিটি টুলস'
                          : 'All your office and productivity tools in one place.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'The Future of Office Productivity',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Text(
                isBangla ? 'আপনার অ্যাপস' : 'Your Applications',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF172B4D),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isBangla
                    ? 'আপনার প্রয়োজনীয় টুলস নির্বাচন করুন'
                    : 'Choose a tool to get started',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 17),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 650 ? 4 : 2;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: modules.length,
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 13,
                      mainAxisSpacing: 13,
                      childAspectRatio: 1.12,
                    ),
                    itemBuilder: (context, index) {
                      final module = modules[index];

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: () => openModule(module),
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: const Color(0xFFE8EDF5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 43,
                                  height: 43,
                                  decoration: BoxDecoration(
                                    color: module.color.withValues(alpha: 0.11),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    module.icon,
                                    color: module.color,
                                    size: 25,
                                  ),
                                ),
                                const SizedBox(height: 11),
                                Text(
                                  isBangla
                                      ? module.banglaName
                                      : module.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF172B4D),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isBangla
                                      ? module.banglaDescription
                                      : module.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
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
              const SizedBox(height: 25),
              Center(
                child: Text(
                  'OFFYNEXBD  •  Work Smart, Be Productive',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

