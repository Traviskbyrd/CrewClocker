import 'package:flutter/material.dart';

class JobEdit {
  const JobEdit(this.name, this.radius);
  final String name;
  final int radius;
}

class EditJobPage extends StatefulWidget {
  const EditJobPage({super.key, required this.name, required this.radius});
  final String name;
  final int radius;
  @override
  State<EditJobPage> createState() => _EditJobPageState();
}

class _EditJobPageState extends State<EditJobPage> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.name);
  late final radius = TextEditingController(text: '${widget.radius}');
  @override
  void dispose() { name.dispose(); radius.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final meters = int.tryParse(radius.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit job')),
      body: SafeArea(child: Form(key: form, child: ListView(
        padding: const EdgeInsets.all(20), children: [
          TextFormField(controller: name, maxLength: 160,
            decoration: const InputDecoration(labelText: 'Job name'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter a job name.' : null),
          const SizedBox(height: 16),
          TextFormField(controller: radius, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tracking radius (meters)', helperText: '25–1000 meters'),
            onChanged: (_) => setState(() {}),
            validator: (v) { final n = int.tryParse(v ?? '');
              return n == null || n < 25 || n > 1000 ? 'Enter a whole number from 25 to 1000.' : null; }),
          if (meters != null && meters >= 25 && meters <= 1000) ...[
            Slider(value: meters.toDouble(), min: 25, max: 1000, divisions: 195,
              label: '$meters m', onChanged: (v) => setState(() => radius.text = '${v.round()}')),
            Text('$meters meters ≈ ${(meters * 3.28084).round()} feet'),
          ],
          const SizedBox(height: 16),
          const Text('Smaller circles can reduce overlap, but radiuses below 100 meters may miss or delay arrival and departure detection. Test the new boundary on your phone.'),
          const SizedBox(height: 16),
          const Text('Saving briefly pauses monitoring and syncs observations, then updates the registered sites if monitoring was on. Past observations keep their original job details.'),
          const SizedBox(height: 24),
          FilledButton(onPressed: () {
            if (form.currentState!.validate()) Navigator.of(context).pop(JobEdit(name.text.trim(), int.parse(radius.text)));
          }, child: const Text('Save changes')),
        ],
      ))),
    );
  }
}
