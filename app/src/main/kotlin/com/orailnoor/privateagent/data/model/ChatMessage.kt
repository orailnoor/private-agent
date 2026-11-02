package com.orailnoor.privateagent.data.model

import kotlinx.serialization.Serializable

@Serializable
data class ChatMessage(
    val id: String = java.util.UUID.randomUUID().toString(),
    val role: String, // "user" or "assistant"
    val content: String,
    val timestamp: Long = System.currentTimeMillis(),
    val actionResult: AgentActionResult? = null,
    val isStreaming: Boolean = false
) {
    val isUser: Boolean get() = role == "user"
}

@Serializable
data class AgentActionResult(
    val actionType: String,
    val success: Boolean,
    val details: String? = null
)

@Serializable
data class ChatSession(
    val id: String,
    val title: String,
    val timestamp: Long,
    val messages: List<ChatMessage>
)
