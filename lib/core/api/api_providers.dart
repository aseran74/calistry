import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_client.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';

/// Token de sesión (cuando tengas auth). Mientras tanto null para anon.
final accessTokenProvider = StateProvider<String?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(accessTokenProvider);
  final session = ref.watch(authControllerProvider).session;
  return ApiClient(
    accessToken: token,
    userId: session?.user.id,
  );
});
