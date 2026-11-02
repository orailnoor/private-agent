package com.orailnoor.privateagent.data.service

import com.orailnoor.privateagent.data.model.AgentAction
import com.orailnoor.privateagent.data.model.AiProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import java.util.concurrent.TimeUnit

class AiService(private val prefs: PreferencesManager) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .readTimeout(90, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    private val mediaTypeJson = "application/json; charset=utf-8".toMediaType()

    companion object {
        const val AGENT_SYSTEM_PROMPT = """
You are PrivateAgent, an intelligent AI that controls an Android phone via Accessibility Services.
You can perform device actions and also have normal conversations.

When the user wants to perform a device action, you MUST respond with ONLY a single JSON object (no markdown fences, no extra text) in this exact format:
{"action": "action_name", "params": {"key": "value"}, "response": "Message to user"}

AVAILABLE ACTIONS:
- open_app: {"app_name": "YouTube"} (Just launches an app)
- make_call: {"contact_name": "Mom"} or {"phone_number": "1234567890"}
- send_sms: {"contact_name": "John", "message": "Hello"} or {"phone_number": "123", "message": "Hi"}
- set_alarm: {"hour": "7", "minute": "30", "label": "Wake up"}
- set_volume: {"level": "50"}
- read_screen: {}
- press_back: {}
- execute_task: {"goal": "Full natural language description of multi-step task"}

CRITICAL RULES:
1. If the request requires multiple steps (open and search, open and send, click, type), always output execute_task.
2. For general questions, reasoning, writing, or chat, respond naturally in plain text without JSON.
"""

        const val CHAT_SYSTEM_PROMPT = """
You are PrivateAgent, an intelligent and friendly AI assistant.
Answer questions, explain concepts, brainstorm, write emails and messages, and assist the user clearly and concisely in plain text or markdown.
"""
    }

    suspend fun sendMessage(
        userPrompt: String,
        history: List<Pair<String, String>>,
        isAgentMode: Boolean
    ): String = withContext(Dispatchers.IO) {
        val provider = prefs.selectedProvider
        val apiKey = prefs.getApiKey(provider)
        val baseUrl = prefs.getBaseUrl(provider).trim()
        val model = prefs.getModel(provider).trim()

        if (apiKey.isEmpty()) {
            throw IllegalStateException("API Key is missing for ${provider.displayName}. Please configure it in Settings.")
        }

        // Build messages JSON array
        val messagesArray = JSONArray()
        if (prefs.useSystemPrompt) {
            val systemContent = if (isAgentMode) AGENT_SYSTEM_PROMPT else CHAT_SYSTEM_PROMPT
            messagesArray.put(JSONObject().apply {
                put("role", "system")
                put("content", systemContent)
            })
        }

        // Append recent history
        val recentHistory = history.takeLast(16)
        for ((role, content) in recentHistory) {
            messagesArray.put(JSONObject().apply {
                put("role", role)
                put("content", content)
            })
        }

        // Append current user prompt
        messagesArray.put(JSONObject().apply {
            put("role", "user")
            put("content", userPrompt)
        })

        val requestJson = JSONObject().apply {
            put("model", model)
            put("messages", messagesArray)
            put("temperature", prefs.temperature.toDouble())
            put("max_tokens", 2048)
        }

        // Construct target endpoint URL
        var endpoint = baseUrl
        if (!endpoint.endsWith("/chat/completions")) {
            endpoint = if (endpoint.endsWith("/")) {
                "${endpoint}chat/completions"
            } else {
                "$endpoint/chat/completions"
            }
        }

        // For Google Gemini API, support key parameter as well as Bearer
        val urlBuilder = endpoint.toHttpUrlOrNull()?.newBuilder()
        if (provider == AiProvider.GOOGLE_GEMINI && urlBuilder != null && !apiKey.startsWith("Bearer ")) {
            urlBuilder.addQueryParameter("key", apiKey)
        }
        val finalUrl = urlBuilder?.build()?.toString() ?: endpoint

        val requestBuilder = Request.Builder()
            .url(finalUrl)
            .addHeader("Content-Type", "application/json")
            .addHeader("Authorization", "Bearer $apiKey")
            .addHeader("HTTP-Referer", "https://github.com/orailnoor/private-agent")
            .addHeader("X-Title", "PrivateAgent")
            .post(requestJson.toString().toRequestBody(mediaTypeJson))

        val response = client.newCall(requestBuilder.build()).execute()
        val responseBody = response.body?.string().orEmpty()

        if (!response.isSuccessful) {
            val errorMsg = try {
                val errObj = JSONObject(responseBody)
                if (errObj.has("error")) {
                    val errNode = errObj.get("error")
                    if (errNode is JSONObject && errNode.has("message")) {
                        errNode.getString("message")
                    } else errNode.toString()
                } else responseBody
            } catch (_: Exception) {
                responseBody
            }
            throw RuntimeException("AI Provider Error (${response.code}): $errorMsg")
        }

        val jsonResponse = JSONObject(responseBody)
        val choices = jsonResponse.optJSONArray("choices")
        if (choices == null || choices.length() == 0) {
            throw RuntimeException("Received empty choices response from AI provider")
        }

        val firstChoice = choices.getJSONObject(0)
        val messageObj = firstChoice.optJSONObject("message")
        var content = messageObj?.optString("content") ?: ""

        // Strip <think>...</think> tags if reasoning model
        content = content.replace(Regex("<think>.*?</think>", RegexOption.DOT_MATCHES_ALL), "").trim()

        if (content.isEmpty()) {
            throw RuntimeException("Model returned empty text. Please check model capacity or try another model.")
        }

        content
    }

    suspend fun fetchModels(provider: AiProvider, apiKey: String, baseUrl: String): List<String> =
        withContext(Dispatchers.IO) {
            if (apiKey.isEmpty()) return@withContext provider.popularModels

            try {
                var cleanBase = baseUrl.trim()
                if (cleanBase.endsWith("/chat/completions")) {
                    cleanBase = cleanBase.removeSuffix("/chat/completions")
                }
                cleanBase = cleanBase.removeSuffix("/")

                val endpoint = "$cleanBase/models"
                val urlBuilder = endpoint.toHttpUrlOrNull()?.newBuilder()
                if (provider == AiProvider.GOOGLE_GEMINI && urlBuilder != null && !apiKey.startsWith("Bearer ")) {
                    urlBuilder.addQueryParameter("key", apiKey)
                }
                val finalUrl = urlBuilder?.build()?.toString() ?: endpoint

                val request = Request.Builder()
                    .url(finalUrl)
                    .addHeader("Authorization", "Bearer $apiKey")
                    .get()
                    .build()

                val response = client.newCall(request).execute()
                if (response.isSuccessful) {
                    val body = response.body?.string().orEmpty()
                    val json = JSONObject(body)
                    val dataArray = json.optJSONArray("data")
                    if (dataArray != null) {
                        val models = mutableListOf<String>()
                        for (i in 0 until dataArray.length()) {
                            val item = dataArray.getJSONObject(i)
                            val id = item.optString("id")
                            if (id.isNotEmpty()) models.add(id)
                        }
                        if (models.isNotEmpty()) {
                            return@withContext models.sorted()
                        }
                    }
                }
            } catch (_: Exception) {}

            // Fallback to provider's popular models list
            provider.popularModels
        }

    fun parseAction(text: String): AgentAction? {
        val trimmed = text.trim()
        val jsonPattern = Regex("""\{[\s\S]*"action"[\s\S]*\}""")
        val match = jsonPattern.find(trimmed) ?: return null

        return try {
            val obj = JSONObject(match.value)
            val actionName = obj.optString("action")
            if (actionName.isEmpty()) return null

            val paramsMap = mutableMapOf<String, String>()
            val paramsObj = obj.optJSONObject("params")
            if (paramsObj != null) {
                val keys = paramsObj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    paramsMap[k] = paramsObj.optString(k, "")
                }
            }

            val response = obj.optString("response", "")
            AgentAction(action = actionName, params = paramsMap, response = response)
        } catch (_: Exception) {
            null
        }
    }
}
