import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/field_repository.dart';
import 'phone_access.dart';

String operationError(Object e) => e is PostgrestException ? e.message : 'Check your connection and refresh before trying again.';

typedef Row = Map<String, dynamic>;
List<Row> rows(dynamic value) => (value as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
String label(dynamic value) => (value ?? '').toString().replaceAll('_', ' ');
String localTime(dynamic value) {
  final d = DateTime.tryParse('$value')?.toLocal();
  if (d == null) return 'Unknown time';
  return '${d.month}/${d.day}/${d.year} ${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

class EntryField {
  const EntryField(this.key, this.title, {this.value = '', this.options, this.date = false, this.number = false});
  final String key, title, value;
  final Map<String, String>? options;
  final bool date, number;
}

Future<Row?> entryForm(BuildContext context, String title, List<EntryField> fields, {String? explanation}) => Navigator.push<Row>(context, MaterialPageRoute(builder: (_) => _EntryForm(title: title, fields: fields, explanation: explanation)));
class _EntryForm extends StatefulWidget {
  const _EntryForm({required this.title, required this.fields, this.explanation});
  final String title;
  final List<EntryField> fields;
  final String? explanation;
  @override
  State<_EntryForm> createState() => _EntryFormState();
}
class _EntryFormState extends State<_EntryForm> {
  late final Map<String, TextEditingController> values = {for (final f in widget.fields) f.key: TextEditingController(text: f.value)};
  @override
  void dispose() { for (final v in values.values) { v.dispose(); } super.dispose(); }
  Future<void> pick(EntryField f) async {
    final old = DateTime.tryParse(values[f.key]!.text)?.toLocal() ?? DateTime.now();
    final day = await showDatePicker(context: context, initialDate: old, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(old));
    if (time == null || !mounted) return;
    setState(() => values[f.key]!.text = DateTime(day.year, day.month, day.day, time.hour, time.minute).toUtc().toIso8601String());
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.title)), body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
    if (widget.explanation != null) Padding(padding: const EdgeInsets.only(bottom: 20), child: Text(widget.explanation!)),
    for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 20), child: f.date
      ? OutlinedButton.icon(onPressed: () => pick(f), icon: const Icon(Icons.calendar_today), label: Text('${f.title}\n${localTime(values[f.key]!.text)}'))
      : f.options != null ? DropdownButtonFormField<String>(initialValue: f.options!.containsKey(values[f.key]!.text) ? values[f.key]!.text : null, isExpanded: true, decoration: InputDecoration(labelText: f.title), items: f.options!.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => values[f.key]!.text = v ?? '')
      : TextField(controller: values[f.key], maxLength: f.key == 'note' ? 2000 : 160, keyboardType: f.number ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: f.title))),
    FilledButton(onPressed: () => Navigator.pop(context, {for (final e in values.entries) e.key: e.value.text.trim()}), child: const Text('Continue')),
  ])));
}

