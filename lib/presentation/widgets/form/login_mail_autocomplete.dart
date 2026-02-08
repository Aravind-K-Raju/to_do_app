import 'package:flutter/material.dart';

class LoginMailAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final List<String> distinctLoginMails;
  final String label;

  const LoginMailAutocomplete({
    super.key,
    required this.controller,
    required this.distinctLoginMails,
    this.label = 'Login Mail (Optional)',
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<String>.empty();
        }
        return distinctLoginMails.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        // Sync provided controller with this external one
        if (textEditingController.text != controller.text &&
            controller.text.isNotEmpty &&
            textEditingController.text.isEmpty) {
          textEditingController.text = controller.text;
        }

        // Listen to changes to update the parent controller
        textEditingController.addListener(() {
          // We need to be careful not to infinite loop if we were doing bidirectional bind,
          // but here we just want to ensure `controller` has the value.
          // However, `controller` is not a ValueNotifier we are listening to here,
          // but we want to write TO it.
          if (controller.text != textEditingController.text) {
            controller.text = textEditingController.text;
          }
        });

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          onFieldSubmitted: (String value) {
            onFieldSubmitted();
          },
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            helperText: 'Account used for login',
          ),
        );
      },
    );
  }
}
