import 'package:airbridge/core/types/transfer_phase.dart';
import 'package:airbridge/ui/airbridge_controller.dart';
import 'package:airbridge/ui/widgets/device_tile.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AirBridgeController _controller;
  final TextEditingController _pairCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AirBridgeController();
    _controller.initialize();
  }

  @override
  void dispose() {
    _pairCodeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final p = _controller.transferProgress;
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFF070B14),
                  Color(0xFF0B1628),
                  Color(0xFF071321),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 1020;
                    final left = _buildLeftPanel(p);
                    final right = _buildRightPanel();

                    if (wide) {
                      return Row(
                        children: <Widget>[
                          Expanded(flex: 3, child: left),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: right),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          left,
                          const SizedBox(height: 16),
                          right,
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftPanel(progress) {
    final phaseLabel = _controller.transferProgress.phase.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.air_rounded, color: Color(0xFF66F2FF)),
                  const SizedBox(width: 10),
                  const Text(
                    'AirBridge',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  _stateChip(_controller.systemState.label),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Gesture-Driven Spatial File Transfer',
                style: TextStyle(
                  color: Colors.blueGrey.shade100,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Transfer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  '$phaseLabel ${_controller.transferProgress.message ?? ''}',
                  key: ValueKey<String>(phaseLabel + (_controller.transferProgress.message ?? '')),
                ),
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 220),
                tween: Tween<double>(
                  begin: 0,
                  end: _controller.transferProgress.progress.clamp(0.0, 1.0),
                ),
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    minHeight: 10,
                    value: value,
                    backgroundColor: const Color(0x223D6480),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF2EE9E6)),
                    borderRadius: BorderRadius.circular(99),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                '${_controller.transferProgress.bytesTransferred} / ${_controller.transferProgress.totalBytes} bytes',
                style: TextStyle(color: Colors.blueGrey.shade100),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Gesture Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Text(
                  _controller.gestureStatus,
                  key: ValueKey<String>(_controller.gestureStatus),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92F2FF),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _actionButton('Pick File', _controller.pickFile),
                  _actionButton('Send', _controller.sendSelectedFile),
                  _actionButton('Cancel', _controller.cancelSelection),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _controller.selectedFileName == null
                    ? 'No file selected'
                    : 'File Selected: ${_controller.selectedFileName}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Pairing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _actionButton('Create Code', _controller.createSession),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _pairCodeController,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '6-digit code',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  _actionButton(
                    'Join',
                    () => _controller.joinSession(_pairCodeController.text),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Your session code: ${_controller.pairingCode ?? '------'}',
                style: const TextStyle(
                  fontSize: 20,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF72F7E5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_controller.hasPendingTrust)
          _panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'First-Time Pairing Confirmation',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Trust ${_controller.pendingTrustPeer!.name} on this device?',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    _actionButton('Trust', _controller.trustPendingPeer),
                    _actionButton('Dismiss', _controller.dismissPendingTrust),
                  ],
                ),
              ],
            ),
          ),
        if (_controller.hasPendingTrust) const SizedBox(height: 14),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Nearby Devices',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 220,
                child: _controller.nearbyDevices.isEmpty
                    ? const Center(
                        child: Text('No peers yet. Keep scanning or pair by code.'),
                      )
                    : ListView.builder(
                        itemCount: _controller.nearbyDevices.length,
                        itemBuilder: (context, index) {
                          final peer = _controller.nearbyDevices[index];
                          return DeviceTile(
                            peer: peer,
                            isSelected: _controller.selectedPeer?.id == peer.id,
                            onTap: () => _controller.selectPeer(peer),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  itemCount: _controller.activityLog.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      _controller.activityLog[index],
                      style: TextStyle(color: Colors.blueGrey.shade100),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x220E203A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0x6638DCFF),
          width: 1.1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x2200D4FF),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _stateChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x2230E0FF),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x8830E0FF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF153A54),
        foregroundColor: const Color(0xFFBFFAFF),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Text(label),
    );
  }
}

