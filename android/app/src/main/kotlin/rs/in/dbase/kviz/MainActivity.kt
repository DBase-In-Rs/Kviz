package rs.`in`.dbase.kviz

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val playIntegrityChannel = "rs.in.dbase.kviz/play_integrity"
    private val playGamesChannel = "rs.in.dbase.kviz/play_games"
    private var playGamesEnabled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
        initializePlayGamesIfConfigured()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, playIntegrityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestIntegrityToken" -> {
                        val nonce = call.argument<String>("nonce")?.trim().orEmpty()
                        if (nonce.isEmpty()) {
                            result.error(
                                "PLAY_INTEGRITY_INVALID_ARGUMENT",
                                "nonce is required",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        val request = IntegrityTokenRequest.builder()
                            .setNonce(nonce)
                            .build()

                        IntegrityManagerFactory.create(applicationContext)
                            .requestIntegrityToken(request)
                            .addOnSuccessListener { response ->
                                result.success(response.token())
                            }
                            .addOnFailureListener { exception ->
                                result.error(
                                    "PLAY_INTEGRITY_ERROR",
                                    exception.message ?: exception.javaClass.simpleName,
                                    null,
                                )
                            }
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, playGamesChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "unlockFirstGameAchievement" -> unlockFirstGameAchievement(result)
                    "unlockAchievement" -> {
                        val achievementKey = call.argument<String>("achievementKey")
                            ?.trim()
                            .orEmpty()
                        unlockAchievement(achievementKey, result)
                    }
                    "submitLeaderboardScore" -> {
                        val leaderboardMode = call.argument<String>("leaderboardMode")
                            ?.trim()
                            .orEmpty()
                        val scoreArg = call.argument<Any>("score")
                        val score = (scoreArg as? Number)?.toLong()
                        submitLeaderboardScore(leaderboardMode, score, result)
                    }
                    "showLeaderboard" -> {
                        val leaderboardMode = call.argument<String>("leaderboardMode")
                            ?.trim()
                            .orEmpty()
                        showLeaderboard(leaderboardMode, result)
                    }
                    "showAllLeaderboards" -> showAllLeaderboards(result)
                    "showAchievements" -> showAchievements(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun initializePlayGamesIfConfigured() {
        val projectId = getString(R.string.app_id).trim()
        if (projectId.isBlank()) {
            playGamesEnabled = false
            return
        }

        runCatching {
            PlayGamesSdk.initialize(this)
            playGamesEnabled = true
        }.onFailure {
            playGamesEnabled = false
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channelId = getString(R.string.kviz_match_channel_id)
        val channelName = getString(R.string.kviz_match_channel_name)
        val channel = NotificationChannel(
            channelId,
            channelName,
            NotificationManager.IMPORTANCE_HIGH,
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun unlockFirstGameAchievement(result: MethodChannel.Result) {
        unlockAchievement("first_game", result)
    }

    private fun unlockAchievement(achievementKey: String, result: MethodChannel.Result) {
        if (!playGamesEnabled) {
            result.success(false)
            return
        }

        val achievementId = achievementIdForKey(achievementKey)
        if (achievementId.isBlank()) {
            result.success(false)
            return
        }

        withAuthenticatedPlayer(result, interactive = false) {
            PlayGames.getAchievementsClient(this)
                .unlockImmediate(achievementId)
                .addOnSuccessListener { result.success(true) }
                .addOnFailureListener { exception ->
                    result.error(
                        "PLAY_GAMES_ACHIEVEMENT_ERROR",
                        exception.message ?: exception.javaClass.simpleName,
                        null,
                    )
                }
        }
    }

    private fun submitLeaderboardScore(
        leaderboardMode: String,
        score: Long?,
        result: MethodChannel.Result,
    ) {
        if (!playGamesEnabled || score == null || score < 0) {
            result.success(false)
            return
        }

        val leaderboardId = leaderboardIdForMode(leaderboardMode)
        if (leaderboardId.isBlank()) {
            result.success(false)
            return
        }

        withAuthenticatedPlayer(result, interactive = true) {
            PlayGames.getLeaderboardsClient(this)
                .submitScoreImmediate(leaderboardId, score)
                .addOnSuccessListener { result.success(true) }
                .addOnFailureListener { exception ->
                    result.error(
                        "PLAY_GAMES_LEADERBOARD_SUBMIT_ERROR",
                        exception.message ?: exception.javaClass.simpleName,
                        null,
                    )
                }
        }
    }

    private fun showLeaderboard(leaderboardMode: String, result: MethodChannel.Result) {
        if (!playGamesEnabled) {
            result.success(false)
            return
        }

        val leaderboardId = leaderboardIdForMode(leaderboardMode)
        if (leaderboardId.isBlank()) {
            result.success(false)
            return
        }

        withAuthenticatedPlayer(result, interactive = true) {
            PlayGames.getLeaderboardsClient(this)
                .getLeaderboardIntent(leaderboardId)
                .addOnSuccessListener { intent ->
                    startActivity(intent)
                    result.success(true)
                }
                .addOnFailureListener { exception ->
                    result.error(
                        "PLAY_GAMES_LEADERBOARD_UI_ERROR",
                        exception.message ?: exception.javaClass.simpleName,
                        null,
                    )
                }
        }
    }

    private fun showAllLeaderboards(result: MethodChannel.Result) {
        if (!playGamesEnabled) {
            result.success(false)
            return
        }

        withAuthenticatedPlayer(result, interactive = true) {
            PlayGames.getLeaderboardsClient(this)
                .getAllLeaderboardsIntent()
                .addOnSuccessListener { intent ->
                    startActivity(intent)
                    result.success(true)
                }
                .addOnFailureListener { exception ->
                    result.error(
                        "PLAY_GAMES_LEADERBOARDS_UI_ERROR",
                        exception.message ?: exception.javaClass.simpleName,
                        null,
                    )
                }
        }
    }

    private fun withAuthenticatedPlayer(
        result: MethodChannel.Result,
        interactive: Boolean,
        action: () -> Unit,
    ) {
        val signInClient = PlayGames.getGamesSignInClient(this)
        signInClient
            .isAuthenticated()
            .addOnSuccessListener authCheck@{ authResult ->
                if (authResult.isAuthenticated) {
                    action()
                    return@authCheck
                }

                if (!interactive) {
                    result.success(false)
                    return@authCheck
                }

                signInClient
                    .signIn()
                    .addOnSuccessListener signIn@{ signInResult ->
                        if (!signInResult.isAuthenticated) {
                            result.success(false)
                            return@signIn
                        }

                        action()
                    }
                    .addOnFailureListener { exception ->
                        result.error(
                            "PLAY_GAMES_SIGN_IN_ERROR",
                            exception.message ?: exception.javaClass.simpleName,
                            null,
                        )
                    }
            }
            .addOnFailureListener { exception ->
                result.error(
                    "PLAY_GAMES_AUTH_ERROR",
                    exception.message ?: exception.javaClass.simpleName,
                    null,
                )
            }
    }

    private fun achievementIdForKey(achievementKey: String): String {
        return when (achievementKey) {
            "first_game" -> getString(R.string.achievement_1st)
            "seven_correct_streak" -> getString(R.string.achievement_7_tanih_u_nizu)
            "one_thousand_points" -> getString(R.string.achievement_1000_poena)
            "my_number_perfect" -> getString(R.string.achievement_moj_broj_bez_greke)
            "top_10_leaderboard" -> getString(R.string.achievement_top_10_rang_lista)
            else -> ""
        }.trim()
    }

    private fun leaderboardIdForMode(leaderboardMode: String): String {
        return when (leaderboardMode) {
            "pitanja", "questions", "ko_zna_zna" -> getString(R.string.leaderboard_pitanja)
            "asocijacije", "associations" -> getString(R.string.leaderboard_asocijacije)
            "moj_broj", "my_number" -> getString(R.string.leaderboard_moj_broj)
            "tangram", "tangram_plus" -> getString(R.string.leaderboard_tangram)
            "daily", "dnevni_izazov", "kviz_plus" -> getString(R.string.leaderboard_dnevni_izazov)
            else -> ""
        }.trim()
    }

    private fun showAchievements(result: MethodChannel.Result) {
        if (!playGamesEnabled) {
            result.success(false)
            return
        }

        withAuthenticatedPlayer(result, interactive = true) {
            openAchievements(result)
        }
    }

    private fun openAchievements(result: MethodChannel.Result) {
        PlayGames.getAchievementsClient(this)
            .getAchievementsIntent()
            .addOnSuccessListener { intent ->
                startActivity(intent)
                result.success(true)
            }
            .addOnFailureListener { exception ->
                result.error(
                    "PLAY_GAMES_ACHIEVEMENTS_UI_ERROR",
                    exception.message ?: exception.javaClass.simpleName,
                    null,
                )
            }
    }
}
