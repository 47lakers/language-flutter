import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/user_database_service.dart';
import '../config/environment.dart';
import '../main.dart';
import 'stats_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ApiService _api;
  late final UserDatabaseService _userDb;
  late FlutterTts _flutterTts;
  bool _isLoading = false;
  String? _error;
  List<dynamic>? _sentences;
  int _currentSentenceIndex = 0;
  bool _showTranslation = false;
  int _phrasesLearned = 0;
  late final DateTime _mountTime; // Track when page was mounted

  // Settings
  String _firstLanguage = 'Spanish';
  String _secondLanguage = 'English';
  String _level = 'A2';
  List<String> _selectedTenses = ['Present'];
  final _verbFocusController = TextEditingController();

  void _clearSentenceCache() {
    setState(() {
      _sentences = null;
      _currentSentenceIndex = 0;
      _showTranslation = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _mountTime = DateTime.now(); // Record mount time
    print('🏠 HomePage initState called at $_mountTime');
    try {
      _api = ApiService(baseUrl: EnvironmentConfig.baseUrl, appKey: EnvironmentConfig.apiKey);
      _userDb = UserDatabaseService();
      
      // Initialize TTS
      _flutterTts = FlutterTts();
      _initTts();
      
      // Listen to verb focus changes and clear cache
      _verbFocusController.addListener(() {
        _clearSentenceCache();
      });
      
      print('✅ HomePage initialization complete');
    } catch (e) {
      print('❌ HomePage init error: $e');
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setVolume(1.0);
    
    // iOS uses different speech rate scale: 0.0-1.0 where 0.5 is normal
    // Android/Web: 0.5-2.0 where 1.0 is normal
    if (!kIsWeb && Platform.isIOS) {
      await _flutterTts.setSpeechRate(0.5); // Normal speed on iOS
    } else {
      await _flutterTts.setSpeechRate(1.0); // Normal speed on Android/Web
    }
    
    await _flutterTts.setPitch(1.0);
    
    // Set default language based on first language setting to prevent first-sentence English voice bug
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
    
    // iOS-specific settings for audio to work on phone
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

  @override
  void dispose() {
    print('🏠 HomePage dispose called');
    _verbFocusController.dispose();
    _flutterTts.stop();
    super.dispose();
  }



  Future<void> _fetchNewBatch() async {
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
        // The API returns data under 'items' key, not 'sentences'
        _sentences = res['items'] as List?;
        _currentSentenceIndex = 0;
        _showTranslation = false;
        
        if (_sentences == null || _sentences!.isEmpty) {
          _error = 'No sentences returned from API';
        }
      });
    } on ApiException catch (e) {
      setState(() {
        _error = 'Server error ${e.status}: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _error = 'Request failed: $e';
        print('Error details: $e');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextSentence() async {
    if (_sentences != null && _sentences!.isNotEmpty) {
      final currentSentence = _sentences![_currentSentenceIndex];
      final verb = currentSentence['verb'] as String? ?? '';
      final tense = currentSentence['tense'] as String? ?? 'present';
      
      // Move to next sentence in the batch
      setState(() {
        _phrasesLearned++;
        _currentSentenceIndex++;
        _showTranslation = false;
        
        // If we've gone through all sentences, fetch a new batch
        if (_currentSentenceIndex >= _sentences!.length) {
          _currentSentenceIndex = 0;
          _fetchNewBatch();
        }
      });
      
      // Record in database
      final auth = context.read<AuthService>();
      if (auth.currentUser != null && verb.isNotEmpty && tense.isNotEmpty) {
        print('Recording: verb=$verb, tense=$tense, uid=${auth.currentUser!.uid}');
        try {
          await _userDb.recordSentenceComplete(
            auth.currentUser!.uid,
            verb.toLowerCase(),
            tense.toLowerCase(),
            _firstLanguage,
          );
          print('Successfully recorded sentence');
        } catch (e) {
          print('Error recording sentence: $e');
        }
      } else if (tense.isEmpty) {
        print('Skipping recording: tense is empty for verb=$verb');
      }
    } else {
      // No sentences yet, fetch the first batch
      _fetchNewBatch();
    }
  }

  void _skipSentence() {
    if (_sentences != null && _sentences!.isNotEmpty) {
      // Move to next sentence WITHOUT incrementing phrases learned
      setState(() {
        _currentSentenceIndex++;
        _showTranslation = false;
        
        // If we've gone through all sentences, fetch a new batch
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

  Future<void> _speak(String text, String language) async {
    // Stop any ongoing speech first
    await _flutterTts.stop();
    
    // Map language names to locale codes
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
    
    // Always set language before speaking to ensure correct voice
    await _flutterTts.setLanguage(locale);
    
    // Set a better quality voice for Spanish (female voice sounds more natural)
    if (language == 'Spanish' && !kIsWeb && Platform.isIOS) {
      await _flutterTts.setVoice({"name": "Monica", "locale": "es-ES"});
    }
    
    // Small delay to ensure language change is applied
    await Future.delayed(const Duration(milliseconds: 300));
    
    await _flutterTts.speak(text);
  }


  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final themeProvider = context.watch<ThemeProvider>();
    final currentSentence = _sentences != null && _sentences!.isNotEmpty 
        ? _sentences![_currentSentenceIndex] 
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
              ),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isLoading ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: _isLoading ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isLoading ? 'CONNECTING' : 'CONNECTED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isLoading ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () async {
                    if (kIsWeb) {
                      // On web, sign out then reload to clear everything
                      await auth.signOut();
                      html.window.location.reload();
                    } else {
                      // On mobile, sign out and clear navigation stack
                      await auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    }
                  },
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
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
                      // Stats Card Button
                      Card(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const StatsPage()),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.bar_chart,
                                    color: Color(0xFF6366F1),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'View Your Stats',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'See your progress and learned verbs',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _nextSentence,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('New'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: currentSentence != null ? _toggleTranslation : null,
                              icon: const Icon(Icons.format_quote, size: 18),
                              label: const Text('Reveal'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: currentSentence != null && !_isLoading ? _skipSentence : null,
                              icon: const Icon(Icons.skip_next, size: 18),
                              label: const Text('Skip'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                              ),
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
                        // Verb Display
                        if (currentSentence['verb'] != null) ...[
                          Text(
                            'Verb: ${currentSentence['verb']}'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Phrases learned: $_phrasesLearned',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                        // Sentence Cards
                        _buildSentenceCard(
                          _firstLanguage,
                          currentSentence['target_text'] ?? 'No text',
                          Theme.of(context).cardColor,
                        ),
                        if (_showTranslation) ...[
                          const SizedBox(height: 24),
                          _buildSentenceCard(
                            _secondLanguage,
                            currentSentence['translation_text'] ?? 'No translation',
                            Theme.of(context).cardColor,
                          ),
                        ],
                      ] else if (_isLoading) ...[
                        const CircularProgressIndicator(),
                      ] else ...[
                        Text(
                          'Click "New sentence" to start',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
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
    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 50),
          // Settings Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Language you\'re learning'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _firstLanguage,
                    items: [
                      'English',
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
                  TextField(
                    controller: _verbFocusController,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _getVerbFocusHint(),
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
                  const SizedBox(height: 24),
                  _buildLabel('Tenses'),
                  const SizedBox(height: 12),
                  _buildTenseChips(),
                  const SizedBox(height: 32),
                  _buildLabel('Appearance'),
                  const SizedBox(height: 12),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) => SwitchListTile(
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

  String _getVerbFocusHint() {
    final hints = {
      'English': 'eat, speak, have',
      'Spanish': 'comer, hablar, tener',
      'French': 'manger, parler, avoir',
      'German': 'essen, sprechen, haben',
      'Italian': 'mangiare, parlare, avere',
      'Portuguese': 'comer, falar, ter',
      'Russian': 'есть, говорить, иметь',
      'Japanese': '食べる, 話す, 持つ',
      'Chinese': '吃, 说, 有',
      'Arabic': 'أكل, تحدث, لديه',
      'Korean': '먹다, 말하다, 가지다',
      'Dutch': 'eten, spreken, hebben',
      'Swedish': 'äta, tala, ha',
      'Polish': 'jeść, mówić, mieć',
      'Greek': 'τρώω, μιλάω, έχω',
    };
    return hints[_firstLanguage] ?? 'verb1, verb2, verb3';
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

  Widget _buildTenseChips() {
    final allTenses = ['Past', 'Present', 'Future'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allTenses.map((tense) {
        final isSelected = _selectedTenses.contains(tense);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedTenses.remove(tense);
              } else {
                _selectedTenses.add(tense);
              }
            });
            _clearSentenceCache();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected 
                ? const Color(0xFF6366F1).withOpacity(0.2) 
                : Theme.of(context).inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? const Color(0xFF6366F1) : Theme.of(context).dividerColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tense,
                  style: TextStyle(
                    color: isSelected 
                      ? const Color(0xFF6366F1) 
                      : Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.close, size: 14, color: Color(0xFF6366F1)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF6366F1),
        ),
      ],
    );
  }

  Widget _buildSentenceCard(String language, String text, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                language,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.volume_up,
                  size: 18,
                  color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                ),
                onPressed: () => _speak(text, language),
                tooltip: 'Listen to pronunciation',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 20,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
