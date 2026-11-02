package com.orailnoor.privateagent.data.service

import android.content.Context
import android.content.SharedPreferences
import com.orailnoor.privateagent.data.model.AiProvider
import com.orailnoor.privateagent.data.model.ChatMessage
import com.orailnoor.privateagent.data.model.ChatSession
import com.orailnoor.privateagent.data.model.TaskLog
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class PreferencesManager(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("private_agent_prefs", Context.MODE_PRIVATE)

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    var selectedProvider: AiProvider
        get() {
            val name = prefs.getString("selected_provider", AiProvider.GOOGLE_GEMINI.name)
            return AiProvider.fromId(name ?: AiProvider.GOOGLE_GEMINI.name)
        }
        set(value) {
            prefs.edit().putString("selected_provider", value.name).apply()
        }

    fun getApiKey(provider: AiProvider): String {
        val key = prefs.getString("api_key_${provider.name}", null)
        return key ?: prefs.getString("global_api_key", "") ?: ""
    }

    fun setApiKey(provider: AiProvider, key: String) {
        prefs.edit()
            .putString("api_key_${provider.name}", key.trim())
            .putString("global_api_key", key.trim())
            .apply()
    }

    fun getBaseUrl(provider: AiProvider): String {
        return prefs.getString("base_url_${provider.name}", provider.defaultBaseUrl)
            ?: provider.defaultBaseUrl
    }

    fun setBaseUrl(provider: AiProvider, url: String) {
        prefs.edit().putString("base_url_${provider.name}", url.trim()).apply()
    }

    fun getModel(provider: AiProvider): String {
        return prefs.getString("model_${provider.name}", provider.defaultModel)
            ?: provider.defaultModel
    }

    fun setModel(provider: AiProvider, model: String) {
        prefs.edit().putString("model_${provider.name}", model.trim()).apply()
    }

    var maxSteps: Int
        get() = prefs.getInt("max_steps", 15)
        set(value) = prefs.edit().putInt("max_steps", value).apply()

    var temperature: Float
        get() = prefs.getFloat("temperature", 0.7f)
        set(value) = prefs.edit().putFloat("temperature", value).apply()

    var useSystemPrompt: Boolean
        get() = prefs.getBoolean("use_system_prompt", true)
        set(value) = prefs.edit().putBoolean("use_system_prompt", value).apply()

    var chatMode: String
        get() = prefs.getString("chat_mode", "agent") ?: "agent"
        set(value) = prefs.edit().putString("chat_mode", value).apply()

    fun loadSessions(): List<ChatSession> {
        val raw = prefs.getString("saved_sessions", null) ?: return emptyList()
        return try {
            json.decodeFromString(raw)
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun saveSession(session: ChatSession) {
        val current = loadSessions().filterNot { it.id == session.id }.toMutableList()
        current.add(0, session)
        if (current.size > 30) current.removeAt(current.size - 1)
        try {
            prefs.edit().putString("saved_sessions", json.encodeToString(current)).apply()
        } catch (_: Exception) {}
    }

    fun deleteSession(sessionId: String) {
        val current = loadSessions().filterNot { it.id == sessionId }
        try {
            prefs.edit().putString("saved_sessions", json.encodeToString(current)).apply()
        } catch (_: Exception) {}
    }

    fun loadTaskLogs(): List<TaskLog> {
        val raw = prefs.getString("saved_task_logs", null) ?: return emptyList()
        return try {
            json.decodeFromString(raw)
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun saveTaskLog(log: TaskLog) {
        val current = loadTaskLogs().toMutableList()
        current.add(0, log)
        if (current.size > 50) current.removeAt(current.size - 1)
        try {
            prefs.edit().putString("saved_task_logs", json.encodeToString(current)).apply()
        } catch (_: Exception) {}
    }
}
