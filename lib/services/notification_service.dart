import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../utils/format_utils.dart';
import '../utils/rotto_character.dart';
import '../utils/rotto_score.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _dailyChannelId = 'scrolltoll_daily';
  static const _moodChannelId = 'rotto_mood';
  static const _dailyNotifId = 1;
  static const _moodNotifId = 2;

  static Future<void> init() async {
    tzdata.initializeTimeZones();

    // Without this, `tz.local` stays UTC and every "9pm" reminder was actually
    // scheduled for 9pm UTC — the middle of the night across most of the world.
    // This was the reason notifications appeared not to work at all.
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // An identifier the tz database does not know would throw. UTC is a poor
      // fallback, but better than failing to initialise notifications at all.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _dailyChannelId,
        'Daily report',
        description: 'A short nudge at the end of the day.',
        importance: Importance.defaultImportance,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _moodChannelId,
        'Rotto’s mood',
        description: 'Sent when Rotto’s mood changes during the day.',
        importance: Importance.defaultImportance,
      ),
    );
  }

  /// The repeating end-of-day nudge.
  ///
  /// Deliberately carries no figures. It repeats daily via
  /// [DateTimeComponents.time], so a body baked with today's numbers would be
  /// re-shown verbatim tomorrow — on any day the app was not opened it would
  /// state yesterday's total as today's. Real numbers go in the mood
  /// notification instead, which is sent at the moment it is true.
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await _plugin.cancel(_dailyNotifId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyNotifId,
      'How did today go?',
      'Open Rotto to see your screen time and how he is holding up.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannelId,
          'Daily report',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Sent the moment Rotto's mood changes, showing the pose he just moved into.
  ///
  /// The image is one of the same `rotto_*` drawables the home widget renders,
  /// so the mood a notification shows is the mood everything else is showing.
  static Future<void> notifyMoodChange({
    required RottoState state,
    required int totalMinutes,
  }) async {
    final name = RottoCharacter.nameFor(state);
    final drawable = RottoCharacter.drawableNameFor(state);
    final title = 'Rotto is now $name';
    final body =
        '${formatDuration(totalMinutes)} today — '
        '${RottoCharacter.captionFor(state)}';

    await _plugin.show(
      _moodNotifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _moodChannelId,
          'Rotto’s mood',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          largeIcon: DrawableResourceAndroidBitmap(drawable),
          styleInformation: BigPictureStyleInformation(
            DrawableResourceAndroidBitmap(drawable),
            hideExpandedLargeIcon: true,
            contentTitle: title,
            summaryText: body,
          ),
        ),
      ),
    );
  }

  static Future<void> cancel() async {
    await _plugin.cancel(_dailyNotifId);
    await _plugin.cancel(_moodNotifId);
  }

  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }
}
