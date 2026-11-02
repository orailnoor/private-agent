package com.orailnoor.privateagent

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.orailnoor.privateagent.data.service.ActionHandler
import com.orailnoor.privateagent.data.service.AiService
import com.orailnoor.privateagent.data.service.PreferencesManager
import com.orailnoor.privateagent.ui.screens.HomeScreen
import com.orailnoor.privateagent.ui.screens.SettingsScreen
import com.orailnoor.privateagent.ui.screens.TaskHistoryScreen
import com.orailnoor.privateagent.ui.theme.PrivateAgentTheme

enum class Screen {
    HOME,
    SETTINGS,
    TASK_HISTORY
}

class MainActivity : ComponentActivity() {

    private lateinit var preferencesManager: PreferencesManager
    private lateinit var aiService: AiService
    private lateinit var actionHandler: ActionHandler

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        preferencesManager = PreferencesManager(this)
        aiService = AiService(preferencesManager)
        actionHandler = ActionHandler(this, preferencesManager)

        setContent {
            PrivateAgentTheme {
                var currentScreen by remember { mutableStateOf(Screen.HOME) }

                Surface(modifier = Modifier.fillMaxSize()) {
                    Crossfade(targetState = currentScreen, label = "screen_transition") { screen ->
                        when (screen) {
                            Screen.HOME -> {
                                HomeScreen(
                                    preferencesManager = preferencesManager,
                                    aiService = aiService,
                                    actionHandler = actionHandler,
                                    onNavigateToSettings = { currentScreen = Screen.SETTINGS },
                                    onNavigateToTaskHistory = { currentScreen = Screen.TASK_HISTORY }
                                )
                            }
                            Screen.SETTINGS -> {
                                SettingsScreen(
                                    preferencesManager = preferencesManager,
                                    aiService = aiService,
                                    onBack = { currentScreen = Screen.HOME }
                                )
                            }
                            Screen.TASK_HISTORY -> {
                                TaskHistoryScreen(
                                    preferencesManager = preferencesManager,
                                    onBack = { currentScreen = Screen.HOME }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