class OperationsPage extends StatefulWidget {
  const OperationsPage({super.key, required this.repository, required this.companyId, this.initialTab = 0});
  final FieldRepository repository;
  final String companyId;
  final int initialTab;
  @override
  State<OperationsPage> createState() => _OperationsPageState();
}
class _OperationsPageState extends State<OperationsPage> {
  Row? data;
  bool busy = false;
  String? error, notice;
  late int tab = widget.initialTab;
  Future<dynamic> rpc(String action, [Row args = const {}]) => widget.repository.client.rpc('cc_operations', params: {'company': widget.companyId, 'action': action, 'data': args});
  String get role => data?['role'] as String? ?? '';
  bool get owner => role == 'owner';
  bool get manager => owner || role == 'supervisor';
  bool get sub => role == 'sub_lead' || role == 'sub_rep';
  String get uid => widget.repository.userId;
  List<Row> list(String key) => rows(data?[key]);
  Map<String, String> options(String key, [String name = 'name']) => {for (final r in list(key)) r['id'] as String: '${r[name]}'};
  @override
  void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final result = Map<String, dynamic>.from(await rpc('state') as Map);
      if (mounted) setState(() => data = result);
    } catch (e) { if (mounted) setState(() => error = 'Could not refresh: ${operationError(e)}'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> run(String action, Row args) async {
    if (busy) return;
    setState(() { busy = true; error = null; notice = null; });
    try {
      final result = await rpc(action, args);
      if (!mounted) return;
      if (action == 'invite') {
        final text = 'Join CrewClocker using ${result['contact']}. Sign in with that verified phone number or email, open Company invitations, and accept your invitation. Invitation code: ${result['token']}';
        await showDialog<void>(context: context, builder: (c) => AlertDialog(title: const Text('Invitation created'), content: SingleChildScrollView(child: SelectableText(text)), actions: [TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: text)); }, child: const Text('Copy instructions')), TextButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))]));
      } else if (action == 'import_visits') {
        notice = '${result['imported']} drafts added. ${result['overlaps']} overlapping visits skipped. Use a manual entry for the correct job when circles overlap. Review all times and breaks.';
      } else { notice = 'Saved.'; }
      final resultState = Map<String, dynamic>.from(await rpc('state') as Map);
      if (mounted) setState(() => data = resultState);
    } catch (e) { if (mounted) setState(() => error = 'Could not save: ${operationError(e)}'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> form(String title, String action, List<EntryField> fields, {Row base = const {}, String? explanation}) async {
    final result = await entryForm(context, title, fields, explanation: explanation);
    if (result == null || !mounted) return;
    if (action == 'invite') {
      final contact = result['contact'] as String;
      result['contact'] = contact.contains('@') ? contact.toLowerCase() : normalizePhone(contact) ?? contact;
    }
    await run(action, {...base, ...result});
  }
  Widget button(String title, VoidCallback action, {bool primary = false}) => Padding(padding: const EdgeInsets.only(right: 8, bottom: 8), child: primary ? FilledButton(onPressed: busy ? null : action, child: Text(title)) : OutlinedButton(onPressed: busy ? null : action, child: Text(title)));
  Widget heading(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(text, style: Theme.of(context).textTheme.titleLarge));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crew operations'), actions: [IconButton(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh')]),
    body: SafeArea(child: Column(children: [
      if (busy) const LinearProgressIndicator(),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      if (notice != null) Padding(padding: const EdgeInsets.all(12), child: Text(notice!)),
      if (data != null) Padding(padding: const EdgeInsets.all(12), child: Text('${label(role)} • Refreshed ${localTime(data!['server_time'])}')),
      Expanded(child: data == null ? Center(child: Text(busy ? 'Loading…' : 'Tap refresh to try again.')) : [attendance(), timecards(), team()][tab]),
    ])),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Attendance'), NavigationDestination(icon: Icon(Icons.schedule), label: 'Timecards'), NavigationDestination(icon: Icon(Icons.people_outline), label: 'People')]),
  );

  Widget attendance() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('See scheduled arrivals and who has been observed at a job. A person’s phone does not prove their entire crew is present. Crew reports are recorded separately.'),
    const SizedBox(height: 12),
    if (manager) Wrap(children: [
      button('Schedule arrival', () {
        final now = DateTime.now();
        form('Schedule crew arrival', 'schedule', [EntryField('crew_id', 'Crew', options: options('crews')), EntryField('site_id', 'Job site', options: options('jobs')), EntryField('start', 'Arrival window starts', date: true, value: now.toUtc().toIso8601String()), EntryField('end', 'Arrival window ends', date: true, value: now.add(const Duration(hours: 1)).toUtc().toIso8601String()), const EntryField('note', 'Customer commitment or notes')], explanation: 'Times use this phone’s time zone. This assigns the job to current crew members. Ask them to reopen CrewClocker to receive assignments.');
      }, primary: true),
      if (owner) button('Assign crew to job', () => form('Assign job', 'assign_crew', [EntryField('crew_id', 'Crew', options: options('crews')), EntryField('site_id', 'Job site', options: options('jobs'))])),
    ]),
    heading('Arrival commitments'),
    const Text('Showing the past 30 days and next 90 days. Refresh for newly uploaded observations.'),
    if (list('schedules').isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No scheduled arrivals yet.')),
    ...list('schedules').map(scheduleTile),
  ]);
  Widget scheduleTile(Row s) {
    final reports = rows(s['reports']);
    final detected = rows(s['detected']);
    final end = DateTime.parse(s['window_end'] as String);
    final cancelled = s['cancelled'] == true;
    final arrived = reports.any((r) => r['kind'] == 'arrival' || r['kind'] == 'crew_remaining') || detected.any((r) => r['transition'] == 'enter' || r['transition'] == 'dwell');
    final overdue = !cancelled && !arrived && end.isBefore(DateTime.now());
    final status = cancelled ? 'Cancelled' : arrived ? 'Arrival evidence recorded — review below' : overdue ? 'Arrival unconfirmed — follow up' : 'Awaiting arrival';
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${s['crew_name']} • ${s['site_name']}', style: Theme.of(context).textTheme.titleMedium),
      Text('${localTime(s['window_start'])} – ${localTime(s['window_end'])}'),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: overdue ? const Color(0xffc62828) : arrived ? const Color(0xff2e7d32) : null))),
      if ('${s['notes']}'.isNotEmpty) Text('${s['notes']}'),
      const SizedBox(height: 8), const Text('Detected individual phones', style: TextStyle(fontWeight: FontWeight.bold)),
      if (detected.isEmpty) const Text('No uploaded detections. This does not prove absence.'),
      ...detected.map((d) => Text('${d['person']}: ${label(d['transition'])} ${localTime(d['observed_at'])}\nReceived ${localTime(d['received_at'])}')),
      const SizedBox(height: 8), const Text('Reported crew presence', style: TextStyle(fontWeight: FontWeight.bold)),
      if (reports.isEmpty) const Text('No reports yet.'),
      ...reports.map((r) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${r['reporter_name']}: ${label(r['kind'])}${r['headcount'] == null ? '' : ' • ${r['headcount']} people'}\n${localTime(r['reported_at'])}${r['note'] == '' ? '' : '\n${r['note']}'}'))),
      if (!cancelled) Wrap(children: [
        button('Report / confirm', () => form('Report crew status', 'report', [const EntryField('kind', 'Report type', value: 'confirm', options: {'confirm': 'Confirm planned arrival', 'arrival': 'Crew arrived', 'departure': 'Crew departed', 'delay': 'Running late', 'crew_remaining': 'Crew working without lead'}), const EntryField('headcount', 'People on site (required for arrival / remaining)', number: true), const EntryField('note', 'Details or expected arrival time')], base: {'schedule_id': s['id']}, explanation: 'This records your report and its time. It does not claim GPS verification of the crew.')),
        if (manager) button('Cancel commitment', () async {
          final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Cancel this arrival commitment?'), content: const Text('Reports and observations will be kept.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel commitment'))]));
          if (yes == true) await run('cancel_schedule', {'schedule_id': s['id']});
        }),
      ]),
    ])));
  }

  Future<void> editCard([Row? c]) => form(c == null ? 'Add timecard' : 'Correct timecard', 'save_card', [
    EntryField('site_id', 'Job', value: c?['site_id'] as String? ?? '', options: {...options('jobs'), if (c != null) c['site_id'] as String: '${c['site_name']}'}),
    EntryField('start', 'Start', date: true, value: c?['started_at'] as String? ?? DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String()),
    EntryField('end', 'End', date: true, value: c?['ended_at'] as String? ?? DateTime.now().toUtc().toIso8601String()),
    EntryField('break_minutes', 'Unpaid break minutes', number: true, value: '${((c?['break_seconds'] as num? ?? 0) / 60).round()}'),
    const EntryField('note', 'Reason / notes (required for corrections)'),
  ], base: {if (c != null) 'id': c['id'], if (c != null) 'revision': c['revision']}, explanation: 'Review the correct job, local times, and unpaid breaks. Overlapping timecards cannot be saved.');

  Widget timecards() {
    if (sub) return const Padding(padding: EdgeInsets.all(24), child: Text('Subcontractor accounts use Attendance to record when your crew represents the company on site. Employee payroll timecards are not used for subcontractors.'));
    final cards = list('cards');
    final mine = cards.where((c) => c['user_id'] == uid && c['status'] != 'void').toList();
    final open = mine.where((c) => c['ended_at'] == null).toList();
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final totals = <String, int>{};
    for (final c in mine.where((c) => c['ended_at'] != null)) {
      final start = DateTime.parse(c['started_at'] as String).toLocal();
      if (start.isBefore(monday) || !start.isBefore(monday.add(const Duration(days: 7)))) continue;
      final secs = DateTime.parse(c['ended_at'] as String).difference(start).inSeconds - (c['break_seconds'] as num).toInt();
      totals[c['status'] as String] = (totals[c['status']] ?? 0) + secs;
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      heading('My time'), const Text('Online connection required for timecard actions. Detected visits become drafts for review; they never become approved hours automatically.'),
      heading('This week'),
      Text('Week starting ${monday.month}/${monday.day}. Cards grouped by their local start date.'),
      if (totals.isEmpty) const Text('No closed timecards this week.'),
      ...totals.entries.map((e) => Text('${label(e.key)}: ${(e.value / 3600).toStringAsFixed(2)} hours')),
      const SizedBox(height: 12),
      Wrap(children: [if (open.isEmpty) button('Clock in', () => form('Clock in', 'clock_in', [EntryField('site_id', 'Job', options: options('jobs'))]), primary: true), button('Add time manually', () => editCard()), button('Review detected visits', () => run('import_visits', {}))]),
      if (owner) const Text('Your own timecards need another authorized reviewer; owners cannot approve themselves.'),
      heading('My timecards'),
      if (mine.isEmpty) const Text('No timecards yet.'),
      ...mine.map(cardTile),
      if (manager) ...[heading('Crew timecards'), const Text('Only authorized reviewers can approve submitted cards. A correction request returns the card to its author.'), ...cards.where((c) => c['user_id'] != uid && c['status'] != 'void').map(cardTile)],
      const Text('The latest 300 accessible timecards are loaded. Totals cover the loaded cards only.'),
    ]);
  }
  Widget cardTile(Row c) {
    final own = c['user_id'] == uid;
    final open = c['ended_at'] == null;
    final editable = c['status'] == 'draft' || c['status'] == 'changes_requested';
    final args = {'id': c['id'], 'revision': c['revision']};
    final hours = open ? null : (DateTime.parse(c['ended_at'] as String).difference(DateTime.parse(c['started_at'] as String)).inSeconds - (c['break_seconds'] as num)) / 3600;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${c['person_name']} • ${c['site_name']}', style: Theme.of(context).textTheme.titleMedium),
      Text('${localTime(c['started_at'])} – ${open ? 'Clocked in' : localTime(c['ended_at'])}'),
      Text('${label(c['status'])}${hours == null ? '' : ' • ${hours.toStringAsFixed(2)} hours'} • ${((c['break_seconds'] as num) / 60).toStringAsFixed(1)} break minutes', style: TextStyle(color: c['status'] == 'approved' ? const Color(0xff2e7d32) : c['status'] == 'changes_requested' ? const Color(0xffc62828) : null)),
      if (c['break_started'] != null) Text('On break since ${localTime(c['break_started'])}'),
      if (c['note'] != '') Text('${c['note']}'),
      const SizedBox(height: 8),
      Wrap(children: [
        if (own && open && editable) ...[button(c['break_started'] == null ? 'Start break' : 'End break', () => run(c['break_started'] == null ? 'break' : 'resume', args)), button('Clock out', () => run('clock_out', args), primary: true)],
        if (own && !open && editable) ...[button('Correct', () => editCard(c)), button('Submit for review', () => run('submit', args), primary: true)],
        if (own && editable) button('Remove draft', () => form('Remove draft', 'void', [const EntryField('note', 'Reason')], base: args, explanation: 'The draft will be voided. Its history is retained.')),
        if (!own && manager && c['status'] == 'submitted') ...[button('Approve', () => run('approve', args), primary: true), button('Request correction', () => form('Request correction', 'request_changes', [const EntryField('note', 'What needs correction?')], base: args))],
      ]),
      ExpansionTile(title: const Text('History'), tilePadding: EdgeInsets.zero, children: rows(c['history']).map((h) => ListTile(title: Text(label(h['action'])), subtitle: Text('${localTime(h['recorded_at'])}\n${h['reason']}'))).toList()),
    ])));
  }

  static const roles = {'employee': 'Crew member', 'supervisor': 'Field supervisor', 'sub_lead': 'Subcontractor lead', 'sub_rep': 'Subcontractor on-site representative'};
  Widget team() => ListView(padding: const EdgeInsets.all(20), children: [
    if (owner) Wrap(children: [
      button('Create crew', () => form('Create crew', 'create_crew', [const EntryField('name', 'Crew / subcontractor name'), const EntryField('kind', 'Crew type', value: 'employee', options: {'employee': 'Employee crew', 'sub': 'Subcontractor crew'})]), primary: true),
      button('Invite person', () => form('Invite person', 'invite', [const EntryField('contact', 'Phone number (+country code) or email'), const EntryField('role', 'Access level', value: 'employee', options: roles), EntryField('crew_id', 'Crew', value: '', options: {'': 'No crew yet', ...options('crews')})], explanation: 'Phone numbers work without email. Invitations expire after 7 days. You can copy instructions to send yourself; creating an invitation does not send a message.')),
    ]),
    const Text('Subcontractor leads may report that their crew is working without them. An optional on-site representative can provide individual phone observations. Neither is employee payroll tracking.'),
    heading('Crews'),
    ...list('crews').map((c) => Card(child: ListTile(title: Text('${c['name']}'), subtitle: Text('${c['kind'] == 'sub' ? 'Subcontractor' : 'Employee'} crew'), trailing: owner ? const Icon(Icons.edit_outlined) : null, onTap: !owner ? null : () => form('Crew access', 'configure_crew', [EntryField('lead_id', 'Lead', value: c['lead_id'] as String? ?? '', options: {'': 'None', for (final p in list('people').where((p) => p['active'] == true && p['role'] == (c['kind'] == 'sub' ? 'sub_lead' : 'supervisor'))) p['user_id'] as String: '${p['name']}'}), EntryField('supervisor_id', 'Field supervisor', value: c['supervisor_id'] as String? ?? '', options: {'': 'None', for (final p in list('people').where((p) => p['active'] == true && p['role'] == 'supervisor')) p['user_id'] as String: '${p['name']}'})], base: {'id': c['id']})))),
    heading('People'),
    ...list('people').map((p) => Card(child: ListTile(title: Text('${p['name']}'), subtitle: Text('${roles[p['role']] ?? label(p['role'])}${p['active'] == false ? ' • Inactive' : ''}'), trailing: owner && p['role'] != 'owner' ? const Icon(Icons.edit_outlined) : null, onTap: !owner || p['role'] == 'owner' ? null : () => form('Change access', 'set_person', [EntryField('role', 'Role', value: p['role'] as String, options: roles), EntryField('crew_id', 'Crew', value: p['crew_id'] as String? ?? '', options: {'': 'None', ...options('crews')}), EntryField('active', 'Account access', value: '${p['active']}', options: const {'true': 'Active', 'false': 'Inactive'})], base: {'user_id': p['user_id']}, explanation: 'The person must reopen the app to update phone monitoring. Close any running timecard first. After changing roles, review crew lead and supervisor assignments.')))),
    if (owner) ...[heading('Invitations'), ...list('invites').map((i) => ListTile(title: Text('${i['contact']}'), subtitle: Text('${roles[i['role']]} • ${i['used'] == true ? 'Accepted' : i['revoked'] == true ? 'Revoked' : 'Expires ${localTime(i['expires_at'])}'}'), trailing: i['used'] == true || i['revoked'] == true ? null : TextButton(onPressed: busy ? null : () => run('revoke_invite', {'id': i['id']}), child: const Text('Revoke'))))],
  ]);
}

