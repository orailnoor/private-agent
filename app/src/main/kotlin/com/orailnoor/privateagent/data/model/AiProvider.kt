package com.orailnoor.privateagent.data.model

enum class AiProvider(
    val displayName: String,
    val defaultBaseUrl: String,
    val defaultModel: String,
    val popularModels: List<String>,
    val description: String
) {
    GOOGLE_GEMINI(
        displayName = "Google Gemini",
        defaultBaseUrl = "https://generativelanguage.googleapis.com/v1beta/openai/",
        defaultModel = "gemini-2.5-flash",
        popularModels = listOf(
            "gemini-2.5-flash",
            "gemini-2.5-pro",
            "gemini-2.0-flash",
            "gemini-1.5-flash",
            "gemini-1.5-pro"
        ),
        description = "High-speed multimodal AI from Google with large context window"
    ),
    DEEPSEEK(
        displayName = "DeepSeek",
        defaultBaseUrl = "https://api.deepseek.com",
        defaultModel = "deepseek-chat",
        popularModels = listOf("deepseek-chat", "deepseek-reasoner"),
        description = "Cost-effective high reasoning chat and code model"
    ),
    OPENROUTER(
        displayName = "OpenRouter",
        defaultBaseUrl = "https://openrouter.ai/api/v1",
        defaultModel = "openai/gpt-oss-120b:free",
        popularModels = listOf(
            "openai/gpt-oss-120b:free",
            "google/gemini-2.0-flash-exp:free",
            "meta-llama/llama-3.3-70b-instruct:free",
            "anthropic/claude-3.5-sonnet"
        ),
        description = "Universal API gateway with free and commercial models"
    ),
    NVIDIA(
        displayName = "NVIDIA NIM",
        defaultBaseUrl = "https://integrate.api.nvidia.com/v1",
        defaultModel = "z-ai/glm-5.2",
        popularModels = listOf(
            "z-ai/glm-5.2",
            "meta/llama-3.3-70b-instruct",
            "nvidia/nemotron-3-nano-30b-a3b",
            "mistralai/mistral-nemotron"
        ),
        description = "High performance hosted AI endpoints by NVIDIA"
    ),
    GROQ(
        displayName = "Groq",
        defaultBaseUrl = "https://api.groq.com/openai/v1",
        defaultModel = "llama-3.3-70b-versatile",
        popularModels = listOf("llama-3.3-70b-versatile", "llama-3.1-8b-instant"),
        description = "Ultra-low latency LPU inference"
    ),
    CUSTOM(
        displayName = "Custom Endpoint",
        defaultBaseUrl = "",
        defaultModel = "",
        popularModels = emptyList(),
        description = "Any OpenAI-compatible server (LM Studio, Ollama, vLLM)"
    );

    companion object {
        fun fromId(id: String): AiProvider {
            return entries.firstOrNull { it.name.equals(id, ignoreCase = true) } ?: GOOGLE_GEMINI
        }
    }
}
