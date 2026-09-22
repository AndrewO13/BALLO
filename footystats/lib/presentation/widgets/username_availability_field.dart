import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/username_rules.dart';
import '../../data/repositories/username_repository.dart';

/// Username input with debounced availability checks and suggestions.
class UsernameAvailabilityField extends StatefulWidget {
  const UsernameAvailabilityField({
    super.key,
    required this.controller,
    this.excludePlayerId,
    this.onAvailabilityChanged,
    this.textInputAction = TextInputAction.done,
    this.onFieldSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? excludePlayerId;
  final ValueChanged<UsernameCheckResult>? onAvailabilityChanged;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool autofocus;

  @override
  State<UsernameAvailabilityField> createState() =>
      _UsernameAvailabilityFieldState();
}

class _UsernameAvailabilityFieldState extends State<UsernameAvailabilityField> {
  final _repository = UsernameRepository();
  Timer? _debounce;
  int _requestId = 0;

  UsernameCheckResult _result = const UsernameCheckResult(
    status: UsernameAvailability.idle,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleCheck(immediate: true);
    });
  }

  @override
  void didUpdateWidget(UsernameAvailabilityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.excludePlayerId != widget.excludePlayerId) {
      _scheduleCheck(immediate: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    _scheduleCheck();
  }

  void _scheduleCheck({bool immediate = false}) {
    _debounce?.cancel();
    if (immediate) {
      unawaited(_runCheck());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _runCheck);
  }

  Future<void> _runCheck() async {
    final id = ++_requestId;
    final text = widget.controller.text;

    final formatError = UsernameRules.usernameError(text);
    if (formatError != null && UsernameRules.normalize(text).isNotEmpty) {
      final next = UsernameCheckResult(
        status: text.trim().length < 3
            ? UsernameAvailability.idle
            : UsernameAvailability.invalid,
      );
      _publishResult(next);
      return;
    }

    if (UsernameRules.normalize(text).isEmpty) {
      _publishResult(
        const UsernameCheckResult(status: UsernameAvailability.idle),
      );
      return;
    }

    setState(() {
      _result = const UsernameCheckResult(status: UsernameAvailability.checking);
    });
    widget.onAvailabilityChanged?.call(_result);

    try {
      final next = await _repository.check(
        text,
        excludePlayerId: widget.excludePlayerId,
      );
      if (!mounted || id != _requestId) return;
      _publishResult(next);
    } catch (_) {
      if (!mounted || id != _requestId) return;
      _publishResult(
        const UsernameCheckResult(status: UsernameAvailability.invalid),
      );
    }
  }

  void _publishResult(UsernameCheckResult next) {
    setState(() => _result = next);
    widget.onAvailabilityChanged?.call(next);
  }

  void _applySuggestion(String username) {
    widget.controller.text = username;
    widget.controller.selection = TextSelection.collapsed(
      offset: username.length,
    );
    _scheduleCheck(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          textInputAction: widget.textInputAction,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
            LengthLimitingTextInputFormatter(20),
          ],
          decoration: InputDecoration(
            labelText: 'Username',
            hintText: 'eg. TurfGeneral',
            prefixText: '@ ',
            suffixIcon: _buildSuffixIcon(colorScheme),
          ),
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: (value) {
            final formatError = UsernameRules.usernameError(value);
            if (formatError != null) return formatError;
            if (_result.status == UsernameAvailability.taken) {
              return 'That username is already taken';
            }
            if (_result.status == UsernameAvailability.checking) {
              return 'Checking username availability';
            }
            if (_result.status != UsernameAvailability.available) {
              return 'Choose an available username';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        _StatusBanner(result: _result, colorScheme: colorScheme, textTheme: textTheme),
        if (_result.status == UsernameAvailability.taken &&
            _result.suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Try one of these',
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _result.suggestions.map((suggestion) {
              return ActionChip(
                label: Text('@$suggestion'),
                onPressed: () => _applySuggestion(suggestion),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget? _buildSuffixIcon(ColorScheme colorScheme) {
    return switch (_result.status) {
      UsernameAvailability.checking => Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
        ),
      UsernameAvailability.available => Icon(
          Icons.check_circle,
          color: colorScheme.primary,
        ),
      UsernameAvailability.taken => Icon(
          Icons.cancel,
          color: colorScheme.error,
        ),
      UsernameAvailability.invalid => Icon(
          Icons.error_outline,
          color: colorScheme.error,
        ),
      UsernameAvailability.idle => null,
    };
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.result,
    required this.colorScheme,
    required this.textTheme,
  });

  final UsernameCheckResult result;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final (message, bg, fg, icon) = switch (result.status) {
      UsernameAvailability.idle => (
          '3–20 characters. Letters, numbers, and underscores.',
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
          Icons.info_outline,
        ),
      UsernameAvailability.checking => (
          'Checking availability…',
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
          null,
        ),
      UsernameAvailability.available => (
          'Username is available',
          colorScheme.primaryContainer.withValues(alpha: 0.45),
          colorScheme.primary,
          Icons.check_circle_outline,
        ),
      UsernameAvailability.taken => (
          'Username is already taken',
          colorScheme.errorContainer.withValues(alpha: 0.55),
          colorScheme.error,
          Icons.block,
        ),
      UsernameAvailability.invalid => (
          'Use 3–20 characters: letters, numbers, underscores',
          colorScheme.errorContainer.withValues(alpha: 0.4),
          colorScheme.error,
          Icons.error_outline,
        ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(result.status),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: textTheme.bodySmall?.copyWith(
                  color: fg,
                  fontWeight: result.status == UsernameAvailability.available
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
