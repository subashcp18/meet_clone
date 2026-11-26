abstract final class ApiEndpoints {
  // region: BASE
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.meetclone.example.com/v1',
  );
  // endregion

  // region: AUTH
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';
  // endregion

  // region: MEETINGS
  static const String meetings = '/meetings';
  static const String createMeeting = '/meetings';
  static String meetingByCode(String code) => '/meetings/$code';
  static String joinMeeting(String code) => '/meetings/$code/join';
  static String leaveMeeting(String code) => '/meetings/$code/leave';
  static String endMeeting(String code) => '/meetings/$code/end';
  // endregion

  // region: PARTICIPANTS
  static String participants(String code) => '/meetings/$code/participants';
  static String muteParticipant(String code, String participantId) =>
      '/meetings/$code/participants/$participantId/mute';
  static String removeParticipant(String code, String participantId) =>
      '/meetings/$code/participants/$participantId';
  // endregion

  // region: CHAT
  static String chatMessages(String code) => '/meetings/$code/chat';
  static String sendChatMessage(String code) => '/meetings/$code/chat';
  // endregion
}
