import 'dart:math';

import 'package:cv_exec_feed/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _execIdKey = 'exec_id';
const _tabIndexKey = 'tab_index';
const _tabIndexMigratedKey = 'tab_index_v2_migrated';
const _tabIndexMigratedV3Key = 'tab_index_v3_migrated';
const _selectedJobKey = 'selected_job_id';
const _hidePassedKey = 'hide_passed';
const _themeModeKey = 'theme_mode';

class AppState {
  final String execId;
  final int selectedTabIndex;
  final String? selectedJobId;
  final bool hidePassed;
  final ThemeMode themeMode;

  const AppState({
    required this.execId,
    this.selectedTabIndex = 0,
    this.selectedJobId,
    this.hidePassed = false,
    this.themeMode = ThemeMode.system,
  });

  AppState copyWith({
    String? execId,
    int? selectedTabIndex,
    String? selectedJobId,
    bool clearSelectedJob = false,
    bool? hidePassed,
    ThemeMode? themeMode,
  }) {
    return AppState(
      execId: execId ?? this.execId,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      selectedJobId:
          clearSelectedJob ? null : (selectedJobId ?? this.selectedJobId),
      hidePassed: hidePassed ?? this.hidePassed,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class AppNotifier extends Notifier<AppState> {
  @override
  AppState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    var execId = prefs.getString(_execIdKey);
    if (execId == null || execId.isEmpty) {
      execId = _newExecId();
      prefs.setString(_execIdKey, execId);
    }
    final themeIndex = prefs.getInt(_themeModeKey);
    var tabIndex = prefs.getInt(_tabIndexKey) ?? 0;
    if (!(prefs.getBool(_tabIndexMigratedKey) ?? false)) {
      // Old order: Feed(0), Lists(1), Campaigns(2), Chat(3)
      // v2 order: Feed(0), Campaigns(1), Lists(2), Chat(3)
      if (tabIndex == 1) {
        tabIndex = 2;
      } else if (tabIndex == 2) {
        tabIndex = 1;
      }
      prefs.setInt(_tabIndexKey, tabIndex);
      prefs.setBool(_tabIndexMigratedKey, true);
    }
    if (!(prefs.getBool(_tabIndexMigratedV3Key) ?? false)) {
      // v3 order: Feed(0), Jobs(1), Campaigns(2), Lists(3), Chat(4)
      if (tabIndex >= 1) tabIndex += 1;
      prefs.setInt(_tabIndexKey, tabIndex);
      prefs.setBool(_tabIndexMigratedV3Key, true);
    }
    return AppState(
      execId: execId,
      selectedTabIndex: tabIndex,
      selectedJobId: prefs.getString(_selectedJobKey),
      hidePassed: prefs.getBool(_hidePassedKey) ?? false,
      themeMode: themeIndex != null && themeIndex < ThemeMode.values.length
          ? ThemeMode.values[themeIndex]
          : ThemeMode.system,
    );
  }

  void setTab(int index) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt(_tabIndexKey, index);
    state = state.copyWith(selectedTabIndex: index);
  }

  void selectJob(String? jobId) {
    final prefs = ref.read(sharedPreferencesProvider);
    if (jobId == null || jobId.isEmpty) {
      prefs.remove(_selectedJobKey);
      state = state.copyWith(clearSelectedJob: true);
    } else {
      prefs.setString(_selectedJobKey, jobId);
      state = state.copyWith(selectedJobId: jobId);
    }
  }

  void openCampaignReview(String jobId) {
    selectJob(jobId);
    setTab(2);
  }

  void setHidePassed(bool value) {
    ref.read(sharedPreferencesProvider).setBool(_hidePassedKey, value);
    state = state.copyWith(hidePassed: value);
  }

  void setExecId(String execId) {
    final trimmed = execId.trim();
    if (trimmed.isEmpty) return;
    ref.read(sharedPreferencesProvider).setString(_execIdKey, trimmed);
    state = state.copyWith(execId: trimmed);
  }

  void setThemeMode(ThemeMode mode) {
    ref.read(sharedPreferencesProvider).setInt(_themeModeKey, mode.index);
    state = state.copyWith(themeMode: mode);
  }
}

final appProvider = NotifierProvider<AppNotifier, AppState>(AppNotifier.new);

final execIdProvider = Provider<String>((ref) => ref.watch(appProvider).execId);

final selectedJobIdProvider = Provider<String?>((ref) {
  return ref.watch(appProvider).selectedJobId;
});

final hidePassedProvider = Provider<bool>((ref) {
  return ref.watch(appProvider).hidePassed;
});

String _newExecId() {
  final r = Random();
  return 'exec-${r.nextInt(0x7FFFFFFF)}-${DateTime.now().millisecondsSinceEpoch}';
}
