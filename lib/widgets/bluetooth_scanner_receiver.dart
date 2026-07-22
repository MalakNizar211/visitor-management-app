import 'package:flutter/material.dart';

class BluetoothScannerReceiver extends StatefulWidget {
  final Future<void> Function(String scannedValue) onScan;

  const BluetoothScannerReceiver({
    super.key,
    required this.onScan,
  });

  @override
  State<BluetoothScannerReceiver> createState() =>
      _BluetoothScannerReceiverState();
}

class _BluetoothScannerReceiverState
    extends State<BluetoothScannerReceiver>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _busy = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestFocus();
    }
  }

  void _requestFocus() {
    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Future<void> _handleScan(String value) async {
    if (_busy) return;

    final scan = value.trim();

    _controller.clear();

    if (scan.isEmpty) {
      _requestFocus();
      return;
    }

    _busy = true;

    try {
      await widget.onScan(scan);
    } finally {
      _busy = false;
      _controller.clear();
      _requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 0,
      height: 0,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        // showCursor: false,
        // enableInteractiveSelection: false,
        // enableSuggestions: false,
        // autocorrect: false,
        keyboardType: TextInputType.none,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
        ),
        // onTap: _requestFocus,
        onSubmitted: _handleScan,
        // onEditingComplete: _handleScan,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}