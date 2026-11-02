package com.orailnoor.privateagent.ui.screens

import android.content.Intent
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.orailnoor.privateagent.AgentAccessibilityService
import com.orailnoor.privateagent.data.model.AiProvider
import com.orailnoor.privateagent.data.service.AiService
import com.orailnoor.privateagent.data.service.PreferencesManager
import com.orailnoor.privateagent.ui.theme.GeminiBlue
import com.orailnoor.privateagent.ui.theme.GeminiPurple
import com.orailnoor.privateagent.ui.theme.GeminiSparkle
import com.orailnoor.privateagent.ui.theme.GreenSuccess
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    preferencesManager: PreferencesManager,
    aiService: AiService,
    onBack: () -> Unit
) {
    BackHandler { onBack() }
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    var selectedProvider by remember { mutableStateOf(preferencesManager.selectedProvider) }
    var apiKey by remember { mutableStateOf(preferencesManager.getApiKey(selectedProvider)) }
    var baseUrl by remember { mutableStateOf(preferencesManager.getBaseUrl(selectedProvider)) }
    var model by remember { mutableStateOf(preferencesManager.getModel(selectedProvider)) }
    var maxSteps by remember { mutableStateOf(preferencesManager.maxSteps.toFloat()) }
    var temperature by remember { mutableStateOf(preferencesManager.temperature) }
    var useSystemPrompt by remember { mutableStateOf(preferencesManager.useSystemPrompt) }
    var obscureKey by remember { mutableStateOf(true) }

    var isFetchingModels by remember { mutableStateOf(false) }
    var fetchedModels by remember { mutableStateOf<List<String>>(emptyList()) }
    var showModelDialog by remember { mutableStateOf(false) }

    val accessibilityEnabled = remember { AgentAccessibilityService.isRunning() }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "Settings",
                        fontWeight = FontWeight.Bold,
                        fontSize = 20.sp
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            contentPadding = PaddingValues(vertical = 12.dp)
        ) {
            // ─── 1. AI Provider Selection ──────────────────────────────────────────
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surface
                    ),
                    border = CardDefaults.outlinedCardBorder()
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Outlined.AutoAwesome,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(24.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text(
                                    "AI Engine Provider",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 17.sp,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    "Select which AI provider powers PrivateAgent",
                                    fontSize = 12.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // Provider Chips
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            AiProvider.entries.chunked(2).forEach { rowProviders ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    rowProviders.forEach { provider ->
                                        val isSelected = provider == selectedProvider
                                        val isGemini = provider == AiProvider.GOOGLE_GEMINI

                                        Box(
                                            modifier = Modifier
                                                .weight(1f)
                                                .clip(RoundedCornerShape(14.dp))
                                                .then(
                                                    if (isSelected && isGemini) {
                                                        Modifier.background(
                                                            Brush.horizontalGradient(
                                                                listOf(GeminiPurple.copy(alpha = 0.25f), GeminiBlue.copy(alpha = 0.25f))
                                                            )
                                                        )
                                                    } else if (isSelected) {
                                                        Modifier.background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f))
                                                    } else {
                                                        Modifier.background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                                                    }
                                                )
                                                .border(
                                                    width = if (isSelected) 1.8.dp else 1.dp,
                                                    color = if (isSelected && isGemini) GeminiSparkle else if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent,
                                                    shape = RoundedCornerShape(14.dp)
                                                )
                                                .clickable {
                                                    selectedProvider = provider
                                                    preferencesManager.selectedProvider = provider
                                                    apiKey = preferencesManager.getApiKey(provider)
                                                    baseUrl = preferencesManager.getBaseUrl(provider)
                                                    model = preferencesManager.getModel(provider)
                                                }
                                                .padding(horizontal = 12.dp, vertical = 10.dp)
                                        ) {
                                            Row(
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                                            ) {
                                                if (isGemini) {
                                                    Icon(
                                                        Icons.Filled.AutoAwesome,
                                                        contentDescription = null,
                                                        tint = GeminiSparkle,
                                                        modifier = Modifier.size(16.dp)
                                                    )
                                                } else {
                                                    Icon(
                                                        if (isSelected) Icons.Filled.CheckCircle else Icons.Outlined.Circle,
                                                        contentDescription = null,
                                                        tint = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                                        modifier = Modifier.size(15.dp)
                                                    )
                                                }
                                                Text(
                                                    provider.displayName,
                                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                                    fontSize = 13.sp,
                                                    color = if (isSelected && isGemini) GeminiSparkle else if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Gemini Special Banner
                        AnimatedVisibility(visible = selectedProvider == AiProvider.GOOGLE_GEMINI) {
                            Column(
                                modifier = Modifier
                                    .padding(top = 14.dp)
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(GeminiPurple.copy(alpha = 0.12f))
                                    .border(1.dp, GeminiSparkle.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                                    .padding(12.dp)
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        Icons.Filled.AutoAwesome,
                                        contentDescription = null,
                                        tint = GeminiSparkle,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        "Google Gemini Integration Active",
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 12.5.sp,
                                        color = GeminiSparkle
                                    )
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    "Google Gemini provides high token limits and lightning-fast responses. Get your free API key at ai.google.dev",
                                    fontSize = 11.5.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }

            // ─── 2. Credentials & Endpoint ─────────────────────────────────────────
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surface
                    ),
                    border = CardDefaults.outlinedCardBorder()
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Outlined.Key,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(22.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Text(
                                "${selectedProvider.displayName} Configuration",
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                        }

                        Spacer(modifier = Modifier.height(14.dp))

                        // API Key
                        OutlinedTextField(
                            value = apiKey,
                            onValueChange = {
                                apiKey = it
                                preferencesManager.setApiKey(selectedProvider, it)
                            },
                            label = { Text("API Key") },
                            placeholder = { Text("Paste your API Key here...") },
                            visualTransformation = if (obscureKey) PasswordVisualTransformation() else VisualTransformation.None,
                            trailingIcon = {
                                IconButton(onClick = { obscureKey = !obscureKey }) {
                                    Icon(
                                        if (obscureKey) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility,
                                        contentDescription = "Toggle visibility"
                                    )
                                }
                            },
                            singleLine = true,
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        // Base URL
                        OutlinedTextField(
                            value = baseUrl,
                            onValueChange = {
                                baseUrl = it
                                preferencesManager.setBaseUrl(selectedProvider, it)
                            },
                            label = { Text("API Base URL") },
                            placeholder = { Text(selectedProvider.defaultBaseUrl) },
                            singleLine = true,
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.fillMaxWidth()
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        // Model selection with Fetch
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            OutlinedTextField(
                                value = model,
                                onValueChange = {
                                    model = it
                                    preferencesManager.setModel(selectedProvider, it)
                                },
                                label = { Text("Model") },
                                singleLine = true,
                                shape = RoundedCornerShape(12.dp),
                                modifier = Modifier.weight(1f)
                            )

                            Button(
                                onClick = {
                                    isFetchingModels = true
                                    coroutineScope.launch {
                                        fetchedModels = aiService.fetchModels(selectedProvider, apiKey, baseUrl)
                                        isFetchingModels = false
                                        showModelDialog = true
                                    }
                                },
                                shape = RoundedCornerShape(12.dp),
                                enabled = !isFetchingModels,
                                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 14.dp)
                            ) {
                                if (isFetchingModels) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(16.dp),
                                        strokeWidth = 2.dp,
                                        color = MaterialTheme.colorScheme.onPrimary
                                    )
                                } else {
                                    Icon(Icons.Outlined.CloudDownload, contentDescription = null, modifier = Modifier.size(18.dp))
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text("Models", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }

                        // Popular models chips
                        if (selectedProvider.popularModels.isNotEmpty()) {
                            Spacer(modifier = Modifier.height(10.dp))
                            Text(
                                "Popular Models:",
                                fontSize = 11.5.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                items(selectedProvider.popularModels) { popularModel ->
                                    val isSelectedModel = model == popularModel
                                    FilterChip(
                                        selected = isSelectedModel,
                                        onClick = {
                                            model = popularModel
                                            preferencesManager.setModel(selectedProvider, popularModel)
                                        },
                                        label = {
                                            Text(
                                                popularModel,
                                                fontSize = 11.sp,
                                                fontWeight = if (isSelectedModel) FontWeight.Bold else FontWeight.Normal
                                            )
                                        },
                                        shape = RoundedCornerShape(10.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // ─── 3. Android Accessibility Service Status ────────────────────────────
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surface
                    ),
                    border = CardDefaults.outlinedCardBorder()
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Outlined.TouchApp,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.size(22.dp)
                                )
                                Spacer(modifier = Modifier.width(10.dp))
                                Text(
                                    "Screen Control Service",
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 16.sp
                                )
                            }

                            // Status Pill
                            Surface(
                                shape = CircleShape,
                                color = if (accessibilityEnabled) GreenSuccess.copy(alpha = 0.15f) else MaterialTheme.colorScheme.error.copy(alpha = 0.15f)
                            ) {
                                Row(
                                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(7.dp)
                                            .clip(CircleShape)
                                            .background(if (accessibilityEnabled) GreenSuccess else MaterialTheme.colorScheme.error)
                                    )
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Text(
                                        if (accessibilityEnabled) "Running" else "Disabled",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (accessibilityEnabled) GreenSuccess else MaterialTheme.colorScheme.error
                                    )
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            "Required for reading screen layouts, clicking coordinates, typing text, and executing multi-step autonomous tasks.",
                            fontSize = 12.5.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(14.dp))
                        OutlinedButton(
                            onClick = {
                                val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                context.startActivity(intent)
                            },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Icon(Icons.Outlined.SettingsAccessibility, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Open Accessibility Settings")
                        }
                    }
                }
            }

            // ─── 4. Agent Tuning Parameters ─────────────────────────────────────────
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(20.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surface
                    ),
                    border = CardDefaults.outlinedCardBorder()
                ) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Outlined.Tune,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(22.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Text(
                                "Agent Tuning",
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // Max Steps Slider
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Max Steps per Task", fontSize = 13.sp, fontWeight = FontWeight.Medium)
                            Text("${maxSteps.toInt()} steps", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                        }
                        Slider(
                            value = maxSteps,
                            onValueChange = {
                                maxSteps = it
                                preferencesManager.maxSteps = it.toInt()
                            },
                            valueRange = 5f..40f,
                            steps = 34
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        // Temperature Slider
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text("Creativity / Temperature", fontSize = 13.sp, fontWeight = FontWeight.Medium)
                            Text("%.2f".format(temperature), fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                        }
                        Slider(
                            value = temperature,
                            onValueChange = {
                                temperature = it
                                preferencesManager.temperature = it
                            },
                            valueRange = 0.0f..1.5f,
                            steps = 15
                        )

                        Spacer(modifier = Modifier.height(10.dp))

                        // System Prompt Switch
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Inject System Prompt", fontSize = 13.sp, fontWeight = FontWeight.Medium)
                                Text("Provides action format and device control instructions to model", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Switch(
                                checked = useSystemPrompt,
                                onCheckedChange = {
                                    useSystemPrompt = it
                                    preferencesManager.useSystemPrompt = it
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // Model Selection Dialog
    if (showModelDialog) {
        AlertDialog(
            onDismissRequest = { showModelDialog = false },
            title = { Text("Available Models for ${selectedProvider.displayName}") },
            text = {
                if (fetchedModels.isEmpty()) {
                    Text("No models returned. Using default model.")
                } else {
                    LazyColumn(modifier = Modifier.fillMaxWidth().heightIn(max = 300.dp)) {
                        items(fetchedModels) { m ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        model = m
                                        preferencesManager.setModel(selectedProvider, m)
                                        showModelDialog = false
                                    }
                                    .padding(vertical = 12.dp, horizontal = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    m,
                                    fontSize = 13.sp,
                                    fontWeight = if (m == model) FontWeight.Bold else FontWeight.Normal,
                                    color = if (m == model) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
                                )
                            }
                            HorizontalDivider()
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showModelDialog = false }) {
                    Text("Close")
                }
            }
        )
    }
}
