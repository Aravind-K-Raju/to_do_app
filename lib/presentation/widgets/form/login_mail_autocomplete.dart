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
        if (textEditingController.value != controller.value &&
            controller.text.isNotEmpty &&
            textEditingController.text.isEmpty) {
          textEditingController.value = controller.value;
        }

        // Listen to changes to update the parent controller
        textEditingController.addListener(() {
          if (controller.value != textEditingController.value) {
            controller.value = textEditingController.value;
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
