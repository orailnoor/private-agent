package com.orailnoor.privateagent.data.service

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.provider.AlarmClock
import com.orailnoor.privateagent.AgentAccessibilityService
import com.orailnoor.privateagent.data.model.AgentAction
import com.orailnoor.privateagent.data.model.AgentActionResult
import com.orailnoor.privateagent.data.model.TaskLog
import com.orailnoor.privateagent.data.model.TaskStepLog
import kotlinx.coroutines.delay

class ActionHandler(
    private val context: Context,
    private val preferencesManager: PreferencesManager
) {
    private var isCancelled = false

    fun cancelTask() {
        isCancelled = true
    }

    suspend fun execute(
        action: AgentAction,
        aiService: AiService,
        onProgress: (String) -> Unit
    ): AgentActionResult {
        isCancelled = false
        val startTime = System.currentTimeMillis()

        return try {
            when (action.action) {
                "open_app" -> {
                    val appName = action.params["app_name"] ?: ""
                    val success = openApp(appName)
                    AgentActionResult(
                        actionType = "open_app",
                        success = success,
                        details = if (success) "Opened $appName" else "Could not find application: $appName"
                    )
                }

                "make_call" -> {
                    val phone = action.params["phone_number"] ?: action.params["contact_name"] ?: ""
                    val success = makeCall(phone)
                    AgentActionResult(
                        actionType = "make_call",
                        success = success,
                        details = if (success) "Dialing $phone" else "Unable to start call"
                    )
                }

                "send_sms" -> {
                    val recipient = action.params["phone_number"] ?: action.params["contact_name"] ?: ""
                    val msg = action.params["message"] ?: ""
                    val success = sendSms(recipient, msg)
                    AgentActionResult(
                        actionType = "send_sms",
                        success = success,
                        details = if (success) "SMS drafted to $recipient" else "Failed to open SMS editor"
                    )
                }

                "set_alarm" -> {
                    val hour = action.params["hour"]?.toIntOrNull() ?: 7
                    val minute = action.params["minute"]?.toIntOrNull() ?: 0
                    val label = action.params["label"] ?: "PrivateAgent Alarm"
                    val success = setAlarm(hour, minute, label)
                    AgentActionResult(
                        actionType = "set_alarm",
                        success = success,
                        details = if (success) "Alarm scheduled for %02d:%02d".format(hour, minute) else "Could not set alarm"
                    )
                }

                "set_volume" -> {
                    val level = action.params["level"]?.toIntOrNull() ?: 50
                    setVolume(level)
                    AgentActionResult(
                        actionType = "set_volume",
                        success = true,
                        details = "Media volume set to $level%"
                    )
                }

                "read_screen" -> {
                    val service = AgentAccessibilityService.instance
                    if (service == null) {
                        AgentActionResult(
                            actionType = "read_screen",
                            success = false,
                            details = "Accessibility Service is not enabled. Please enable it in Settings."
                        )
                    } else {
                        val nodes = service.dumpScreen()
                        val visibleItems = nodes.filter {
                            val text = (it["text"] as? String).orEmpty()
                            val desc = (it["contentDescription"] as? String).orEmpty()
                            text.isNotEmpty() || desc.isNotEmpty()
                        }.take(20)

                        val summary = visibleItems.joinToString("\n") {
                            val t = (it["text"] as? String).orEmpty().ifEmpty { (it["contentDescription"] as? String).orEmpty() }
                            "- $t (${it["className"]})"
                        }
                        AgentActionResult(
                            actionType = "read_screen",
                            success = true,
                            details = "Screen contains ${nodes.size} elements:\n$summary"
                        )
                    }
                }

                "press_back" -> {
                    val service = AgentAccessibilityService.instance
                    val success = service?.pressBack() ?: false
                    AgentActionResult(
                        actionType = "press_back",
                        success = success,
                        details = if (success) "Pressed Back" else "Accessibility service unavailable"
                    )
                }

                "execute_task" -> {
                    val goal = action.params["goal"] ?: action.response
                    executeAutonomousTask(goal, aiService, onProgress)
                }

                else -> {
                    AgentActionResult(
                        actionType = action.action,
                        success = true,
                        details = action.response.ifEmpty { "Action finished" }
                    )
                }
            }
        } catch (e: Exception) {
            AgentActionResult(
                actionType = action.action,
                success = false,
                details = "Error executing action: ${e.message}"
            )
        }
    }

    private suspend fun executeAutonomousTask(
        goal: String,
        aiService: AiService,
        onProgress: (String) -> Unit
    ): AgentActionResult {
        val service = AgentAccessibilityService.instance
        if (service == null) {
            return AgentActionResult(
                actionType = "execute_task",
                success = false,
                details = "Accessibility Service is disabled. Enable 'PrivateAgent Screen Control' in Android Settings to automate tasks."
            )
        }

        val stepLogs = mutableListOf<TaskStepLog>()
        val maxSteps = preferencesManager.maxSteps
        var stepCount = 0
        var taskCompleted = false
        var finalDetails = ""

        onProgress("Starting autonomous task: $goal")
        delay(600)

        while (stepCount < maxSteps && !isCancelled && !taskCompleted) {
            stepCount++
            onProgress("Step $stepCount: Reading screen hierarchy...")

            val nodes = service.dumpScreen()
            val simplifiedNodes = nodes.filter {
                val t = (it["text"] as? String).orEmpty()
                val d = (it["contentDescription"] as? String).orEmpty()
                val clickable = it["isClickable"] as? Boolean ?: false
                t.isNotEmpty() || d.isNotEmpty() || clickable
            }.take(30).map {
                val text = (it["text"] as? String).orEmpty()
                val desc = (it["contentDescription"] as? String).orEmpty()
                val label = if (text.isNotEmpty()) text else desc
                val bounds = it["bounds"] as? Map<*, *>
                val cx = bounds?.get("centerX") ?: 0
                val cy = bounds?.get("centerY") ?: 0
                "[$label] at ($cx, $cy)"
            }

            val stepPrompt = """
Goal: $goal
Current Step: $stepCount of $maxSteps
Visible Screen Elements:
${simplifiedNodes.joinToString("\n")}

Decide the NEXT single action to achieve the goal.
Respond ONLY with a JSON object:
{"action": "click|input|scroll|open_app|finish", "params": {"x": 500, "y": 800, "text": "..."}, "response": "Explanation"}
If the task is accomplished, use {"action": "finish", "params": {}, "response": "Task complete summary"}
"""

            try {
                val aiResponse = aiService.sendMessage(
                    userPrompt = stepPrompt,
                    history = emptyList(),
                    isAgentMode = true
                )

                val parsedAction = aiService.parseAction(aiResponse)
                if (parsedAction == null) {
                    onProgress("AI Response: $aiResponse")
                    finalDetails = aiResponse
                    taskCompleted = true
                    break
                }

                stepLogs.add(
                    TaskStepLog(
                        stepIndex = stepCount,
                        description = parsedAction.response.ifEmpty { parsedAction.action },
                        actionType = parsedAction.action
                    )
                )

                when (parsedAction.action) {
                    "finish" -> {
                        onProgress("Task completed: ${parsedAction.response}")
                        finalDetails = parsedAction.response.ifEmpty { "Goal accomplished" }
                        taskCompleted = true
                        break
                    }
                    "click" -> {
                        val x = parsedAction.params["x"]?.toFloatOrNull() ?: 500f
                        val y = parsedAction.params["y"]?.toFloatOrNull() ?: 1000f
                        onProgress("Tapping coordinate ($x, $y)...")
                        service.clickCoordinates(x, y)
                        delay(1200)
                    }
                    "input" -> {
                        val text = parsedAction.params["text"].orEmpty()
                        onProgress("Typing text '$text'...")
                        service.inputText(text)
                        delay(1000)
                    }
                    "scroll" -> {
                        val dir = parsedAction.params["direction"] ?: "down"
                        onProgress("Scrolling $dir...")
                        service.scroll(dir)
                        delay(1000)
                    }
                    "open_app" -> {
                        val app = parsedAction.params["app_name"].orEmpty()
                        onProgress("Opening app '$app'...")
                        openApp(app)
                        delay(2500)
                    }
                    else -> {
                        onProgress("Executed ${parsedAction.action}")
                        delay(800)
                    }
                }
            } catch (e: Exception) {
                onProgress("Step $stepCount encountered an issue: ${e.message}")
                finalDetails = "Error on step $stepCount: ${e.message}"
                break
            }
        }

        if (isCancelled) {
            finalDetails = "Task was stopped by user."
        }

        // Save task history log
        val log = TaskLog(
            goal = goal,
            success = taskCompleted,
            steps = stepLogs,
            durationMs = System.currentTimeMillis()
        )
        preferencesManager.saveTaskLog(log)

        return AgentActionResult(
            actionType = "execute_task",
            success = taskCompleted || !isCancelled,
            details = finalDetails.ifEmpty { "Automated execution completed $stepCount steps." }
        )
    }

    private fun openApp(appName: String): Boolean {
        val pm = context.packageManager
        val packages = pm.getInstalledPackages(0)

        // Find match by package name or application label
        val matchedPkg = packages.firstOrNull { pkg ->
            val label = pm.getApplicationLabel(pkg.applicationInfo).toString()
            label.contains(appName, ignoreCase = true) || pkg.packageName.contains(appName, ignoreCase = true)
        }

        if (matchedPkg != null) {
            val intent = pm.getLaunchIntentForPackage(matchedPkg.packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                return true
            }
        }
        return false
    }

    private fun makeCall(phone: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${Uri.encode(phone)}")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun sendSms(recipient: String, message: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:${Uri.encode(recipient)}")).apply {
                putExtra("sms_body", message)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun setAlarm(hour: Int, minute: Int, label: String): Boolean {
        return try {
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
                putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun setVolume(level: Int) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val target = ((level.coerceIn(0, 100) / 100f) * maxVolume).toInt()
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, target, AudioManager.FLAG_SHOW_UI)
    }
}
