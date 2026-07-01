/// Represents a preset AI provider for the settings screen.
///
/// Each preset stores a human-readable name, the OpenAI-compatible base URL,
/// a sensible default model, and whether the provider exposes a `/models`
/// endpoint that can be fetched with an API key.
class AiProvider {
  final String name;
  final String baseUrl;
  final String defaultModel;
  final bool supportsModelFetch;

  const AiProvider({
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    this.supportsModelFetch = true,
  });
}

/// Built-in provider presets. Keep this list in one place so the UI and the
/// service can stay in sync without duplicating URLs and default models.
const List<AiProvider> aiProviders = [
  AiProvider(
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    defaultModel: 'deepseek-chat',
  ),
  AiProvider(
    name: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModel: 'openai/gpt-oss-120b:free',
  ),
  AiProvider(
    name: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    defaultModel: 'llama-3.1-8b-instant',
  ),
  AiProvider(
    name: 'Ollama Cloud',
    baseUrl: 'https://ollama.com/v1',
    defaultModel: 'gemma3:4b',
  ),
  AiProvider(
    name: 'Local',
    baseUrl: 'http://10.0.2.2:1234/v1',
    defaultModel: 'local-model',
    supportsModelFetch: false,
  ),
];
