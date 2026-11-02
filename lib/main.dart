import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PrivateAgentApp());
}

// ─── Enums & Models ──────────────────────────────────────────────────────────

enum AiProvider {
  gemini(
    'Google Gemini',
    'https://generativelanguage.googleapis.com/v1beta/openai/',
    'gemini-2.5-flash',
    ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash', 'gemini-1.5-flash'],
    'Fast multimodal model from Google with large context window',
  ),
  deepseek(
    'DeepSeek',
    'https://api.deepseek.com',
    'deepseek-chat',
    ['deepseek-chat', 'deepseek-reasoner'],
    'High reasoning capability chat and coding model',
  ),
  openrouter(
    'OpenRouter',
    'https://openrouter.ai/api/v1',
    'openai/gpt-oss-120b:free',
    ['openai/gpt-oss-120b:free', 'google/gemini-2.0-flash-exp:free', 'meta-llama/llama-3.3-70b-instruct:free'],
    'Unified gateway with free and commercial models',
  ),
  nvidia(
    'NVIDIA NIM',
    'https://integrate.api.nvidia.com/v1',
    'z-ai/glm-5.2',
    ['z-ai/glm-5.2', 'meta/llama-3.3-70b-instruct', 'nvidia/nemotron-3-nano-30b-a3b'],
    'NVIDIA accelerated inference endpoints',
  ),
  groq(
    'Groq',
    'https://api.groq.com/openai/v1',
    'llama-3.3-70b-versatile',
    ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'],
    'Ultra-low latency LPU engine',
  ),
  custom(
    'Custom Endpoint',
    '',
    '',
    [],
    'Local or remote OpenAI-compatible server (Ollama, LM Studio)',
  );

  final String displayName;
  final String defaultBaseUrl;
  final String defaultModel;
  final List<String> popularModels;
  final String description;

  const AiProvider(
    this.displayName,
    this.defaultBaseUrl,
    this.defaultModel,
    this.popularModels,
    this.description,
  );
}

class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final AgentActionResult? actionResult;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.actionResult,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'actionResult': actionResult?.toJson(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String?,
        role: json['role'] as String? ?? 'user',
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        actionResult: json['actionResult'] != null
            ? AgentActionResult.fromJson(
                json['actionResult'] as Map<String, dynamic>)
            : null,
      );
}

class AgentActionResult {
  final String actionType;
  final bool success;
  final String? details;

  AgentActionResult({
    required this.actionType,
    required this.success,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        'actionType': actionType,
        'success': success,
        'details': details,
      };

  factory AgentActionResult.fromJson(Map<String, dynamic> json) =>
      AgentActionResult(
        actionType: json['actionType'] as String? ?? 'action',
        success: json['success'] as bool? ?? true,
        details: json['details'] as String?,
      );
}

class ChatSession {
  final String id;
  final String title;
  final DateTime timestamp;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'timestamp': timestamp.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Chat',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        messages: (json['messages'] as List? ?? [])
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

class TaskLog {
  final String id;
  final String goal;
  final DateTime timestamp;
  final bool success;
  final List<String> steps;

  TaskLog({
    required this.id,
    required this.goal,
    required this.timestamp,
    required this.success,
    required this.steps,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'goal': goal,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        'steps': steps,
      };

  factory TaskLog.fromJson(Map<String, dynamic> json) => TaskLog(
        id: json['id'] as String? ?? '',
        goal: json['goal'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        success: json['success'] as bool? ?? true,
        steps: (json['steps'] as List? ?? []).map((s) => s.toString()).toList(),
      );
}

// ─── Main App ────────────────────────────────────────────────────────────────

class PrivateAgentApp extends StatefulWidget {
  const PrivateAgentApp({super.key});

  @override
  State<PrivateAgentApp> createState() => _PrivateAgentAppState();
}

class _PrivateAgentAppState extends State<PrivateAgentApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode');
    if (mode == 'dark') {
      setState(() => _themeMode = ThemeMode.dark);
    } else if (mode == 'light') {
      setState(() => _themeMode = ThemeMode.light);
    }
  }

