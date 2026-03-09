import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _showTranslationFirst = false;
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

    // Check daily rate limit before hitting the API
    final auth = context.read<AuthService>();
    if (auth.currentUser != null) {
      final allowed = await _userDb.checkAndIncrementDailyApiUsage(auth.currentUser!.uid);
      if (!allowed) {
        setState(() {
          _isLoading = false;
          _error = "You've reached your 5 requests for today. Come back tomorrow!";
        });
        return;
      }
    }

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
          _error = 'No phrases came back — please try again.';
        }
      });
    } on ApiException catch (e) {
      setState(() {
        // Log the raw detail for debugging, show a clean message to the user
        print('ApiException ${e.status}: ${e.message}');
        if (e.status >= 500) {
          _error = 'Our server ran into a problem. Please try again in a moment.';
        } else if (e.status == 401 || e.status == 403) {
          _error = 'Authentication error. Please sign out and back in.';
        } else if (e.status == 429) {
          _error = 'Too many requests — please wait a moment and try again.';
        } else {
          _error = 'Something went wrong (code ${e.status}). Please try again.';
        }
      });
    } on SocketException {
      setState(() {
        _error = 'No internet connection. Check your network and try again.';
      });
    } on TimeoutException {
      setState(() {
        _error = 'The request took too long. Check your connection and try again.';
      });
    } catch (e) {
      print('Unexpected error: $e');
      setState(() {
        _error = 'Something unexpected happened. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Skip to the next sentence without saving (or fetch first batch if none loaded)
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

  // Save the current phrase to the DB without advancing
  void _saveSentence() async {
    if (_sentences == null || _sentences!.isEmpty) return;

    final currentSentence = _sentences![_currentSentenceIndex];
    final verb = currentSentence['verb'] as String? ?? '';
    final tense = currentSentence['tense'] as String? ?? 'present';
    final phrase = currentSentence['target_text'] as String? ?? '';
    final phraseTranslation = currentSentence['translation_text'] as String? ?? '';
    final verbTranslation = currentSentence['verb_translation'] as String? ?? '';

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
          phrase: phrase,
          phraseTranslation: phraseTranslation,
          verbTranslation: verbTranslation,
        );
        print('Successfully recorded sentence');
      } catch (e) {
        print('Error recording sentence: $e');
      }
    } else if (tense.isEmpty) {
      print('Skipping recording: tense is empty for verb=$verb');
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
                  Text(
                    'DailyFrase',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      if (kIsWeb) {
                        await auth.signOut();
                        html.window.location.reload();
                      } else {
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
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _newSentence,
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: const Text('New'),
                              style: OutlinedButton.styleFrom(
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
                            child: ElevatedButton.icon(
                              onPressed: currentSentence != null && !_isLoading ? _saveSentence : null,
                              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                              label: const Text('Save'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                backgroundColor: const Color(0xFF22C55E),
                                foregroundColor: Colors.white,
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
                          _showTranslationFirst ? _secondLanguage : _firstLanguage,
                          _showTranslationFirst
                              ? (currentSentence['translation_text'] ?? 'No text')
                              : (currentSentence['target_text'] ?? 'No text'),
                          Theme.of(context).cardColor,
                        ),
                        if (_showTranslation) ...[
                          const SizedBox(height: 24),
                          _buildSentenceCard(
                            _showTranslationFirst ? _firstLanguage : _secondLanguage,
                            _showTranslationFirst
                                ? (currentSentence['target_text'] ?? 'No translation')
                                : (currentSentence['translation_text'] ?? 'No translation'),
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
                  _buildLabel('Sentence complexity'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _level,
                    items: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
                    onChanged: (val) {
                      setState(() => _level = val!);
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
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6366F1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: const Text('View Tutorial', style: TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer
                      context.read<AuthService>().setNewUserFlag();
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.feedback_outlined, size: 24, color: Color(0xFF6366F1)),
                    title: const Text('Send Feedback', style: TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer
                      _showFeedbackSheet();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackSheet() {
    final controller = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Feedback',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spotted a bug or have a suggestion? Let us know.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(ctx).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    autofocus: true,
                    style: TextStyle(
                      color: Theme.of(ctx).textTheme.bodyLarge?.color,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write your feedback here...',
                      hintStyle: TextStyle(color: Theme.of(ctx).hintColor, fontSize: 13),
                      filled: true,
                      fillColor: Theme.of(ctx).inputDecorationTheme.fillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(ctx).dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(ctx).dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              final text = controller.text.trim();
                              if (text.isEmpty) return;
                              setSheetState(() => submitting = true);
                              try {
                                final auth = context.read<AuthService>();
                                await FirebaseFirestore.instance
                                    .collection('feedback')
                                    .add({
                                  'message': text,
                                  'email': auth.currentUser?.email ?? 'anonymous',
                                  'uid': auth.currentUser?.uid ?? '',
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Thanks for your feedback!')),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => submitting = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Failed to send. Please try again.')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
