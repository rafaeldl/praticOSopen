part of 'order_form_screen.dart';

class _DebouncedTextFormField extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final TextInputType? keyboardType;

  const _DebouncedTextFormField({
    Key? key,
    this.initialValue,
    required this.onChanged,
    this.placeholder,
    this.keyboardType,
  }) : super(key: key);

  @override
  _DebouncedTextFormFieldState createState() => _DebouncedTextFormFieldState();
}

class _DebouncedTextFormFieldState extends State<_DebouncedTextFormField> {
  late TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTextFormFieldRow(
      controller: _controller,
      placeholder: widget.placeholder,
      keyboardType: widget.keyboardType,
      onChanged: _onChanged,
      onEditingComplete: () {
        if (_debounce?.isActive ?? false) {
           _debounce!.cancel();
           widget.onChanged(_controller.text);
        }
        FocusScope.of(context).unfocus();
      },
    );
  }
}
