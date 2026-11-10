import 'package:flutter/services.dart';

class OnboardingState {
  const OnboardingState({required this.completed, this.page = 0});

  final bool completed;
  final int page;

  static const complete = OnboardingState(completed: true, page: 2);
}

abstract interface class OnboardingStore {
  Future<OnboardingState> load();
  Future<void> savePage(int page);
  Future<void> complete();
}

/// Replaying the introduction never reads or writes first-run preferences.
class ReplayOnboardingStore implements OnboardingStore {
  const ReplayOnboardingStore();
  @override
  Future<OnboardingState> load() async =>
      const OnboardingState(completed: false);
  @override
  Future<void> savePage(int page) async {}
  @override
  Future<void> complete() async {}
}

class AndroidOnboardingStore implements OnboardingStore {
  const AndroidOnboardingStore();

  static const channel = MethodChannel('com.xrecorder/onboarding');

  @override
  Future<OnboardingState> load() async {
    final value = await channel.invokeMapMethod<String, Object?>('read');
    if (value == null || value['completed'] is! bool || value['page'] is! int) {
      throw const FormatException('Invalid onboarding state');
    }
    return OnboardingState(
      completed: value['completed']! as bool,
      page: (value['page']! as int).clamp(0, 2).toInt(),
    );
  }

  @override
  Future<void> savePage(int page) {
    if (page < 0 || page > 2) {
      throw RangeError.range(page, 0, 2, 'page');
    }
    return channel.invokeMethod<void>('savePage', page);
  }

  @override
  Future<void> complete() => channel.invokeMethod<void>('complete');
}
