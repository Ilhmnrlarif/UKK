import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../services/navigation_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'task_reminders',
          channelName: 'Pengingat Tugas',
          channelDescription: 'Notifikasi untuk pengingat tugas',
          defaultColor: Colors.blue,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          locked: true,
          defaultRingtoneType: DefaultRingtoneType.Alarm,
        ),
      ],
      debug: true,
    );

    // Menangani ketika notifikasi diklik
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: (ReceivedAction receivedAction) async {
        debugPrint('Notification clicked: ${receivedAction.id}');
        return;
      },
    );
  }

  Future<void> scheduleTaskNotification({
    required dynamic taskId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? category,
    String? notes,
  }) async {
    try {
      final int notificationId = taskId.toString().hashCode;
      
      // Konversi ke zona waktu lokal
      final now = DateTime.now();
      var scheduledDateTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        scheduledDate.hour,
        scheduledDate.minute,
      );

      // Jika waktu sudah lewat, jadwalkan untuk besok
      if (scheduledDateTime.isBefore(now)) {
        scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
        debugPrint('Waktu sudah lewat, dijadwalkan untuk besok: $scheduledDateTime');
      }

      // Siapkan konten notifikasi
      String notificationBody = body;
      if (category != null) {
        notificationBody = 'Kategori: $category\n$body';
      }
      if (notes?.isNotEmpty == true) {
        notificationBody += '\n\nCatatan: $notes';
      }

      // Log informasi penjadwalan
      debugPrint('=== Penjadwalan Notifikasi ===');
      debugPrint('ID: $notificationId');
      debugPrint('Judul: $title');
      debugPrint('Isi: $notificationBody');
      debugPrint('Kategori: $category');
      debugPrint('Waktu sekarang: $now');
      debugPrint('Waktu dijadwalkan: $scheduledDateTime');
      debugPrint('Selisih waktu: ${scheduledDateTime.difference(now).inMinutes} menit');

      // Tampilkan notifikasi test terlebih dahulu
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId + 1,
          channelKey: 'task_reminders',
          title: title,
          body: 'Notifikasi tugas yang dijadwalkan pada ${scheduledDate.hour}:${scheduledDate.minute}',
          category: NotificationCategory.Reminder,
          wakeUpScreen: true,
          criticalAlert: true,
          autoDismissible: false,
        ),
      );

      // Jadwalkan notifikasi utama
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: 'task_reminders',
          title: title,
          body: notificationBody,
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
          criticalAlert: true,
          autoDismissible: false,
          locked: true,
        ),
        schedule: NotificationCalendar(
          year: scheduledDateTime.year,
          month: scheduledDateTime.month,
          day: scheduledDateTime.day,
          hour: scheduledDateTime.hour,
          minute: scheduledDateTime.minute,
          second: 0,
          millisecond: 0,
          repeats: false,
          allowWhileIdle: true,
          preciseAlarm: true,
          timeZone: await AwesomeNotifications().getLocalTimeZoneIdentifier(),
        ),
      );

      // Verifikasi penjadwalan
      final pendingNotifications = await AwesomeNotifications().listScheduledNotifications();
      debugPrint('Jumlah notifikasi terjadwal: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        debugPrint('Notifikasi terjadwal: ID=${notification.content?.id}, Title=${notification.content?.title}');
      }

      debugPrint('=== Notifikasi berhasil dijadwalkan ===');
    } catch (e) {
      debugPrint('Error menjadwalkan notifikasi: $e');
      rethrow;
    }
  }

  Future<void> cancelNotification(dynamic taskId) async {
    try {
      final int notificationId = taskId.toString().hashCode;
      await AwesomeNotifications().cancel(notificationId);
      debugPrint('Notifikasi dibatalkan untuk ID: $taskId');
    } catch (e) {
      debugPrint('Error membatalkan notifikasi: $e');
      rethrow;
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await AwesomeNotifications().cancelAll();
      debugPrint('Semua notifikasi dibatalkan');
    } catch (e) {
      debugPrint('Error membatalkan semua notifikasi: $e');
      rethrow;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        return await AwesomeNotifications().requestPermissionToSendNotifications();
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }
} 