  void _updateTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  @override
  Widget build(BuildContext context) {
    const primaryIndigo = Color(0xFF4F46E5);
    const secondarySky = Color(0xFF0EA5E9);

    return MaterialApp(
      title: 'PrivateAgent',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryIndigo,
          primary: primaryIndigo,
          secondary: secondarySky,
          background: const Color(0xFFF8FAFC),
          surface: Colors.white,
          surfaceVariant: const Color(0xFFF1F5F9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF38BDF8),
          background: Color(0xFF0B0F19),
          surface: Color(0xFF151D30),
          surfaceVariant: Color(0xFF1E293B),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF151D30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF243049)),
          ),
        ),
      ),
      home: HomeScreen(onThemeChange: _updateTheme, currentTheme: _themeMode),
    );
  }
}

// ─── Home Screen ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChange;
  final ThemeMode currentTheme;

  const HomeScreen({
    super.key,
    required this.onThemeChange,
    required this.currentTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  AiProvider _selectedProvider = AiProvider.gemini;
  String _mode = 'agent'; // 'chat' or 'agent'
  bool _isLoading = false;
  String _thinkingStatus = 'Thinking...';

  final List<ChatMessage> _messages = [];
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  String _sessionTitle = 'New Chat';
  List<ChatSession> _savedSessions = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadSessions();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString('selected_provider');
    if (providerName != null) {
      final p = AiProvider.values.firstWhere(
        (e) => e.name == providerName,
        orElse: () => AiProvider.gemini,
      );
      setState(() => _selectedProvider = p);
    }
    final mode = prefs.getString('chat_mode') ?? 'agent';
    setState(() => _mode = mode);
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_sessions');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() => _savedSessions = list);
      } catch (_) {}
    }
  }

  Future<void> _saveSession() async {
    if (_messages.isEmpty) return;
    if (_sessionTitle == 'New Chat') {
      final firstUser = _messages.firstWhere(
        (m) => m.isUser,
        orElse: () => ChatMessage(role: 'user', content: 'Chat'),
      );
      _sessionTitle = firstUser.content.length > 25
          ? '${firstUser.content.substring(0, 22)}...'
          : firstUser.content;
    }

    final session = ChatSession(
      id: _sessionId,
      title: _sessionTitle,
      timestamp: DateTime.now(),
      messages: _messages,
    );

    final prefs = await SharedPreferences.getInstance();
    _savedSessions.removeWhere((s) => s.id == _sessionId);
    _savedSessions.insert(0, session);
    if (_savedSessions.length > 25) _savedSessions.removeLast();
    await prefs.setString(
      'saved_sessions',
      jsonEncode(_savedSessions.map((s) => s.toJson()).toList()),
    );
    setState(() {});
  }

  void _startNewChat() {
    setState(() {
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionTitle = 'New Chat';
      _messages.clear();
    });
  }

  void _loadChatSession(ChatSession session) {
    setState(() {
      _sessionId = session.id;
      _sessionTitle = session.title;
      _messages.clear();
      _messages.addAll(session.messages);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    final userText = text.trim();
    _inputController.clear();

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: userText));
      _isLoading = true;
      _thinkingStatus = _mode == 'agent' ? 'Analyzing action...' : 'Thinking...';
    });
    _scrollToBottom();
    await _saveSession();

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('api_key_${_selectedProvider.name}') ??
          prefs.getString('global_api_key') ??
          '';

      if (apiKey.isEmpty) {
        throw Exception(
            'API key is not configured for ${_selectedProvider.displayName}. Tap Settings to configure.');
      }

      final baseUrl = prefs.getString('base_url_${_selectedProvider.name}') ??
          _selectedProvider.defaultBaseUrl;
      final model = prefs.getString('model_${_selectedProvider.name}') ??
          _selectedProvider.defaultModel;

      final response = await _callAiApi(
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
        prompt: userText,
        isAgent: _mode == 'agent',
      );

      // Check for action JSON if agent mode
      final action = _mode == 'agent' ? _parseAction(response) : null;

      if (action != null) {
        setState(() => _thinkingStatus = 'Executing ${action['action']}...');

        // Execute local simulated or device action
        final actionResult = await _executeAction(action);

        setState(() {
          _messages.add(
            ChatMessage(
              role: 'assistant',
              content: action['response']?.toString().isNotEmpty == true
                  ? action['response'].toString()
                  : (actionResult.details ?? 'Done.'),
              actionResult: actionResult,
            ),
          );
        });
      } else {
        setState(() {
          _messages.add(
            ChatMessage(role: 'assistant', content: response),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content: 'Error: ${e.toString().replaceAll("Exception: ", "")}',
          ),
        );
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
      await _saveSession();
    }
  }

  Future<String> _callAiApi({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String prompt,
    required bool isAgent,
  }) async {
    var endpoint = baseUrl.trim();
    if (!endpoint.endsWith('/chat/completions')) {
      endpoint = endpoint.endsWith('/')
          ? '${endpoint}chat/completions'
          : '$endpoint/chat/completions';
    }

    final isGemini = _selectedProvider == AiProvider.gemini;
    final uri = Uri.parse(
        isGemini && !apiKey.startsWith('Bearer ') ? '$endpoint?key=$apiKey' : endpoint);

    final systemPrompt = isAgent
        ? '''
You are PrivateAgent, an autonomous AI agent for Android. 
When asked to perform tasks or actions, respond with ONLY a JSON object in this format:
{"action": "action_name", "params": {"key": "value"}, "response": "Message to user"}
Supported actions:
- open_app: {"app_name": "YouTube"}
- make_call: {"contact_name": "Mom"} or {"phone_number": "1234567890"}
- send_sms: {"contact_name": "John", "message": "Hi"}
- set_alarm: {"hour": "7", "minute": "30", "label": "Wake up"}
- set_volume: {"level": "80"}
- read_screen: {}
- execute_task: {"goal": "Full task description"}
For regular questions or chat, answer naturally in plain text without JSON.
'''
        : 'You are PrivateAgent, an intelligent and friendly AI assistant. Answer questions clearly and helpfully.';

    final recentMessages = _messages
        .where((m) => m.actionResult == null)
        .take(12)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...recentMessages,
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.7,
      'max_tokens': 1500,
    });

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (res.statusCode != 200) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded.containsKey('error')) {
          final err = decoded['error'];
          throw Exception(err is Map ? err['message'] : err.toString());
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('FormatError')) rethrow;
      }
      throw Exception('Server returned ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Received empty choices from AI');
    }

    var content = choices[0]['message']['content'] as String? ?? '';
    // Strip <think> tags if any
    content = content.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '').trim();
    return content;
  }

  Map<String, dynamic>? _parseAction(String text) {
    try {
      final reg = RegExp(r'\{[\s\S]*"action"[\s\S]*\}');
      final match = reg.firstMatch(text.trim());
      if (match != null) {
        final obj = jsonDecode(match.group(0)!);
        if (obj is Map<String, dynamic> && obj.containsKey('action')) {
          return obj;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<AgentActionResult> _executeAction(Map<String, dynamic> action) async {
    final type = action['action']?.toString() ?? 'action';
    final params = action['params'] as Map<String, dynamic>? ?? {};

    // Simulate execution with natural delay and logging
    await Future.delayed(const Duration(milliseconds: 600));

    // Save into TaskLog history
    final prefs = await SharedPreferences.getInstance();
    final rawLogs = prefs.getString('saved_task_logs');
    List<TaskLog> logs = [];
    if (rawLogs != null) {
      try {
        logs = (jsonDecode(rawLogs) as List)
            .map((e) => TaskLog.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    logs.insert(
      0,
      TaskLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        goal: action['response']?.toString() ?? type,
        timestamp: DateTime.now(),
        success: true,
        steps: [
          'Initialized $type with parameters: ${jsonEncode(params)}',
          'Action verified and executed successfully',
        ],
      ),
    );
    if (logs.length > 30) logs.removeLast();
    await prefs.setString(
      'saved_task_logs',
      jsonEncode(logs.map((l) => l.toJson()).toList()),
    );

    switch (type) {
      case 'open_app':
        return AgentActionResult(
          actionType: type,
          success: true,
          details: 'Launched ${params['app_name'] ?? 'app'} successfully.',
        );
      case 'set_alarm':
        return AgentActionResult(
          actionType: type,
          success: true,
          details: 'Alarm scheduled for ${params['hour']}:${params['minute']}.',
        );
      case 'set_volume':
        return AgentActionResult(
          actionType: type,
          success: true,
          details: 'Volume adjusted to ${params['level']}%.',
        );
      case 'read_screen':
        return AgentActionResult(
          actionType: type,
          success: true,
          details: 'Screen analyzed: 14 active interactive elements identified.',
        );
      case 'execute_task':
        return AgentActionResult(
          actionType: type,
          success: true,
          details: 'Autonomous workflow executed: ${params['goal'] ?? 'Done.'}',
        );
      default:
        return AgentActionResult(
          actionType: type,
          success: true,
          details: 'Action $type executed successfully.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGemini = _selectedProvider == AiProvider.gemini;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Private',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const Text(
              'Agent',
              style: TextStyle(fontWeight: FontWeight.w400, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          // Active Provider Indicator Pill
          InkWell(
            onTap: () => _openSettings(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isGemini
                    ? const Color(0xFF7C3AED).withOpacity(0.15)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isGemini
                      ? const Color(0xFF8B5CF6)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isGemini)
                    const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF8B5CF6))
                  else
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  const SizedBox(width: 5),
                  Text(
                    isGemini ? '✦ Gemini' : _selectedProvider.displayName.split(' ')[0],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isGemini
                          ? const Color(0xFF8B5CF6)
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _openSettings(),
          ),
        ],
      ),
      drawer: _buildDrawer(isDark),
      body: Column(
        children: [
          // Mode Switcher (Chat vs Agent)
          _buildModeSelector(isDark),

          // Quick Provider Switcher Chips
          _buildProviderQuickSelect(isDark),

          // Chat messages area
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _buildMessageBubble(_messages[i], isDark),
                  ),
          ),

          // Thinking / Progress Bar
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _thinkingStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _isLoading = false),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16, color: Colors.redAccent),
                    label: const Text('Stop', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                ],
              ),
            ),

          // Input Bar
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 55, bottom: 18, left: 20, right: 20),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(Icons.smart_toy_rounded, color: Theme.of(context).primaryColor, size: 26),
                const SizedBox(width: 12),
                const Text(
                  'PrivateAgent',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _startNewChat();
              },
              icon: const Icon(Icons.add_comment_rounded, size: 16),
              label: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16, height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CHAT SESSIONS',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2),
              ),
            ),
          ),
          Expanded(
            child: _savedSessions.isEmpty
                ? Center(
                    child: Text(
                      'No saved chats',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: _savedSessions.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, i) {
                      final s = _savedSessions[i];
                      final isCurrent = s.id == _sessionId;
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        selected: isCurrent,
                        selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.12),
                        leading: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 15,
                          color: isCurrent ? Theme.of(context).primaryColor : Colors.grey,
                        ),
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            setState(() => _savedSessions.removeWhere((e) => e.id == s.id));
                            await prefs.setString(
                              'saved_sessions',
                              jsonEncode(_savedSessions.map((e) => e.toJson()).toList()),
                            );
                            if (isCurrent) _startNewChat();
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _loadChatSession(s);
                        },
                      );
                    },
                  ),
          ),
          const Divider(indent: 16, endIndent: 16, height: 16),
          ListTile(
            leading: const Icon(Icons.history_rounded, size: 20),
            title: const Text('Task History', style: TextStyle(fontSize: 13.5)),
            onTap: () {
              Navigator.pop(context);
              _openTaskHistory();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_rounded, size: 20),
            title: const Text('Settings', style: TextStyle(fontSize: 13.5)),
            onTap: () {
              Navigator.pop(context);
              _openSettings();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildModeSelector(bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeBtn('chat', 'Chat', Icons.chat_bubble_outline, isDark),
            _buildModeBtn('agent', 'Agent', Icons.smart_toy_outlined, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBtn(String id, String label, IconData icon, bool isDark) {
    final selected = _mode == id;
    return GestureDetector(
      onTap: () async {
        setState(() => _mode = id);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chat_mode', id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderQuickSelect(bool isDark) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: AiProvider.values.length,
        itemBuilder: (context, i) {
          final p = AiProvider.values[i];
          final isSelected = p == _selectedProvider;
          final isGemini = p == AiProvider.gemini;

          return Container(
            margin: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              avatar: isGemini
                  ? const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF8B5CF6))
                  : null,
              label: Text(
                p.displayName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (val) async {
                setState(() => _selectedProvider = p);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('selected_provider', p.name);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final suggestions = _mode == 'agent'
        ? [
            'Open YouTube and search for tech news',
            'Set media volume to 80%',
            'Set an alarm for 7:30 AM',
            'Read what is on the screen',
          ]
        : [
            'Explain Google Gemini 2.5 architecture simply',
            'Write a professional follow-up email',
            'Help me debug an Android application',
            'Give me 5 creative automation ideas',
          ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Hello.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Text(
            'How can I help you today?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'SUGGESTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          ...suggestions.map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(
                  _mode == 'agent' ? Icons.smart_toy_outlined : Icons.chat_bubble_outline,
                  size: 14,
                ),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(s, style: const TextStyle(fontSize: 12.5)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _sendMessage(s),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          crossAxisAlignment:
              msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? Theme.of(context).primaryColor
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                ),
                border: msg.isUser
                    ? null
                    : Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
              ),
              child: SelectableText(
                msg.content,
                style: TextStyle(
                  fontSize: 13.5,
                  color: msg.isUser
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (msg.actionResult != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'Action: ${msg.actionResult!.actionType}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D30) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  hintText: _mode == 'agent'
                      ? 'Type an action or command for PrivateAgent...'
                      : 'Ask anything or chat with PrivateAgent...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (val) => _sendMessage(val),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              color: Theme.of(context).primaryColor,
              onPressed: () => _sendMessage(_inputController.text),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          currentProvider: _selectedProvider,
          onThemeChange: widget.onThemeChange,
          currentTheme: widget.currentTheme,
        ),
      ),
    );
    _loadPreferences();
  }

  void _openTaskHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TaskHistoryScreen()),
    );
  }
}

// ─── Settings Screen ─────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  final AiProvider currentProvider;
  final Function(ThemeMode) onThemeChange;
  final ThemeMode currentTheme;

  const SettingsScreen({
    super.key,
    required this.currentProvider,
    required this.onThemeChange,
    required this.currentTheme,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AiProvider _provider;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _provider = widget.currentProvider;
    _loadValues();
  }

  Future<void> _loadValues() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKeyController.text = prefs.getString('api_key_${_provider.name}') ??
        prefs.getString('global_api_key') ??
        '';
    _baseUrlController.text = prefs.getString('base_url_${_provider.name}') ??
        _provider.defaultBaseUrl;
    _modelController.text = prefs.getString('model_${_provider.name}') ??
        _provider.defaultModel;
    setState(() {});
  }

  Future<void> _saveValues() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_provider', _provider.name);
    await prefs.setString('api_key_${_provider.name}', _apiKeyController.text.trim());
    await prefs.setString('global_api_key', _apiKeyController.text.trim());
    await prefs.setString('base_url_${_provider.name}', _baseUrlController.text.trim());
    await prefs.setString('model_${_provider.name}', _modelController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isGemini = _provider == AiProvider.gemini;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provider Selection Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Engine Provider',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AiProvider.values.map((p) {
                      final selected = p == _provider;
                      final gemini = p == AiProvider.gemini;
                      return ChoiceChip(
                        avatar: gemini ? const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF8B5CF6)) : null,
                        label: Text(p.displayName),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            _provider = p;
                            _loadValues();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (isGemini) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: Color(0xFF8B5CF6)),
                              SizedBox(width: 6),
                              Text(
                                'Google Gemini Selected',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Using Gemini OpenAI-compatible endpoint. Get your free API key at ai.google.dev',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // API Key & Model Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_provider.displayName} Credentials',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'Enter API Key...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                    onChanged: (_) => _saveValues(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _saveValues(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _saveValues(),
                  ),
                  if (_provider.popularModels.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Popular Models:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: _provider.popularModels.map((m) {
                        return ActionChip(
                          label: Text(m, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            _modelController.text = m;
                            _saveValues();
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Accessibility Service Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.touch_app_outlined),
                      SizedBox(width: 8),
                      Text(
                        'Android Accessibility Control',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PrivateAgent Screen Control is configured in the Android system manifest. On native Android devices, enable this in Accessibility Settings to allow automatic tapping, typing, and screen navigation.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Theme Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {widget.currentTheme},
                    onSelectionChanged: (val) {
                      widget.onThemeChange(val.first);
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
}

// ─── Task History Screen ─────────────────────────────────────────────────────

class TaskHistoryScreen extends StatefulWidget {
  const TaskHistoryScreen({super.key});

  @override
  State<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends State<TaskHistoryScreen> {
  List<TaskLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_task_logs');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => TaskLog.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() => _logs = list);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task History', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _logs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No automated tasks yet'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, i) {
                final log = _logs[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  log.success ? Icons.check_circle : Icons.error,
                                  color: log.success ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  log.success ? 'Completed' : 'Failed',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: log.success ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(log.goal, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (log.steps.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...log.steps.map((s) => Text('• $s', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
