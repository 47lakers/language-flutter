import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../config/environment.dart';
import '../main.dart';
import 'stats_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// GuestHomePage provides the same UI as HomePage but disables saving and stats.
class GuestHomePage extends StatefulWidget {
  const GuestHomePage({super.key});

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {
  late FlutterTts _flutterTts;
    List<String> _selectedTenses = ['Present'];

    Widget _buildTenseChips() {
      final tenses = ['Past', 'Present', 'Future'];
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: tenses.map((tense) {
          final isSelected = _selectedTenses.contains(tense);
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(tense),
              selected: isSelected,
              onSelected: null, // disables interaction
              selectedColor: const Color(0xFF6366F1).withOpacity(0.15),
              backgroundColor: Theme.of(context).cardColor,
              checkmarkColor: Colors.transparent,
              disabledColor: Theme.of(context).disabledColor.withOpacity(0.1),
            ),
          );
        }).toList(),
      );
    }
  late final ApiService _api;
  bool _isLoading = false;
  String? _error;
  List<dynamic>? _sentences;
  int _currentSentenceIndex = 0;
  bool _showTranslation = false;
  bool _showTranslationFirst = false;
  int _phrasesLearned = 0;
  int _setsUsed = 0;
  static const int _maxSets = 2;

  String _firstLanguage = 'Spanish';
  String _secondLanguage = 'English';
  String _level = 'A2';
  final _verbFocusController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: EnvironmentConfig.baseUrl, appKey: EnvironmentConfig.apiKey);
    _flutterTts = FlutterTts();
    _initTts();
  }

  @override
  void dispose() {
    _verbFocusController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setVolume(1.0);
    if (!kIsWeb && Platform.isIOS) {
      await _flutterTts.setSpeechRate(0.5);
    } else {
      await _flutterTts.setSpeechRate(1.0);
    }
    await _flutterTts.setPitch(1.0);
    final languageMap = {
      'English': 'en-US',
      'Spanish': 'es-ES',
      'French': 'fr-FR',
      'German': 'de-DE',
      'Italian': 'it-IT',
      'Portuguese': 'pt-PT',
      'Russian': 'ru-RU',
      'Japanese': 'ja-JP',
      'Chinese': 'zh-CN',
      'Arabic': 'ar-SA',
      'Korean': 'ko-KR',
      'Dutch': 'nl-NL',
      'Swedish': 'sv-SE',
      'Polish': 'pl-PL',
      'Greek': 'el-GR',
    };
    final locale = languageMap[_firstLanguage] ?? 'es-ES';
    await _flutterTts.setLanguage(locale);
    if (!kIsWeb && Platform.isIOS) {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }
  }

  Future<void> _speak(String text, String language) async {
    await _flutterTts.stop();
    final languageMap = {
      'English': 'en-US',
      'Spanish': 'es-ES',
      'French': 'fr-FR',
      'German': 'de-DE',
      'Italian': 'it-IT',
      'Portuguese': 'pt-PT',
      'Russian': 'ru-RU',
      'Japanese': 'ja-JP',
      'Chinese': 'zh-CN',
      'Arabic': 'ar-SA',
      'Korean': 'ko-KR',
      'Dutch': 'nl-NL',
      'Swedish': 'sv-SE',
      'Polish': 'pl-PL',
      'Greek': 'el-GR',
    };
    final locale = languageMap[language] ?? 'en-US';
    await _flutterTts.setLanguage(locale);
    if (language == 'Spanish' && !kIsWeb && Platform.isIOS) {
      await _flutterTts.setVoice({"name": "Monica", "locale": "es-ES"});
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await _flutterTts.speak(text);
  }

  void _clearSentenceCache() {
    setState(() {
      _sentences = null;
      _currentSentenceIndex = 0;
      _showTranslation = false;
    });
  }

  Future<void> _fetchNewBatch() async {
    if (_setsUsed >= _maxSets) {
      setState(() {
        _error = "Guest mode: Only $_maxSets sets per day. Sign up for more!";
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tenses = _selectedTenses.map((t) => t.toLowerCase()).toList();
      final focusVerbs = _verbFocusController.text
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
      final res = await _api.generateBatch(
        targetLanguage: _firstLanguage.toLowerCase(),
        translationLanguage: _secondLanguage.toLowerCase(),
        focusVerbs: focusVerbs,
        level: _level,
        tenses: tenses,
        batchSize: 20,
      );
      setState(() {
        _sentences = res['items'] as List?;
        _currentSentenceIndex = 0;
        _showTranslation = false;
        _setsUsed++;
        if (_sentences == null || _sentences!.isEmpty) {
          _error = 'No phrases came back — please try again.';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _newSentence() {
    if (_sentences == null || _sentences!.isEmpty) {
      _fetchNewBatch();
    } else {
      setState(() {
        _phrasesLearned++;
        _currentSentenceIndex++;
        _showTranslation = false;
        if (_currentSentenceIndex >= _sentences!.length) {
          _currentSentenceIndex = 0;
          _fetchNewBatch();
        }
      });
    }
  }

  void _toggleTranslation() {
    setState(() {
      _showTranslation = !_showTranslation;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSentence = _sentences != null && _sentences!.isNotEmpty 
        ? _sentences![_currentSentenceIndex] 
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DailyFrase (Guest)'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Back to Login', style: TextStyle(color: Colors.white)),
            onPressed: () {
              if (kIsWeb) {
                try {
                  html.window.location.reload();
                } catch (_) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } else {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 200,
                      maxWidth: 800,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_open, color: Colors.blue, size: 28),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Guest mode: Try out DailyFrase!\nSign up to save progress and unlock more.',
                                      style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _newSentence,
                                  icon: const Icon(Icons.arrow_forward, size: 18),
                                  label: const Text('New'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: currentSentence != null ? _toggleTranslation : null,
                                  icon: const Icon(Icons.format_quote, size: 18),
                                  label: const Text('Reveal'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 48),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ] else if (currentSentence != null) ...[
                            Text(
                              'Verb: \\${currentSentence['verb']}'.toUpperCase(),
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color, letterSpacing: 2),
                            ),
                            const SizedBox(height: 8),
                            Text('Phrases learned: \\$_phrasesLearned', style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6))),
                            const SizedBox(height: 48),
                            _buildSentenceCard(_showTranslationFirst ? _secondLanguage : _firstLanguage, _showTranslationFirst ? (currentSentence['translation_text'] ?? 'No text') : (currentSentence['target_text'] ?? 'No text'), Theme.of(context).cardColor),
                            if (_showTranslation) ...[
                              const SizedBox(height: 24),
                              _buildSentenceCard(_showTranslationFirst ? _firstLanguage : _secondLanguage, _showTranslationFirst ? (currentSentence['target_text'] ?? 'No translation') : (currentSentence['translation_text'] ?? 'No translation'), Theme.of(context).cardColor),
                            ],
                          ] else if (_isLoading) ...[
                            const CircularProgressIndicator(),
                          ] else ...[
                            Column(
                              children: [
                                Text('Tap "New" to start your session', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 16)),
                                const SizedBox(height: 8),
                                Text('Guest mode: 2 sets/day, 40 phrases max', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.4), fontSize: 13)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ), // <-- Add this closing parenthesis for Padding
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final themeProvider = context.watch<ThemeProvider>();
    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 50),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Language you're learning"),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _firstLanguage,
                    items: [
                      'Spanish',
                      'French',
                      'German',
                      'Italian',
                      'Portuguese',
                      'Russian',
                      'Japanese',
                      'Chinese',
                      'Arabic',
                      'Korean',
                      'Dutch',
                      'Swedish',
                      'Polish',
                      'Greek',
                    ],
                    onChanged: (val) {
                      setState(() => _firstLanguage = val!);
                      _clearSentenceCache();
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Verb focus'),
                  const SizedBox(height: 8),
                  AbsorbPointer(
                    absorbing: true,
                    child: Opacity(
                      opacity: 0.5,
                      child: TextField(
                        controller: _verbFocusController,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'verb1, verb2, verb3',
                          hintStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                          filled: true,
                          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Tenses'),
                  const SizedBox(height: 12),
                  AbsorbPointer(
                    absorbing: true,
                    child: Opacity(
                      opacity: 0.5,
                      child: _buildTenseChips(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AbsorbPointer(
                    absorbing: true,
                    child: Opacity(
                      opacity: 0.5,
                      child: _buildDropdown(
                        value: _level,
                        items: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
                        onChanged: (_) {}, // no-op handler to satisfy type
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: Text(
                      'Show $_secondLanguage First',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    subtitle: Text(
                      'See the translation and try to recall the phrase',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.55),
                      ),
                    ),
                    value: _showTranslationFirst,
                    onChanged: (value) {
                      setState(() {
                        _showTranslationFirst = value;
                        _showTranslation = false;
                      });
                    },
                    activeColor: const Color(0xFF6366F1),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    value: themeProvider.isDarkMode,
                    onChanged: (value) => themeProvider.toggleTheme(),
                    activeColor: const Color(0xFF6366F1),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: Theme.of(context).cardColor,
        icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).iconTheme.color?.withOpacity(0.6)),
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSentenceCard(String label, String text, Color color) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.volume_up,
                    size: 18,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                  ),
                  onPressed: () => _speak(text, label),
                  tooltip: 'Listen to pronunciation',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}
