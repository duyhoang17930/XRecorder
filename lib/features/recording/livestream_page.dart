import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/domain/models.dart';
import '../../core/domain/repositories.dart';
import '../../core/widgets/studio_widgets.dart';
import '../../l10n/localization.dart';
import '../settings/settings_controller.dart';
import 'recording_service.dart';

final _liveRoutes = Expando<bool>();

Future<void> openLivestream(BuildContext context) async {
  final navigator = Navigator.of(context);
  if (_liveRoutes[navigator] == true) return;
  _liveRoutes[navigator] = true;
  try {
    await navigator.push<void>(
      MaterialPageRoute(builder: (_) => const LivestreamPage()),
    );
  } finally {
    _liveRoutes[navigator] = false;
  }
}

class LivestreamPage extends StatefulWidget {
  const LivestreamPage({super.key});
  @override
  State<LivestreamPage> createState() => _LivestreamPageState();
}

class _LivestreamPageState extends State<LivestreamPage>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _server = TextEditingController(), _key = TextEditingController();
  final _name = TextEditingController();
  LivestreamRecordingService? _adapter;
  LivestreamDestinationStore? _store;
  StreamSubscription<Map<String, dynamic>>? _events;
  Map<String, dynamic> _status = const {'state': 'idle'};
  bool _starting = false, _obscure = true;
  bool _storeBusy = false, _hasSaved = false, _loadFailed = false;
  String? _destinationNotice, _nameError;
  int _epoch = 0, _lastSecond = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = CaptureScope.of(context).service;
    if (_adapter != null || service is! LivestreamRecordingService) return;
    _adapter = service as LivestreamRecordingService;
    if (service is LivestreamDestinationStore) {
      _store = service as LivestreamDestinationStore;
      _loadDestination();
    }
    _events = _adapter!.liveStates.listen(
      (value) {
        _epoch++;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final update = value['state'] != _status['state'] || now != _lastSecond;
        _status = value;
        if (update &&
            mounted &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.paused) {
          _lastSecond = now;
          setState(() {});
        }
      },
      onError: (_) {
        if (mounted) setState(() => _status = {'state': 'unavailable'});
      },
    );
    _refresh();
  }

  Future<void> _refresh() async {
    final epoch = ++_epoch;
    try {
      final value = await _adapter?.currentLive();
      if (mounted && epoch == _epoch && value != null) {
        setState(() => _status = value);
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() => _status = {'state': 'unavailable'});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_obscure) {
      setState(() => _obscure = true);
    }
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _start() async {
    if (_starting ||
        _storeBusy ||
        CaptureScope.of(context).busy ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _starting = true;
      _obscure = true;
    });
    try {
      await CaptureScope.of(context).startLive(
        SettingsScope.of(context).recordingSnapshot,
        serverUrl: _server.text.trim(),
        streamKey: _key.text.trim(),
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        showFailure(context, error, operation: UserOperation.recording);
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _loadDestination() async {
    if (_storeBusy || _store == null) return;
    setState(() => _storeBusy = true);
    try {
      final saved = await _store!.loadLiveDestination();
      if (!mounted) return;
      setState(() {
        _hasSaved = saved != null;
        _loadFailed = false;
        _destinationNotice = null;
        if (saved != null) {
          _name.text = saved['name'] ?? '';
          _server.text = saved['serverUrl'] ?? '';
          _key.text = saved['streamKey'] ?? '';
          _obscure = true;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _destinationNotice = 'Could not load the saved destination. Retry, or forget it before saving a new one.';
        });
      }
    } finally {
      if (mounted) setState(() => _storeBusy = false);
    }
  }

  Future<void> _saveDestination() async {
    if (_storeBusy || _loadFailed || CaptureScope.of(context).busy) return;
    final name = _name.text.trim();
    setState(
      () => _nameError =
          name.isEmpty ||
              name.length > 80 ||
              name.contains(RegExp(r'[\x00-\x1f\x7f-\x9f]'))
          ? 'Enter a destination name of up to 80 characters.'
          : null,
    );
    if (!_form.currentState!.validate() || _nameError != null) return;
    setState(() {
      _storeBusy = true;
      _obscure = true;
    });
    try {
      await _store!.saveLiveDestination(
        name: name,
        serverUrl: _server.text.trim(),
        streamKey: _key.text.trim(),
      );
      if (mounted) {
        setState(() {
          _hasSaved = true;
          _destinationNotice = 'Destination saved on this device.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _destinationNotice = 'Could not save the destination. The previous saved destination was kept.',
        );
      }
    } finally {
      if (mounted) setState(() => _storeBusy = false);
    }
  }

  Future<void> _forgetDestination() async {
    if (_storeBusy || CaptureScope.of(context).busy) return;
    setState(() => _storeBusy = true);
    try {
      final forget = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.message('Forget saved destination?')),
          content: Text(
            context.message(
              'This removes only the saved livestream destination and clears these fields. Your recordings and projects are kept.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.message('Forget destination')),
            ),
          ],
        ),
      );
      if (forget != true || !mounted) return;
      await _store!.forgetLiveDestination();
      if (mounted) {
        setState(() {
          _hasSaved = false;
          _loadFailed = false;
          _nameError = null;
          _name.clear();
          _server.clear();
          _key.clear();
          _obscure = true;
          _destinationNotice = 'Saved destination removed.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _destinationNotice =
              'Could not remove the saved destination. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _storeBusy = false);
    }
  }

  String _label(BuildContext context) =>
      context.message(switch (_status['state']) {
        'awaitingPermission' => 'Waiting for screen sharing permission',
        'preparing' || 'connecting' => 'Connecting to livestream',
        'live' => 'Live connected',
        'reconnecting' => 'Reconnecting to livestream',
        'connection_failed' =>
          'Connection failed. Check the destination and network.',
        'authentication_failed' =>
          'Stream key rejected. Check the destination settings.',
        'configuration_failed' =>
          'Could not start the livestream. Check recording settings.',
        'interrupted' =>
          'Livestream interrupted. Enter the destination and start again.',
        'cancelled' => 'Livestream cancelled',
        'stopped' => 'Livestream ended',
        'unavailable' =>
          'Livestream status is unavailable. Try reopening this screen.',
        _ => 'Ready to livestream',
      });

  @override
  Widget build(BuildContext context) {
    final capture = CaptureScope.of(context);
    final ownsSession =
        _status['sessionId'] == capture.session?.id &&
        _status['state'] != 'idle';
    final busy = _starting || capture.busy || _storeBusy;
    final canStop =
        ownsSession &&
        capture.busy &&
        ![
          RecordingState.stopping,
          RecordingState.finalizing,
        ].contains(capture.session?.state);
    final h264 =
        SettingsScope.of(context).recordingSnapshot.codec == VideoCodec.avc;
    return Scaffold(
      appBar: AppBar(title: Text(context.message('Livestream'))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.message(
                          'Your selected screen and audio are sent to this destination. A local video is also saved. RTMP is unencrypted; use RTMPS when available.',
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('live-server'),
                        controller: _server,
                        enabled: !busy,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: context.message('Server URL'),
                          hintText: 'rtmps://server.example/live',
                        ),
                        validator: (value) {
                          final uri = Uri.tryParse(value?.trim() ?? '');
                          return uri != null &&
                                  const [
                                    'rtmp',
                                    'rtmps',
                                  ].contains(uri.scheme) &&
                                  uri.host.isNotEmpty &&
                                  uri.path.replaceAll('/', '').isNotEmpty &&
                                  uri.userInfo.isEmpty &&
                                  !uri.hasQuery &&
                                  !uri.hasFragment &&
                                  (value?.trim().length ?? 0) <= 4096 &&
                                  (!uri.hasPort ||
                                      (uri.port >= 1 && uri.port <= 65535))
                              ? null
                              : context.message(
                                  'Enter an RTMP or RTMPS server URL with an application path.',
                                );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('live-key'),
                        controller: _key,
                        enabled: !busy,
                        obscureText: _obscure,
                        textDirection: TextDirection.ltr,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableIMEPersonalizedLearning: false,
                        decoration: InputDecoration(
                          labelText: context.message('Stream key'),
                          suffixIcon: IconButton(
                            tooltip: context.message(
                              _obscure ? 'Show stream key' : 'Hide stream key',
                            ),
                            onPressed: busy
                                ? null
                                : () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? AppIcons.showSecret
                                  : AppIcons.hideSecret,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value == null ||
                                !RegExp(r'^[\x21-\x7e]{1,2048}$')
                                    .hasMatch(value.trim()) ||
                                value.trim().contains('#')
                            ? context.message(
                                'Enter a stream key without spaces.',
                              )
                            : null,
                      ),
                      const SizedBox(height: 24),
                      if (_store != null) ...[
                        TextFormField(
                          key: const ValueKey('live-name'),
                          controller: _name,
                          enabled: !busy,
                          decoration: InputDecoration(
                            labelText: context.message('Destination name'),
                            errorText: _nameError == null
                                ? null
                                : context.message(_nameError!),
                          ),
                          onChanged: (_) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.message(
                            'Saving stores the destination encrypted on this device. Nothing starts automatically.',
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: busy || _loadFailed
                                  ? null
                                  : _saveDestination,
                              child: Text(context.message('Save destination')),
                            ),
                            if (_hasSaved || _loadFailed)
                              TextButton(
                                onPressed: busy ? null : _forgetDestination,
                                child: Text(
                                  context.message('Forget destination'),
                                ),
                              ),
                            if (_loadFailed)
                              TextButton(
                                onPressed: busy ? null : _loadDestination,
                                child: Text(context.l10n.retry),
                              ),
                          ],
                        ),
                        if (_storeBusy) const LinearProgressIndicator(),
                        if (_destinationNotice != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(context.message(_destinationNotice!)),
                          ),
                        const SizedBox(height: 24),
                      ],
                      Semantics(liveRegion: true, child: Text(_label(context))),
                      if (capture.error != null && ownsSession)
                        Text(
                          context.message(
                            UserMessages.failure(
                              capture.error,
                              operation: UserOperation.captureControl,
                            ).text,
                          ),
                        ),
                      if (ownsSession && _status['sentBytes'] is num)
                        Text(
                          '${context.fileSize((_status['sentBytes'] as num).toInt())} · ${((_status['bitrate'] as num?)?.toInt() ?? 0) ~/ 1000} kbps',
                        ),
                      if (!h264)
                        Text(
                          context.message(
                            'Choose H264 in recording settings before livestreaming.',
                          ),
                        ),
                      if (capture.busy && !ownsSession)
                        Text(context.l10n.finishTheCurrentRecordingFirst),
                      if (capture.session?.state == RecordingState.paused &&
                          ownsSession)
                        Text(
                          context.message(
                            'Recording paused. Viewers see the last frame until you resume.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canStop
                      ? () async {
                          try {
                            await capture.stop();
                          } catch (error) {
                            if (context.mounted) {
                              showFailure(
                                context,
                                error,
                                operation: UserOperation.captureControl,
                              );
                            }
                          }
                        }
                      : busy || !h264 || _adapter == null
                      ? null
                      : _start,
                  icon: Icon(canStop ? AppIcons.stop : AppIcons.livestream),
                  label: Text(
                    context.message(
                      canStop
                          ? 'End livestream'
                          : _starting
                          ? 'Starting livestream'
                          : 'Start livestream',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    _server.dispose();
    _key.dispose();
    _name.dispose();
    super.dispose();
  }
}
