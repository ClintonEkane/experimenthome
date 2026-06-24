import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/current_reading.dart';
import '../../../core/models/experiment.dart';
import '../../../core/models/session_record.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/mqtt_service.dart';
import '../widgets/resistor_selector.dart';
import '../widgets/live_graph.dart';
import '../widgets/status_indicator.dart';
import '../widgets/current_display.dart';

const _mqttBroker = '147bea8727e745e8993c3928a1f4199f.s1.eu.hivemq.cloud';
const _mqttPort = 8883;
const _mqttUsername = 'experimenthome';
const _mqttPassword = 'Experimenthome1';

class ExperimentScreen extends StatefulWidget {
  final Experiment experiment;
  final List<Station> stations;

  const ExperimentScreen({
    super.key,
    required this.experiment,
    required this.stations,
  });

  @override
  State<ExperimentScreen> createState() => _ExperimentScreenState();
}

class _ExperimentScreenState extends State<ExperimentScreen>
    with WidgetsBindingObserver {
  late final MqttService _mqtt;
  late final AuthService _auth;
  late final FirestoreService _firestore;

  Station? _myStation;
  bool _sessionActive = false;
  bool _released = false;
  int _selectedResistor = 100;
  final List<CurrentReading> _readings = [];
  double _peakCurrentMa = 0;
  String? _sessionDocId;
  DeviceStatus _deviceStatus = DeviceStatus.offline;

  StreamSubscription<CurrentReading>? _currentSub;
  StreamSubscription<DeviceStatus>? _statusSub;

  static const _resistorOptions = [100, 220, 470, 1000];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = context.read<AuthService>();
    _firestore = context.read<FirestoreService>();
    _mqtt = MqttService();
    _tryClaimStation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _releaseStation();
    }
  }

  void _releaseStation() {
    if (_released) return;
    _released = true;

    if (_sessionActive) {
      _mqtt.stopExperiment();
      if (_sessionDocId != null) {
        _firestore.endSession(_sessionDocId!, _peakCurrentMa);
        _sessionDocId = null;
      }
      _sessionActive = false;
    }

    if (_myStation != null) {
      _firestore.unlockStation(widget.experiment.id, _myStation!.id);
      _myStation = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Station claiming
  // ---------------------------------------------------------------------------

  Future<void> _tryClaimStation() async {
    final claimable =
        widget.stations.where((s) => s.isAvailable).firstOrNull;
    if (claimable == null) return;

    if (claimable.isStale) {
      await _firestore.unlockStation(widget.experiment.id, claimable.id);
    }

    final user = _auth.currentUser!;
    await _firestore.lockStation(
      experimentId: widget.experiment.id,
      stationId: claimable.id,
      userId: user.uid,
      displayName: user.displayName ?? user.email ?? 'Unknown',
    );
    setState(() => _myStation = claimable);
    await _connectMqtt(claimable.id);
  }

  Future<void> _connectMqtt(String stationId) async {
    final user = _auth.currentUser!;
    await _mqtt.connect(
      broker: _mqttBroker,
      port: _mqttPort,
      username: _mqttUsername,
      password: _mqttPassword,
      clientId: 'flutter_${user.uid}',
      experimentId: widget.experiment.id,
      stationId: stationId,
    );

    _currentSub = _mqtt.currentStream.listen((reading) {
      if (!mounted) return;
      setState(() {
        _readings.add(reading);
        if (_readings.length > 120) _readings.removeAt(0);
        if (reading.currentMa > _peakCurrentMa) {
          _peakCurrentMa = reading.currentMa;
        }
      });
    });

    _statusSub = _mqtt.statusStream.listen((status) {
      if (mounted) setState(() => _deviceStatus = status);
    });
  }

  // ---------------------------------------------------------------------------
  // Session control
  // ---------------------------------------------------------------------------

  Future<void> _startSession() async {
    if (_myStation == null) return;
    final user = _auth.currentUser!;
    _readings.clear();
    _peakCurrentMa = 0;

    final record = SessionRecord(
      id: '',
      userId: user.uid,
      experimentId: widget.experiment.id,
      stationId: _myStation!.id,
      resistorOhms: _selectedResistor,
      peakCurrentMa: 0,
      startedAt: DateTime.now(),
    );
    _sessionDocId = await _firestore.saveSession(record);

    _mqtt.startExperiment();
    _mqtt.selectResistor(_selectedResistor);
    setState(() => _sessionActive = true);
  }

  Future<void> _stopSession() async {
    _mqtt.stopExperiment();

    if (_sessionDocId != null) {
      await _firestore.endSession(_sessionDocId!, _peakCurrentMa);
      _sessionDocId = null;
    }

    if (_myStation != null) {
      await _firestore.unlockStation(widget.experiment.id, _myStation!.id);
    }
    _released = true;

    if (mounted) {
      setState(() {
        _sessionActive = false;
        _readings.clear();
      });
    }
  }

  void _onResistorChanged(int ohms) {
    setState(() => _selectedResistor = ohms);
    if (_sessionActive) {
      _mqtt.selectResistor(ohms);
    }
  }

  // ---------------------------------------------------------------------------
  // Release station on exit
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseStation();
    _currentSub?.cancel();
    _statusSub?.cancel();
    _mqtt.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final inUseStation = widget.stations
        .where((s) => !s.isAvailable)
        .firstOrNull;
    final allOccupied = widget.stations.isNotEmpty && _myStation == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.experiment.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StatusIndicator(status: _deviceStatus),
          ),
        ],
      ),
      body: allOccupied
          ? _buildInUseView(inUseStation)
          : _myStation == null
          ? const Center(child: CircularProgressIndicator())
          : _buildControlView(),
    );
  }

  Widget _buildInUseView(Station? station) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, size: 64, color: AppColors.stale),
            const SizedBox(height: 16),
            const Text(
              'Experiment currently in use',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              station != null
                  ? 'In use by ${station.lockedByName ?? "another user"}'
                  : 'Please check back later',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlView() {
    final currentMa = _readings.isNotEmpty ? _readings.last.currentMa : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CurrentDisplay(currentMa: currentMa, isActive: _sessionActive),
          const SizedBox(height: 16),
          LiveGraph(readings: _readings, isActive: _sessionActive),
          const SizedBox(height: 16),
          ResistorSelector(
            options: _resistorOptions,
            selected: _selectedResistor,
            onChanged: _onResistorChanged,
          ),
          const SizedBox(height: 24),
          _sessionActive
              ? ElevatedButton.icon(
                  onPressed: _stopSession,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Experiment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.offline,
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _startSession,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Experiment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.online,
                  ),
                ),
        ],
      ),
    );
  }
}
