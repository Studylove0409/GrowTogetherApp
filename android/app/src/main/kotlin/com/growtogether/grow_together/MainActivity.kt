package com.growtogether.grow_together

import android.Manifest
import android.content.ContentValues
import android.content.ContentUris
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.CalendarContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private class NoWritableCalendarException : IllegalStateException("No writable calendar found")
    private class CalendarReminderNotCreatedException :
        IllegalStateException("Calendar event was created, but reminder was not enabled")

    private data class CalendarReminderRequest(
        val title: String,
        val startMillis: Long,
        val endMillis: Long,
        val repeatsDaily: Boolean,
        val repeatUntilMillis: Long?,
    )

    private data class WritableCalendar(
        val id: Long,
        val reminderMethod: Int,
    )

    private var pendingCalendarRequest: CalendarReminderRequest? = null
    private var pendingCalendarResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "grow_together/system_reminders",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "createCalendarReminder" -> {
                    val title = call.argument<String>("title") ?: "一起进步呀计划提醒"
                    val startMillis = call.argument<Long>("startMillis")
                    val endMillis = call.argument<Long>("endMillis")
                    val repeatsDaily = call.argument<Boolean>("repeatsDaily") ?: false
                    val repeatUntilMillis = call.argument<Long>("repeatUntilMillis")

                    if (startMillis == null || endMillis == null || endMillis <= startMillis) {
                        result.error(
                            "invalid_arguments",
                            "valid startMillis and endMillis are required",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val request = CalendarReminderRequest(
                        title = title,
                        startMillis = startMillis,
                        endMillis = endMillis,
                        repeatsDaily = repeatsDaily,
                        repeatUntilMillis = repeatUntilMillis,
                    )
                    createCalendarReminderWithPermission(request, result)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "grow_together/avatar_saver",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveAvatar" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename")
                    val mimeType = call.argument<String>("mimeType") ?: "image/jpeg"

                    if (bytes == null || bytes.isEmpty() || filename.isNullOrBlank()) {
                        result.error("invalid_arguments", "Avatar bytes and filename are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = saveAvatarImage(bytes, filename, mimeType)
                        result.success(uri.toString())
                    } catch (error: Exception) {
                        result.error("save_failed", error.message ?: "Avatar save failed", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALENDAR_PERMISSION_REQUEST_CODE) return

        val result = pendingCalendarResult
        val request = pendingCalendarRequest
        pendingCalendarResult = null
        pendingCalendarRequest = null
        if (result == null || request == null) return

        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        if (!granted) {
            result.error(
                "calendar_permission_denied",
                "Calendar permission was denied",
                null,
            )
            return
        }

        createCalendarReminderCatching(request, result)
    }

    private fun createCalendarReminderWithPermission(
        request: CalendarReminderRequest,
        result: MethodChannel.Result,
    ) {
        if (!hasCalendarPermission()) {
            if (pendingCalendarResult != null) {
                result.error(
                    "calendar_request_in_progress",
                    "Another calendar permission request is in progress",
                    null,
                )
                return
            }

            pendingCalendarRequest = request
            pendingCalendarResult = result
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                requestPermissions(
                    arrayOf(
                        Manifest.permission.READ_CALENDAR,
                        Manifest.permission.WRITE_CALENDAR,
                    ),
                    CALENDAR_PERMISSION_REQUEST_CODE,
                )
            }
            return
        }

        createCalendarReminderCatching(request, result)
    }

    private fun createCalendarReminderCatching(
        request: CalendarReminderRequest,
        result: MethodChannel.Result,
    ) {
        try {
            val eventId = createCalendarReminder(request)
            result.success(eventId)
        } catch (error: NoWritableCalendarException) {
            result.error("calendar_no_writable_calendar", error.message, null)
        } catch (error: CalendarReminderNotCreatedException) {
            result.error("calendar_reminder_not_created", error.message, null)
        } catch (error: SecurityException) {
            result.error("calendar_permission_denied", error.message, null)
        } catch (error: Exception) {
            result.error("calendar_setup_failed", error.message, null)
        }
    }

    private fun hasCalendarPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.WRITE_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun createCalendarReminder(request: CalendarReminderRequest): Long {
        val calendar = findOrCreateAppCalendar() ?: findWritableCalendar()
            ?: throw NoWritableCalendarException()
        val timezone = TimeZone.getDefault().id
        val eventValues = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendar.id)
            put(CalendarContract.Events.TITLE, request.title)
            put(CalendarContract.Events.DESCRIPTION, "来自一起进步呀的计划提醒")
            put(CalendarContract.Events.DTSTART, request.startMillis)
            put(CalendarContract.Events.EVENT_TIMEZONE, timezone)
            put(CalendarContract.Events.HAS_ALARM, 1)
            if (request.repeatsDaily) {
                put(CalendarContract.Events.DURATION, "PT15M")
                put(CalendarContract.Events.RRULE, buildDailyRrule(request.repeatUntilMillis))
            } else {
                put(CalendarContract.Events.DTEND, request.endMillis)
            }
        }

        val eventUri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, eventValues)
            ?: throw IllegalStateException("Unable to create calendar event")
        val eventId = ContentUris.parseId(eventUri)
        val reminderValues = ContentValues().apply {
            put(CalendarContract.Reminders.EVENT_ID, eventId)
            put(CalendarContract.Reminders.MINUTES, 0)
            put(
                CalendarContract.Reminders.METHOD,
                calendar.reminderMethod,
            )
        }
        contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, reminderValues)
            ?: throw IllegalStateException("Unable to create calendar reminder")
        contentResolver.update(
            ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId),
            ContentValues().apply {
                put(CalendarContract.Events.HAS_ALARM, 1)
            },
            null,
            null,
        )
        if (!hasReminder(eventId)) {
            throw CalendarReminderNotCreatedException()
        }
        return eventId
    }

    private fun findOrCreateAppCalendar(): WritableCalendar? {
        findAppCalendarId()?.let {
            return WritableCalendar(it, CalendarContract.Reminders.METHOD_ALERT)
        }

        return try {
            val values = ContentValues().apply {
                put(CalendarContract.Calendars.ACCOUNT_NAME, APP_CALENDAR_ACCOUNT_NAME)
                put(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
                put(CalendarContract.Calendars.NAME, APP_CALENDAR_NAME)
                put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, APP_CALENDAR_NAME)
                put(CalendarContract.Calendars.CALENDAR_COLOR, APP_CALENDAR_COLOR)
                put(
                    CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
                    CalendarContract.Calendars.CAL_ACCESS_OWNER,
                )
                put(CalendarContract.Calendars.OWNER_ACCOUNT, APP_CALENDAR_ACCOUNT_NAME)
                put(CalendarContract.Calendars.VISIBLE, 1)
                put(CalendarContract.Calendars.SYNC_EVENTS, 1)
                put(
                    CalendarContract.Calendars.ALLOWED_REMINDERS,
                    CalendarContract.Reminders.METHOD_ALERT.toString(),
                )
                put(
                    CalendarContract.Calendars.ALLOWED_AVAILABILITY,
                    CalendarContract.Events.AVAILABILITY_BUSY.toString(),
                )
            }
            val uri = contentResolver.insert(appCalendarSyncAdapterUri(), values)
                ?: return null
            WritableCalendar(ContentUris.parseId(uri), CalendarContract.Reminders.METHOD_ALERT)
        } catch (_: Exception) {
            null
        }
    }

    private fun findAppCalendarId(): Long? {
        val projection = arrayOf(CalendarContract.Calendars._ID)
        val selection =
            "${CalendarContract.Calendars.ACCOUNT_NAME} = ? AND " +
                "${CalendarContract.Calendars.ACCOUNT_TYPE} = ? AND " +
                "${CalendarContract.Calendars.NAME} = ?"
        val args = arrayOf(
            APP_CALENDAR_ACCOUNT_NAME,
            CalendarContract.ACCOUNT_TYPE_LOCAL,
            APP_CALENDAR_NAME,
        )
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            args,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getLong(0)
        }
        return null
    }

    private fun appCalendarSyncAdapterUri(): Uri {
        return CalendarContract.Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(
                CalendarContract.Calendars.ACCOUNT_NAME,
                APP_CALENDAR_ACCOUNT_NAME,
            )
            .appendQueryParameter(
                CalendarContract.Calendars.ACCOUNT_TYPE,
                CalendarContract.ACCOUNT_TYPE_LOCAL,
            )
            .build()
    }

    private fun findWritableCalendar(): WritableCalendar? {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
            CalendarContract.Calendars.VISIBLE,
            CalendarContract.Calendars.SYNC_EVENTS,
            CalendarContract.Calendars.ALLOWED_REMINDERS,
        )
        val selection =
            "${CalendarContract.Calendars.VISIBLE} = ? AND " +
                "${CalendarContract.Calendars.SYNC_EVENTS} = ? AND " +
                "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?"
        val args = arrayOf(
            "1",
            "1",
            CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString(),
        )
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            args,
            null,
        )?.use { cursor ->
            var fallback: WritableCalendar? = null
            while (cursor.moveToNext()) {
                val calendarId = cursor.getLong(0)
                val allowedReminders = cursor.getString(4)
                val reminderMethod = reminderMethodFor(allowedReminders) ?: continue
                val calendar = WritableCalendar(calendarId, reminderMethod)
                if (reminderMethod == CalendarContract.Reminders.METHOD_ALERT) {
                    return calendar
                }
                if (fallback == null) fallback = calendar
            }
            return fallback
        }
        return null
    }

    private fun reminderMethodFor(allowedReminders: String?): Int? {
        if (allowedReminders.isNullOrBlank()) {
            return CalendarContract.Reminders.METHOD_ALERT
        }

        val supported = allowedReminders
            .split(",")
            .mapNotNull { it.trim().toIntOrNull() }
            .toSet()

        return when {
            CalendarContract.Reminders.METHOD_ALERT in supported ->
                CalendarContract.Reminders.METHOD_ALERT
            CalendarContract.Reminders.METHOD_DEFAULT in supported ->
                CalendarContract.Reminders.METHOD_DEFAULT
            else -> null
        }
    }

    private fun hasReminder(eventId: Long): Boolean {
        val projection = arrayOf(CalendarContract.Reminders._ID)
        val selection = "${CalendarContract.Reminders.EVENT_ID} = ?"
        val args = arrayOf(eventId.toString())
        contentResolver.query(
            CalendarContract.Reminders.CONTENT_URI,
            projection,
            selection,
            args,
            null,
        )?.use { cursor ->
            return cursor.moveToFirst()
        }
        return false
    }

    private fun buildDailyRrule(repeatUntilMillis: Long?): String {
        if (repeatUntilMillis == null) return "FREQ=DAILY"
        val until = SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(repeatUntilMillis))
        return "FREQ=DAILY;UNTIL=$until"
    }

    private fun saveAvatarImage(bytes: ByteArray, filename: String, mimeType: String): Uri {
        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, filename)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/GrowTogether",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Unable to create image file")

        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IllegalStateException("Unable to open image output stream")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }

            return uri
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    companion object {
        private const val CALENDAR_PERMISSION_REQUEST_CODE = 4132
        private const val APP_CALENDAR_ACCOUNT_NAME = "grow_together_local"
        private const val APP_CALENDAR_NAME = "一起进步呀"
        private const val APP_CALENDAR_COLOR = 0xFFFF8FAB.toInt()
    }
}
