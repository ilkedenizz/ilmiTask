import 'package:flutter/material.dart';

class AppStrings {
  final String languageCode;

  const AppStrings(this.languageCode);

  bool get isTr => languageCode == 'tr';

  static AppStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final code = locale?.languageCode ?? 'tr';
    return AppStrings(code);
  }

  // --- TOP BAR & SEARCH ---
  String get appTitle => 'ilmi Task';
  String get searchHint => isTr ? 'Hatırlatıcı ara...' : 'Search reminders...';
  String get manageCategories => isTr ? 'Kategoriler' : 'Manage Categories';
  String get newReminder => isTr ? 'Yeni Hatırlatıcı' : 'New Reminder';
  String get editReminder => isTr ? 'Hatırlatıcıyı Düzenle' : 'Edit Reminder';
  String get addReminderFab => isTr ? 'Hatırlatıcı Ekle' : 'Add reminder';

  // --- FILTER PILLS ---
  String get all => isTr ? 'Tümü' : 'All';
  String get pinned => isTr ? 'Sabitlenen' : 'Pinned';
  String get completed => isTr ? 'Tamamlanan' : 'Completed';

  // --- BENTO SUMMARY CARDS ---
  String get summaryToday => isTr ? 'BUGÜN' : 'TODAY';
  String get summaryScheduled => isTr ? 'PLANLANAN' : 'SCHEDULED';
  String get summaryImportant => isTr ? 'ÖNEMLİ' : 'IMPORTANT';
  String get summaryLocation => isTr ? 'KONUM' : 'LOCATION';
  String get summaryDone => isTr ? 'BİTEN' : 'DONE';

  // --- SECTION HEADERS ---
  String pinnedSection(int count) => isTr ? 'SABİTLENEN ($count)' : 'PINNED ($count)';
  String overdueSection(int count) => isTr ? 'GECİKEN / GEÇMİŞ ($count)' : 'OVERDUE / PASSED ($count)';
  String upcomingSection(int count) => isTr ? 'YAKLAŞAN ($count)' : 'UPCOMING ($count)';
  String somedaySection(int count) => isTr ? 'TÜM GÖREVLER ($count)' : 'ALL TASKS ($count)';
  String completedSection(int count) => isTr ? 'TAMAMLANANLAR ($count)' : 'COMPLETED ($count)';

  // --- EMPTY STATES ---
  String get emptyActiveTitle => isTr ? 'Bekleyen görev yok' : 'No active reminders';
  String get emptyActiveSubtitle =>
      isTr ? 'Günün tadını çıkar veya yeni bir hatırlatıcı ekle' : 'Enjoy your day or tap + to create one';
  String get emptyFilterTitle => isTr ? 'Sonuç bulunamadı' : 'No matching reminders';
  String get emptyFilterSubtitle =>
      isTr ? 'Arama terimini veya seçili filtreyi değiştirmeyi dene' : 'Try searching for something else or clear filters';
  String get emptyAgendaTitle => isTr ? 'Bu gün için görev yok' : 'No tasks for this day';
  String get emptyAgendaSubtitle =>
      isTr ? 'Bu tarihe hızlıca bir görev eklemek için dokun' : 'Tap below to add a reminder for this date';

  // --- VIEW MODES ---
  String get viewList => isTr ? 'LİSTE' : 'LIST';
  String get viewCalendar => isTr ? 'AJANDA' : 'AGENDA';

  // --- EDITOR SHEET ---
  String get titleLabel => isTr ? 'Başlık' : 'Title';
  String get titleHint => isTr ? 'Ne hatırlatılmasını istersin?' : 'What do you need to be reminded of?';
  String get titleValidation => isTr ? 'Lütfen bir başlık gir' : 'Please enter a reminder title';
  String get notesLabel => isTr ? 'Notlar (isteğe bağlı)' : 'Notes (optional)';
  String get notesHint => isTr ? 'Ayrıntılar, kontrol maddeleri veya bağlantılar ekle' : 'Add extra details, checklist hints, or links';
  String get categoryLabel => isTr ? 'Kategori' : 'Category';
  String get pinLabel => isTr ? 'Sabitle' : 'Pin';
  String get scheduleDateTime => isTr ? 'Tarih ve Saat Seç' : 'Schedule Date & Time';
  String get noAlert => isTr ? 'Uyarısız' : 'No Alert';
  String get todayEvening => isTr ? 'Bu Akşam' : 'Today Evening';
  String get tomorrowMorning => isTr ? 'Yarın 09:00' : 'Tomorrow 09:00';
  String get nextWeek => isTr ? 'Gelecek Hafta' : 'Next Week';
  String get customDateTime => isTr ? 'Özel Tarih/Saat' : 'Custom Date/Time';
  String get preAlertLabel => isTr ? 'Erken Uyarı' : 'Pre-Alert';
  String get repeatLabel => isTr ? 'Tekrar' : 'Repeat';
  String get alertSeverityLabel => isTr ? 'Uyarı Şiddeti' : 'Alert Severity';
  String get severityLightTitle => isTr ? 'Hafif' : 'Light';
  String get severityLightSub => isTr ? 'Sessiz, bildirim paneli' : 'Silent, in shade';
  String get severityShortTitle => isTr ? 'Kısa' : 'Short';
  String get severityShortSub => isTr ? 'Standart zil sesi' : 'Standard chime';
  String get severityStrongTitle => isTr ? 'Güçlü' : 'Strong';
  String get severityStrongSub => isTr ? 'Tam ekran alarm' : 'Full-screen alarm';
  String checklistTitle(int count) => isTr ? 'Kontrol Listesi / Alt Görevler ($count)' : 'Checklist / Subtasks ($count)';
  String get addSubtaskHint => isTr ? 'Alt görev maddesi ekle...' : 'Add a subtask item...';
  String get photoAttachment => isTr ? 'Fotoğraf Eki' : 'Photo Attachment';
  String get fromGallery => isTr ? 'Galeriden' : 'From Gallery';
  String get takePhoto => isTr ? 'Fotoğraf Çek' : 'Take Photo';
  String get remove => isTr ? 'Kaldır' : 'Remove';
  String get locationTriggerSection => isTr ? 'Konum Uyarısı (Geofence)' : 'Location Trigger (Geofencing)';
  String get triggerTypeLabel => isTr ? 'TETİK TİPİ' : 'TRIGGER TYPE';
  String get arriving => isTr ? 'VARIŞ' : 'ARRIVING';
  String get leaving => isTr ? 'AYRILMA' : 'LEAVING';
  String get geofenceRadiusLabel => isTr ? 'GEOFENCE YARIÇAPI' : 'GEOFENCE RADIUS';
  String get coordinatesLabel => isTr ? 'KOORDİNATLAR' : 'COORDINATES';
  String get openDarkMapPicker => isTr ? 'Karanlık Haritayı Aç' : 'Open Dark Map Picker';
  String get save => isTr ? 'Kaydet' : 'Save';
  String get create => isTr ? 'Oluştur' : 'Create';
  String get cancel => isTr ? 'İptal' : 'Cancel';

  // --- ALARM SCREEN ---
  String get alarmActive => isTr ? 'ALARM AKTİF' : 'ALARM ACTIVE';
  String checklistAlarmTitle(int done, int total) => isTr ? 'KONTROL LİSTESİ ($done/$total)' : 'CHECKLIST ($done/$total)';
  String get snooze10m => isTr ? 'Ertele (+10m)' : 'Snooze (+10m)';
  String get dismissDone => isTr ? 'Dismiss / Done' : 'Dismiss / Done';
  String get alarmSnoozedMessage => isTr ? 'Alarm 10 dakika ertelendi' : 'Alarm snoozed for 10 minutes';

  // --- NOTIFICATION ACTIONS ---
  String get notifDoneAction => isTr ? '✓ Tamamla' : '✓ Done';
  String get notifSnoozeAction => isTr ? '🕒 Ertele (+10dk)' : '🕒 Snooze (+10m)';

  // --- SYSTEM SHIELD ---
  String get systemShieldTitle => isTr ? 'Sistem Güvenilirlik Kalkanı' : 'System Reliability Shield';
  String get shieldBatteryOptimization => isTr ? 'PİL OPTİMİZASYONU' : 'BATTERY OPTIMIZATION';
  String get shieldExactAlarms => isTr ? 'KESİN ALARMLAR' : 'EXACT ALARMS';
  String get shieldNotifications => isTr ? 'BİLDİRİM İZNİ' : 'POST NOTIFICATIONS';
  String get shieldGeofencing => isTr ? 'KONUM UYARILARI' : 'GEOLOCATION SERVICE';
  String get shieldBackgroundLocation => isTr ? 'ARKA PLAN KONUMU' : 'BACKGROUND LOCATION';
}

/// Global controller to switch language dynamically
class LocaleController extends ChangeNotifier {
  static final LocaleController instance = LocaleController._internal();
  LocaleController._internal();

  Locale _locale = const Locale('tr');
  Locale get locale => _locale;

  void setLocale(Locale loc) {
    if (_locale != loc) {
      _locale = loc;
      notifyListeners();
    }
  }

  void toggleLocale() {
    if (_locale.languageCode == 'tr') {
      setLocale(const Locale('en'));
    } else {
      setLocale(const Locale('tr'));
    }
  }
}
