import 'package:flutter/material.dart';
import 'package:learningneeds_summary/screens/input_page.dart';
import 'package:learningneeds_summary/screens/generate_page.dart';
import 'package:learningneeds_summary/table_page.dart';

class TitlePage extends StatefulWidget {
  @override
  _TitlePageState createState() => _TitlePageState();
}

class _TitlePageState extends State<TitlePage> {
  String selectedPage = 'Home';

  void _onPageSelected(String page) {
    setState(() {
      selectedPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 135,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 241, 246, 248),
              border: Border(right: BorderSide(color: Colors.white, width: 2)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Image.asset(
                  'assets/pgp_logo.png',
                  height: 85,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 30),
                _buildSidebarItem(
                  icon: Icons.home,
                  label: 'Home',
                  page: TitlePage(),
                  pageKey: 'Home',
                ),
                _buildSidebarItem(
                  icon: Icons.input,
                  label: 'Input Data',
                  page: InputPage(),
                  pageKey: 'Input Data',
                ),
                _buildSidebarItem(
                  icon: Icons.description,
                  label: 'Generate Report',
                  page: GeneratePage(),
                  pageKey: 'Generate Report',
                ),
                _buildSidebarItem(
                  icon: Icons.table_chart,
                  label: 'View Table',
                  page: TablePage(),
                  pageKey: 'View Table',
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Container(
              color: const Color.fromARGB(255, 241, 246, 248),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double fixedTop = constraints.maxHeight * 0.25;

                  return Stack(
                    children: [
                      // Title text (fixed position)
                      Positioned(
                        left: 30.0,
                        top: fixedTop,
                        child: const Text(
                          'ILDP Learning Needs\n Summary System',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 55,
                            fontWeight: FontWeight.bold,
                            color:
                                Colors.black, // Changed to black for visibility
                          ),
                        ),
                      ),

                      Positioned(
                        right: 20.0,
                        top: 90,
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 8,
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                            width: 520,
                            height: 350,
                            child: Image.asset(
                              'assets/picture.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),

                      // Bottom text + button
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 54.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Start Generating your Excel File?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GeneratePage(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                      255, 40, 91, 167), // A nice blue tone
                                  foregroundColor: Colors.white, // Text color
                                  elevation: 6,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 30, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: const Text('Generate Excel File'),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right image card (fixed position)
                    ],
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required Widget page,
    required String pageKey,
  }) {
    final bool isSelected = selectedPage == pageKey;
    return GestureDetector(
      onTap: () {
        _onPageSelected(pageKey);
        if (!isSelected) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        }
      },
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color.fromARGB(255, 193, 211, 228)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 17),
            child: Icon(
              icon,
              color: isSelected ? Colors.black : Colors.black54,
              size: 25,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.black54,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
