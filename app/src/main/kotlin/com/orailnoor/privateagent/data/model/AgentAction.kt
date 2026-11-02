package com.orailnoor.privateagent.data.model

import kotlinx.serialization.Serializable

@Serializable
data class AgentAction(
    val action: String,
    val params: Map<String, String> = emptyMap(),
    val response: String = ""
)

@Serializable
data class TaskLog(
    val id: String = java.util.UUID.randomUUID().toString(),
    val goal: String,
    val timestamp: Long = System.currentTimeMillis(),
    val success: Boolean,
    val steps: List<TaskStepLog> = emptyList(),
    val durationMs: Long = 0
)

@Serializable
data class TaskStepLog(
    val stepIndex: Int,
    val description: String,
    val actionType: String,
    val timestamp: Long = System.currentTimeMillis()
)