class CompanyInvitations extends StatefulWidget {
  const CompanyInvitations({super.key, required this.repository});
  final FieldRepository repository;
  @override
  State<CompanyInvitations> createState() => _CompanyInvitationsState();
}
class _CompanyInvitationsState extends State<CompanyInvitations> {
  List<Row> invites = [];
  String? error;
  bool busy = false;
  @override
  void initState() { super.initState(); load(); }
  Future<dynamic> rpc(String action, Row data) => widget.repository.client.rpc('cc_operations', params: {'company': null, 'action': action, 'data': data});
  Future<void> load() async {
    setState(() => busy = true);
    try { final result = rows(await rpc('pending_invites', {})); if (mounted) setState(() { invites = result; error = null; }); }
    catch (e) { if (mounted) setState(() => error = operationError(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> accept([Row? invite]) async {
    final values = await entryForm(context, 'Join company', [const EntryField('name', 'Your name'), if (invite == null) const EntryField('token', 'Invitation code')], explanation: 'Sign in with the verified phone number or email your company invited.');
    if (values == null || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await rpc('accept_invite', {...values, if (invite != null) 'id': invite['id']});
      if (mounted) Navigator.pop(context, result['company_id'] as String);
    } catch (e) { if (mounted) setState(() => error = operationError(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Company invitations')), body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
    if (busy) const LinearProgressIndicator(), if (error != null) Text(error!),
    const Text('Invitations matching your verified phone number or email appear here.'),
    if (!busy && invites.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No pending invitations. Ask your company owner to invite this account.')),
    ...invites.map((i) => ListTile(title: Text('${i['company_name']}'), subtitle: Text(label(i['role'])), trailing: FilledButton(onPressed: busy ? null : () => accept(i), child: const Text('Join')))),
    TextButton(onPressed: busy ? null : () => accept(), child: const Text('Enter invitation code')),
    TextButton(onPressed: busy ? null : load, child: const Text('Refresh invitations')),
  ])));
}
