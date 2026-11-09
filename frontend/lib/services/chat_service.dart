import '../core/constants/app_constants.dart';
import '../models/conversation_model.dart';
import '../models/chat_message_model.dart';
import 'api_service.dart';
import 'profile_service.dart';
import 'storage_service.dart';

class ChatService {
  final ApiService _apiService;
  final ProfileService _profileService;
  final StorageService _storageService;
  String? _cachedUsername;

  ChatService({
    ApiService? apiService,
    ProfileService? profileService,
    StorageService? storageService,
  }) : _apiService = apiService ?? ApiService(),
       _profileService =
           profileService ?? ProfileService(apiService: apiService),
       _storageService = storageService ?? StorageService();

  /// Build the authenticated WebSocket URL for [conversationId] using [AppConstants.chatWebSocketUrl].
  Future<String> getConversationWebSocketUrl(int conversationId) async {
    final token = await _storageService.getAccessToken();
    return AppConstants.chatWebSocketUrl(conversationId, token: token);
  }

  /// Retrieve authenticated user's username (cached after first fetch)
  Future<String> getCurrentUsername() async {
    if (_cachedUsername != null && _cachedUsername!.isNotEmpty) {
      return _cachedUsername!;
    }
    try {
      final profile = await _profileService.getProfile();
      _cachedUsername = profile.username;
      return _cachedUsername!;
    } catch (_) {
      return _cachedUsername ?? '';
    }
  }

  /// Fetch all conversations for the authenticated user
  Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await _apiService.get(
        AppConstants.conversationsEndpoint,
      );
      return _parseConversationList(response.data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load conversations: $e');
    }
  }

  /// Get or create a conversation with a specific user ID
  Future<ConversationModel> getOrCreateConversation(int partnerUserId) async {
    try {
      final response = await _apiService.post(
        AppConstants.conversationsEndpoint,
        data: {'user_id': partnerUserId},
      );

      if (response.data is Map) {
        return ConversationModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ApiException('Invalid server response format.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to start conversation: $e');
    }
  }

  /// Fetch messages for a specific conversation
  Future<List<ChatMessageModel>> getMessages(int conversationId) async {
    try {
      final endpoint = AppConstants.conversationMessagesEndpoint(
        conversationId,
      );
      final response = await _apiService.get(endpoint);
      return _parseMessageList(response.data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load messages: $e');
    }
  }

  /// Send a message within a conversation
  Future<ChatMessageModel> sendMessage(int conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ApiException('Message cannot be empty.');
    }

    try {
      final endpoint = AppConstants.conversationMessagesEndpoint(
        conversationId,
      );
      final response = await _apiService.post(
        endpoint,
        data: {'message': trimmed},
      );

      if (response.data is Map) {
        return ChatMessageModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      throw ApiException('Invalid server response format.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to send message: $e');
    }
  }

  List<ConversationModel> _parseConversationList(dynamic data) {
    List items = [];
    if (data is List) {
      items = data;
    } else if (data is Map) {
      if (data['results'] is List) {
        items = data['results'];
      } else if (data['data'] is List) {
        items = data['data'];
      } else if (data['conversations'] is List) {
        items = data['conversations'];
      }
    }

    return items
        .whereType<Map>()
        .map(
          (item) => ConversationModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  List<ChatMessageModel> _parseMessageList(dynamic data) {
    List items = [];
    if (data is List) {
      items = data;
    } else if (data is Map) {
      if (data['results'] is List) {
        items = data['results'];
      } else if (data['data'] is List) {
        items = data['data'];
      } else if (data['messages'] is List) {
        items = data['messages'];
      }
    }

    return items
        .whereType<Map>()
        .map(
          (item) => ChatMessageModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
