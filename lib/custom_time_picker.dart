import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// A drop-in, dependency-free replacement for Flutter's [showTimePicker].
///
/// Behaves like the built-in dialog (same call shape, returns a
/// [TimeOfDay]), but adds *preventive* validation: any time that is not
/// strictly after [minTime] is rendered disabled and cannot be tapped,
/// dragged onto, or otherwise selected. There is nothing to validate after
/// the fact because invalid values are unreachable in the UI.
///
/// Usage (mirrors `showTimePicker`):
/// ```dart
/// final time = await showCustomTimePicker(
///   context: context,
///   initialTime: TimeOfDay.now(),
///   helpText: 'Select Start Time',
///   minTime: someEarlierTime, // optional
/// );
/// ```
Future<TimeOfDay?> showCustomTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
  TimeOfDay? minTime,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (context) {
      return CustomTimePickerDialog(
        initialTime: initialTime,
        helpText: helpText,
        minTime: minTime,
      );
    },
  );
}

/// Opens a single dialog that walks the user through picking a *start* time
/// and then an *end* time, without closing and reopening a new [Dialog].
/// The transition between the two steps happens inside the same dialog
/// shell via an animated cross-fade/slide.
///
/// Returns `null` if the user cancels at any point, otherwise a record with
/// the confirmed `start` and `end` times (guaranteed `end` is strictly after
/// `start`).
Future<({TimeOfDay start, TimeOfDay end})?> showCustomTimeRangePicker({
  required BuildContext context,
  TimeOfDay? initialStart,
  TimeOfDay? initialEnd,
  TimeOfDay? minStartTime,
}) {
  return showDialog<({TimeOfDay start, TimeOfDay end})>(
    context: context,
    builder: (context) {
      return _TimeRangePickerDialog(
        initialStart: initialStart,
        initialEnd: initialEnd,
        minStartTime: minStartTime,
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Time-validity helpers
// ---------------------------------------------------------------------------

int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

/// A time is valid when there is no [minTime], or it is strictly after it.
bool _isTimeValid(TimeOfDay time, TimeOfDay? minTime) {
  if (minTime == null) return true;
  return _minutesOf(time) > _minutesOf(minTime);
}

/// An hour is selectable if at least one minute within it is valid.
bool _isHourValid(int hour24, TimeOfDay? minTime) {
  if (minTime == null) return true;
  return _isTimeValid(TimeOfDay(hour: hour24, minute: 59), minTime);
}

TimeOfDay? _firstValidTimeInHour(int hour24, TimeOfDay? minTime) {
  for (int minute = 0; minute < 60; minute++) {
    final candidate = TimeOfDay(hour: hour24, minute: minute);
    if (_isTimeValid(candidate, minTime)) return candidate;
  }
  return null;
}

/// Clamps [from] forward to the nearest valid time if it isn't already one.
TimeOfDay _nextValidTime(TimeOfDay from, TimeOfDay? minTime) {
  if (minTime == null || _isTimeValid(from, minTime)) return from;

  int total = _minutesOf(minTime) + 1;
  if (total > 23 * 60 + 59) total = 23 * 60 + 59;

  return TimeOfDay(hour: total ~/ 60, minute: total % 60);
}

// ---------------------------------------------------------------------------
// Dialog (single time)
// ---------------------------------------------------------------------------

enum _PickerMode { hour, minute }

class CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final String? helpText;
  final TimeOfDay? minTime;

  const CustomTimePickerDialog({
    super.key,
    required this.initialTime,
    this.helpText,
    this.minTime,
  });

  @override
  State<CustomTimePickerDialog> createState() {
    return _CustomTimePickerDialogState();
  }
}

class _CustomTimePickerDialogState extends State<CustomTimePickerDialog> {
  late TimeOfDay _time;
  _PickerMode _mode = _PickerMode.hour;

  @override
  void initState() {
    super.initState();

    _time = _nextValidTime(widget.initialTime, widget.minTime);
  }

  bool get _isPM => _time.hour >= 12;

  int get _selectedHourIndex => _time.hourOfPeriod;

  int _hour24For(int hourIndex, bool pm) {
    // hourIndex 0 represents the "12" label.
    if (hourIndex == 0) return pm ? 12 : 0;
    return pm ? hourIndex + 12 : hourIndex;
  }

  bool _isPeriodEnabled(bool pm) {
    final startHour = pm ? 12 : 0;

    for (int hour = startHour; hour < startHour + 12; hour++) {
      if (_isHourValid(hour, widget.minTime)) return true;
    }

    return false;
  }

  void _selectHour(int hourIndex) {
    final hour24 = _hour24For(hourIndex, _isPM);

    setState(() {
      TimeOfDay next = TimeOfDay(hour: hour24, minute: _time.minute);

      if (!_isTimeValid(next, widget.minTime)) {
        next = _firstValidTimeInHour(hour24, widget.minTime) ?? next;
      }

      _time = next;
      _mode = _PickerMode.minute;
    });
  }

  void _selectMinute(int minute) {
    setState(() {
      _time = TimeOfDay(hour: _time.hour, minute: minute);
    });
  }

  void _selectPeriod(bool pm) {
    if (pm == _isPM) return;
    if (!_isPeriodEnabled(pm)) return;

    setState(() {
      int hour24 = _time.hour % 12 + (pm ? 12 : 0);

      if (!_isHourValid(hour24, widget.minTime)) {
        final startHour = pm ? 12 : 0;

        for (int hour = startHour; hour < startHour + 12; hour++) {
          if (_isHourValid(hour, widget.minTime)) {
            hour24 = hour;
            break;
          }
        }
      }

      TimeOfDay next = TimeOfDay(hour: hour24, minute: _time.minute);

      if (!_isTimeValid(next, widget.minTime)) {
        next = _firstValidTimeInHour(hour24, widget.minTime) ?? next;
      }

      _time = next;
    });
  }

  String get _formattedHour {
    final hour = _time.hourOfPeriod;
    return (hour == 0 ? 12 : hour).toString();
  }

  String get _formattedMinute {
    return _time.minute.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    const dialSize = 260.0;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium + 8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.helpText != null) ...[
              Text(
                widget.helpText!.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _timeSegment(
                  text: _formattedHour,
                  selected: _mode == _PickerMode.hour,
                  onTap: () {
                    setState(() => _mode = _PickerMode.hour);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                _timeSegment(
                  text: _formattedMinute,
                  selected: _mode == _PickerMode.minute,
                  onTap: () {
                    setState(() => _mode = _PickerMode.minute);
                  },
                ),
                const SizedBox(width: 16),
                _periodToggle(),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: _mode == _PickerMode.hour
                  ? _DialPicker(
                key: const ValueKey('hour-dial'),
                size: dialSize,
                itemCount: 12,
                selectedIndex: _selectedHourIndex,
                isEnabled: (index) {
                  return _isHourValid(
                    _hour24For(index, _isPM),
                    widget.minTime,
                  );
                },
                onSelect: _selectHour,
                labelFor: (index) {
                  return (index == 0 ? 12 : index).toString();
                },
              )
                  : _DialPicker(
                key: const ValueKey('minute-dial'),
                size: dialSize,
                itemCount: 12,
                selectedIndex: (_time.minute / 5).round() % 12,
                isEnabled: (index) {
                  return _isTimeValid(
                    TimeOfDay(hour: _time.hour, minute: index * 5),
                    widget.minTime,
                  );
                },
                onSelect: (index) {
                  _selectMinute(index * 5);
                },
                labelFor: (index) {
                  return (index * 5).toString().padLeft(2, '0');
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, _time);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeSegment({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.softGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: selected ? AppColors.ratpGreenDark : AppColors.navy,
          ),
        ),
      ),
    );
  }

  Widget _periodToggle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _periodButton(
          label: 'AM',
          selected: !_isPM,
          enabled: _isPeriodEnabled(false),
          onTap: () => _selectPeriod(false),
        ),
        const SizedBox(height: 6),
        _periodButton(
          label: 'PM',
          selected: _isPM,
          enabled: _isPeriodEnabled(true),
          onTap: () => _selectPeriod(true),
        ),
      ],
    );
  }

  Widget _periodButton({
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ratpGreen : Colors.transparent,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: !enabled
                ? AppColors.muted.withOpacity(.35)
                : (selected ? Colors.white : AppColors.ink),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog (start + end range, single shell, two internal steps)
// ---------------------------------------------------------------------------

enum _RangeStep { start, end }

enum _InputMode { dial, keyboard }

class _TimeRangePickerDialog extends StatefulWidget {
  final TimeOfDay? initialStart;
  final TimeOfDay? initialEnd;
  final TimeOfDay? minStartTime;

  const _TimeRangePickerDialog({
    this.initialStart,
    this.initialEnd,
    this.minStartTime,
  });

  @override
  State<_TimeRangePickerDialog> createState() {
    return _TimeRangePickerDialogState();
  }
}

class _TimeRangePickerDialogState extends State<_TimeRangePickerDialog> {
  _RangeStep _step = _RangeStep.start;
  _PickerMode _mode = _PickerMode.hour;
  _InputMode _inputMode = _InputMode.dial;

  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  final TextEditingController _hourController = TextEditingController();
  final TextEditingController _minuteController = TextEditingController();
  bool _keyboardPM = false;
  String? _keyboardError;

  @override
  void initState() {
    super.initState();

    _startTime = _nextValidTime(
      widget.initialStart ?? TimeOfDay.now(),
      widget.minStartTime,
    );

    final defaultEnd = TimeOfDay(
      hour: (_startTime.hour + (_startTime.minute >= 30 ? 1 : 0)) % 24,
      minute: _startTime.minute >= 30 ? 0 : 30,
    );

    _endTime = _nextValidTime(
      widget.initialEnd ?? defaultEnd,
      _startTime,
    );

    _syncKeyboardFields();
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();

    super.dispose();
  }

  TimeOfDay get _currentTime =>
      _step == _RangeStep.start ? _startTime : _endTime;

  set _currentTime(TimeOfDay value) {
    if (_step == _RangeStep.start) {
      _startTime = value;
    } else {
      _endTime = value;
    }
  }

  TimeOfDay? get _currentMinTime =>
      _step == _RangeStep.start ? widget.minStartTime : _startTime;

  String get _stepTitle =>
      _step == _RangeStep.start ? 'Select Start Time' : 'Select End Time';

  void _syncKeyboardFields() {
    final hour = _currentTime.hourOfPeriod;

    _hourController.text = (hour == 0 ? 12 : hour).toString();
    _minuteController.text = _currentTime.minute.toString().padLeft(2, '0');
    _keyboardPM = _currentTime.hour >= 12;
    _keyboardError = null;
  }

  // -- hour/minute dial mode -----------------------------------------------

  bool get _isPM => _currentTime.hour >= 12;

  int get _selectedHourIndex => _currentTime.hourOfPeriod;

  int _hour24For(int hourIndex, bool pm) {
    if (hourIndex == 0) return pm ? 12 : 0;
    return pm ? hourIndex + 12 : hourIndex;
  }

  bool _isPeriodEnabled(bool pm) {
    final startHour = pm ? 12 : 0;

    for (int hour = startHour; hour < startHour + 12; hour++) {
      if (_isHourValid(hour, _currentMinTime)) return true;
    }

    return false;
  }

  void _selectHour(int hourIndex) {
    final hour24 = _hour24For(hourIndex, _isPM);

    setState(() {
      TimeOfDay next = TimeOfDay(hour: hour24, minute: _currentTime.minute);

      if (!_isTimeValid(next, _currentMinTime)) {
        next = _firstValidTimeInHour(hour24, _currentMinTime) ?? next;
      }

      _currentTime = next;
      _mode = _PickerMode.minute;
    });
  }

  void _selectMinute(int minute) {
    setState(() {
      _currentTime = TimeOfDay(hour: _currentTime.hour, minute: minute);
    });
  }

  void _selectPeriod(bool pm) {
    if (pm == _isPM) return;
    if (!_isPeriodEnabled(pm)) return;

    setState(() {
      int hour24 = _currentTime.hour % 12 + (pm ? 12 : 0);

      if (!_isHourValid(hour24, _currentMinTime)) {
        final startHour = pm ? 12 : 0;

        for (int hour = startHour; hour < startHour + 12; hour++) {
          if (_isHourValid(hour, _currentMinTime)) {
            hour24 = hour;
            break;
          }
        }
      }

      TimeOfDay next = TimeOfDay(hour: hour24, minute: _currentTime.minute);

      if (!_isTimeValid(next, _currentMinTime)) {
        next = _firstValidTimeInHour(hour24, _currentMinTime) ?? next;
      }

      _currentTime = next;
    });
  }

  // -- keyboard entry mode --------------------------------------------------

  void _toggleInputMode() {
    setState(() {
      if (_inputMode == _InputMode.dial) {
        _syncKeyboardFields();
        _inputMode = _InputMode.keyboard;
      } else {
        _inputMode = _InputMode.dial;
      }
    });
  }

  void _handleKeyboardChanged() {
    final hourText = _hourController.text.trim();
    final minuteText = _minuteController.text.trim();

    if (hourText.isEmpty || minuteText.isEmpty) {
      setState(() => _keyboardError = 'Enter a complete time');
      return;
    }

    final hourValue = int.tryParse(hourText);
    final minuteValue = int.tryParse(minuteText);

    if (hourValue == null || hourValue < 1 || hourValue > 12) {
      setState(() => _keyboardError = 'Hour must be 1–12');
      return;
    }

    if (minuteValue == null || minuteValue < 0 || minuteValue > 59) {
      setState(() => _keyboardError = 'Minute must be 00–59');
      return;
    }

    final hour24 = _keyboardPM
        ? (hourValue % 12) + 12
        : hourValue % 12;

    final candidate = TimeOfDay(hour: hour24, minute: minuteValue);

    if (!_isTimeValid(candidate, _currentMinTime)) {
      setState(() {
        _keyboardError = _step == _RangeStep.end
            ? 'End time must be after the start time'
            : 'Time must be after the minimum allowed time';
      });
      return;
    }

    setState(() {
      _currentTime = candidate;
      _keyboardError = null;
    });
  }

  void _setKeyboardPeriod(bool pm) {
    setState(() {
      _keyboardPM = pm;
    });

    _handleKeyboardChanged();
  }

  bool get _isCurrentStepValid {
    if (_inputMode == _InputMode.keyboard) {
      return _keyboardError == null;
    }

    return true;
  }

  // -- navigation -------------------------------------------------------

  void _goToEndStep() {
    setState(() {
      _endTime = _nextValidTime(_endTime, _startTime);
      _step = _RangeStep.end;
      _mode = _PickerMode.hour;
      _inputMode = _InputMode.dial;
      _syncKeyboardFields();
    });
  }

  void _goBackToStartStep() {
    setState(() {
      _step = _RangeStep.start;
      _mode = _PickerMode.hour;
      _inputMode = _InputMode.dial;
      _syncKeyboardFields();
    });
  }

  void _confirm() {
    Navigator.pop(context, (start: _startTime, end: _endTime));
  }

  String get _formattedHour {
    final hour = _currentTime.hourOfPeriod;
    return (hour == 0 ? 12 : hour).toString();
  }

  String get _formattedMinute {
    return _currentTime.minute.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium + 8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.medium + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: Offset(
                      child.key == const ValueKey('step-start') ? -.12 : .12,
                      0,
                    ),
                    end: Offset.zero,
                  ).animate(animation);

                  return ClipRect(
                    child: SlideTransition(
                      position: slide,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    ),
                  );
                },
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: Column(
                  key: ValueKey(
                    _step == _RangeStep.start
                        ? 'step-start'
                        : 'step-end',
                  ),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _timeReadout(),
                    const SizedBox(height: 18),
                    _inputMode == _InputMode.dial
                        ? _dialArea()
                        : _keyboardArea(),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      decoration: const BoxDecoration(
        color: AppColors.ratpGreenDark,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_step == _RangeStep.end)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                onPressed: _goBackToStartStep,
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
                tooltip: 'Back to start time',
                visualDensity: VisualDensity.compact,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _step == _RangeStep.start
                        ? 'STEP 1 OF 2'
                        : 'STEP 2 OF 2',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _stepTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleInputMode,
            icon: Icon(
              _inputMode == _InputMode.dial
                  ? Icons.keyboard_rounded
                  : Icons.schedule_rounded,
            ),
            color: Colors.white,
            tooltip: _inputMode == _InputMode.dial
                ? 'Type the time instead'
                : 'Use the dial instead',
          ),
        ],
      ),
    );
  }

  Widget _timeReadout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _timeSegment(
          text: _formattedHour,
          selected: _mode == _PickerMode.hour,
          onTap: () {
            setState(() => _mode = _PickerMode.hour);
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
        ),
        _timeSegment(
          text: _formattedMinute,
          selected: _mode == _PickerMode.minute,
          onTap: () {
            setState(() => _mode = _PickerMode.minute);
          },
        ),
        const SizedBox(width: 16),
        _periodToggle(
          isPM: _isPM,
          onSelect: _selectPeriod,
          isEnabled: _isPeriodEnabled,
        ),
      ],
    );
  }

  Widget _dialArea() {
    const dialSize = 260.0;

    return Center(
      child: _mode == _PickerMode.hour
          ? _DialPicker(
        key: const ValueKey('hour-dial'),
        size: dialSize,
        itemCount: 12,
        selectedIndex: _selectedHourIndex,
        isEnabled: (index) {
          return _isHourValid(_hour24For(index, _isPM), _currentMinTime);
        },
        onSelect: _selectHour,
        labelFor: (index) {
          return (index == 0 ? 12 : index).toString();
        },
      )
          : _DialPicker(
        key: const ValueKey('minute-dial'),
        size: dialSize,
        itemCount: 12,
        selectedIndex: (_currentTime.minute / 5).round() % 12,
        isEnabled: (index) {
          return _isTimeValid(
            TimeOfDay(hour: _currentTime.hour, minute: index * 5),
            _currentMinTime,
          );
        },
        onSelect: (index) {
          _selectMinute(index * 5);
        },
        labelFor: (index) {
          return (index * 5).toString().padLeft(2, '0');
        },
      ),
    );
  }

  Widget _keyboardArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _keyboardBox(
              controller: _hourController,
              hint: 'HH',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),
            ),
            _keyboardBox(
              controller: _minuteController,
              hint: 'MM',
            ),
            const SizedBox(width: 16),
            _periodToggle(
              isPM: _keyboardPM,
              onSelect: _setKeyboardPeriod,
              isEnabled: (_) => true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 20,
          child: _keyboardError != null
              ? Text(
            _keyboardError!,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          )
              : null,
        ),
      ],
    );
  }

  Widget _keyboardBox({
    required TextEditingController controller,
    required String hint,
  }) {
    return SizedBox(
      width: 74,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 2,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: AppColors.navy,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: hint,
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: const BorderSide(
              color: AppColors.ratpGreen,
              width: 2,
            ),
          ),
        ),
        onChanged: (_) => _handleKeyboardChanged(),
      ),
    );
  }

  Widget _timeSegment({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.softGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: selected ? AppColors.ratpGreenDark : AppColors.navy,
          ),
        ),
      ),
    );
  }

  Widget _periodToggle({
    required bool isPM,
    required void Function(bool pm) onSelect,
    required bool Function(bool pm) isEnabled,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _periodButton(
          label: 'AM',
          selected: !isPM,
          enabled: isEnabled(false),
          onTap: () => onSelect(false),
        ),
        const SizedBox(height: 6),
        _periodButton(
          label: 'PM',
          selected: isPM,
          enabled: isEnabled(true),
          onTap: () => onSelect(true),
        ),
      ],
    );
  }

  Widget _periodButton({
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ratpGreen : Colors.transparent,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: !enabled
                ? AppColors.muted.withOpacity(.35)
                : (selected ? Colors.white : AppColors.ink),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    final isLastStep = _step == _RangeStep.end;
    final canProceed = _isCurrentStepValid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('CANCEL'),
          ),
          if (!isLastStep)
            TextButton(
              onPressed: canProceed ? _goToEndStep : null,
              child: const Text('NEXT'),
            )
          else
            TextButton(
              onPressed: canProceed ? _confirm : null,
              child: const Text('DONE'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dial (shared by hour + minute modes)
// ---------------------------------------------------------------------------

class _DialPicker extends StatelessWidget {
  final double size;
  final int itemCount;
  final int selectedIndex;
  final bool Function(int index) isEnabled;
  final void Function(int index) onSelect;
  final String? Function(int index) labelFor;

  const _DialPicker({
    super.key,
    required this.size,
    required this.itemCount,
    required this.selectedIndex,
    required this.isEnabled,
    required this.onSelect,
    required this.labelFor,
  });

  double _angleFor(int index) {
    return (index / itemCount) * 2 * math.pi - math.pi / 2;
  }

  int _indexFromPosition(Offset localPosition) {
    final center = Offset(size / 2, size / 2);

    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    double angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    final step = 2 * math.pi / itemCount;

    return (angle / step).round() % itemCount;
  }

  void _handleTouch(Offset localPosition) {
    final index = _indexFromPosition(localPosition);

    if (isEnabled(index)) {
      onSelect(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = size / 2 - 26;
    final center = Offset(size / 2, size / 2);

    return GestureDetector(
      onPanDown: (details) => _handleTouch(details.localPosition),
      onPanUpdate: (details) => _handleTouch(details.localPosition),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _SelectionPainter(
                center: center,
                radius: radius,
                angle: _angleFor(selectedIndex),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.ratpGreen,
                shape: BoxShape.circle,
              ),
            ),
            for (int i = 0; i < itemCount; i++) _buildTick(i, center, radius),
          ],
        ),
      ),
    );
  }

  Widget _buildTick(int index, Offset center, double radius) {
    final angle = _angleFor(index);

    final position = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    final enabled = isEnabled(index);
    final selected = index == selectedIndex;
    final label = labelFor(index);

    if (label == null) {
      // Unlabeled tick - small dot.
      return Positioned(
        left: position.dx - 3,
        top: position.dy - 3,
        child: IgnorePointer(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled
                  ? (selected
                  ? AppColors.ratpGreen
                  : AppColors.muted.withOpacity(.5))
                  : AppColors.muted.withOpacity(.2),
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: position.dx - 18,
      top: position.dy - 18,
      child: IgnorePointer(
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.ratpGreen : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: enabled
                  ? (selected ? Colors.white : AppColors.ink)
                  : AppColors.muted.withOpacity(.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double angle;

  _SelectionPainter({
    required this.center,
    required this.radius,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final end = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    final linePaint = Paint()
      ..color = AppColors.ratpGreen.withOpacity(.9)
      ..strokeWidth = 2;

    canvas.drawLine(center, end, linePaint);

    final knobPaint = Paint()..color = AppColors.ratpGreen.withOpacity(.16);

    canvas.drawCircle(end, 20, knobPaint);
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.radius != radius;
  }
}