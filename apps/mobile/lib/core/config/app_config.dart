abstract final class AppConfig {
  static const String name = String.fromEnvironment(
    'CONVOCOACH_APP_NAME',
    defaultValue: 'ConvoCoach',
  );

  static const bool mockMode = bool.fromEnvironment(
    'CONVOCOACH_MOCK_MODE',
    defaultValue: true,
  );
}
