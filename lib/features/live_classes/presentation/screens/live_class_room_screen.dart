import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calistenia_app/core/api/api_providers.dart';
import 'package:calistenia_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveClassRoomScreen extends ConsumerStatefulWidget {
  const LiveClassRoomScreen({
    super.key,
    required this.liveClassId,
  });

  final String liveClassId;

  @override
  ConsumerState<LiveClassRoomScreen> createState() =>
      _LiveClassRoomScreenState();
}

class _LiveClassRoomScreenState extends ConsumerState<LiveClassRoomScreen> {
  bool _loading = true;
  Map<String, dynamic>? _liveClass;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final liveClass = await client.getLiveClassById(widget.liveClassId);
      if (liveClass == null) throw Exception('Clase no encontrada.');
      if (!mounted) return;
      setState(() {
        _liveClass = liveClass;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _endClass() async {
    try {
      await ref.read(apiClientProvider).endLiveClass(widget.liveClassId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clase finalizada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _platformLabel(String? platform) {
    switch (platform) {
      case 'zoom':
        return 'Zoom';
      case 'google_meet':
        return 'Google Meet';
      case 'instagram_live':
        return 'Instagram Live';
      case 'tiktok_live':
        return 'TikTok Live';
      default:
        return platform?.toString() ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final myUserId = auth.session?.user.id;
    final isTeacher = _liveClass?['teacher_user_id']?.toString() == myUserId;
    final url = _liveClass?['meeting_url']?.toString().trim() ?? '';
    final platform = _liveClass?['platform']?.toString();
    final scheduledAt = _liveClass?['scheduled_at']?.toString();
    final status = _liveClass?['status']?.toString() ?? 'scheduled';

    return Scaffold(
      appBar: AppBar(
        title: Text(_liveClass?['title']?.toString() ?? 'Clase'),
        actions: [
          if (isTeacher && _liveClass?['status']?.toString() != 'ended')
            TextButton(
              onPressed: _endClass,
              child: const Text('Finalizar'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plataforma',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _platformLabel(platform),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Fecha y hora',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(scheduledAt ?? '—'),
                        const SizedBox(height: 14),
                        if ((_liveClass?['description']?.toString() ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          Text(
                            'Notas',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_liveClass!['description'].toString()),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          'Enlace',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(url.isEmpty ? '—' : url),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: (url.isEmpty || status == 'ended')
                                  ? null
                                  : () async {
                                      final uri = Uri.tryParse(url);
                                      if (uri == null) return;
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                              icon: const Icon(Icons.open_in_new, size: 20),
                              label: const Text('Abrir'),
                            ),
                            OutlinedButton.icon(
                              onPressed: url.isEmpty
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: url),
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Enlace copiado al portapapeles'),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.copy, size: 20),
                              label: const Text('Copiar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Estado: $status',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
