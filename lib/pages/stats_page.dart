import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/user_database_service.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistics')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Learning Stats'),
        elevation: 0,
      ),
      body: StreamBuilder<UserData?>(
        stream: UserDatabaseService().getUserDataStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('No data yet. Complete some sentences!'),
            );
          }

          final userData = snapshot.data!;
          
          // Group verbs by language
          final verbsByLanguage = <String, List<MapEntry<String, VerbDetails>>>{};
          for (var entry in userData.verbsLearned.entries) {
            final language = entry.value.language.isEmpty ? 'Unknown' : entry.value.language;
            verbsByLanguage.putIfAbsent(language, () => []).add(entry);
          }
          
          // Sort verbs within each language by total
          for (var language in verbsByLanguage.keys) {
            verbsByLanguage[language]!.sort((a, b) => b.value.total.compareTo(a.value.total));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Stats Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn(
                              'Total Sentences',
                              userData.totalSentences.toString(),
                              Icons.library_books,
                            ),
                            _buildStatColumn(
                              'Verbs Learned',
                              userData.verbsLearned.length.toString(),
                              Icons.text_fields,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Verbs Section
                if (userData.verbsLearned.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Complete sentences to see verb statistics here!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                else ...verbsByLanguage.entries.map((languageEntry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.language,
                            color: const Color(0xFF6366F1),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            languageEntry.key,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D3748),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${languageEntry.value.length} verbs',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...languageEntry.value.map((entry) => _buildVerbCard(
                            context,
                            entry.key,
                            entry.value,
                          )),
                      const SizedBox(height: 24),
                    ],
                  )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: const Color(0xFF6366F1)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildVerbCard(BuildContext context, String verb, VerbDetails details) {
    final tensesList = details.tenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  verb,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${details.total} total',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (tensesList.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tensesList.map((tense) {
                  return _buildTenseChip(tense.key, tense.value);
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTenseChip(String tense, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D3748),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tense,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF818CF8),
            ),
          ),
        ],
      ),
    );
  }
}
