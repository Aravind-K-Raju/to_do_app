import 'package:flutter/material.dart';
import '../../data/repositories/security_repository_impl.dart';
import '../../domain/usecases/security/check_pin_exists.dart';
import '../../domain/usecases/security/set_pin.dart';
import '../../domain/usecases/security/validate_pin.dart';
import '../navigation_scaffold.dart';

enum PinMode { setup, verify }

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _repository = SecurityRepositoryImpl();

  PinMode _mode = PinMode.verify;
  String _enteredPin = '';
  String _confirmPin = ''; // Only for setup
  String _message = 'Initializing...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final hasPin = await CheckPinExists(_repository).call();
    setState(() {
      _mode = hasPin ? PinMode.verify : PinMode.setup;
      _message = hasPin ? 'Enter your PIN' : 'Create a new PIN';
      _isLoading = false;
    });
  }

  void _onDigitPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _handlePinSubmit();
      }
    }
  }

  void _onDeletePress() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _handlePinSubmit() async {
    if (_mode == PinMode.verify) {
      final isValid = await ValidatePin(_repository).call(_enteredPin);
      if (isValid) {
        _navigateToHome();
      } else {
        setState(() {
          _message = 'Incorrect PIN. Try again.';
          _enteredPin = '';
        });
      }
    } else {
      // Setup Mode
      if (_confirmPin.isEmpty) {
        // First entry done, ask for confirmation
        setState(() {
          _confirmPin = _enteredPin;
          _enteredPin = '';
          _message = 'Confirm your PIN';
        });
      } else {
        // Confirmation entry done
        if (_enteredPin == _confirmPin) {
          await SetPin(_repository).call(_enteredPin);
          _navigateToHome();
        } else {
          setState(() {
            _message = 'PINs do not match. Start over.';
            _enteredPin = '';
            _confirmPin = '';
          });
        }
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NavigationScaffold()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 24),
            Text(
              _message,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildPinDots(colorScheme),
            const Spacer(flex: 2),
            _buildKeypad(colorScheme),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDots(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _enteredPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? colorScheme.primary : colorScheme.surface,
            border: Border.all(
              color: isFilled ? colorScheme.primary : Colors.grey,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(ColorScheme colorScheme) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        _buildKeypadRow(['4', '5', '6']),
        _buildKeypadRow(['7', '8', '9']),
        _buildKeypadRow([null, '0', 'DEL']),
      ],
    );
  }

  Widget _buildKeypadRow(List<String?> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) {
          if (key == null) return const SizedBox(width: 80);
          if (key == 'DEL') {
            return IconButton(
              iconSize: 32,
              onPressed: _onDeletePress,
              icon: const Icon(Icons.backspace_outlined),
            );
          }
          return TextButton(
            onPressed: () => _onDigitPress(key),
            style: TextButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(24),
            ),
            child: Text(
              key,
              style: const TextStyle(fontSize: 28, color: Colors.white),
            ),
          );
        }).toList(),
      ),
    );
  }
}
