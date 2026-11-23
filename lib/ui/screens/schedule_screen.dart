import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/feed_repository.dart';
import '../../services/schedule_service.dart';
import '../widgets/artwork.dart';
import '../widgets/common.dart';
import 'podcast_screen.dart';

/// Parrilla de programación: hoy y los próximos días, como en la web.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, this.now});

  /// Hora fija (solo para capturas y pruebas).
  final DateTime? now;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ScheduleService>().refresh();
      });
      // Actualiza «en directo» y quita lo que va terminando.
      _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedule = context.watch<ScheduleService>();
    final now = widget.now ?? ScheduleService.nowInMadrid();
    final days = schedule.upcomingByDay(now: now);
    final title = schedule.config.schedule?.title ?? 'Parrilla de programación';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: schedule.refresh,
        child: schedule.entries.isEmpty
            ? ListView(children: [
                SizedBox(
                  height: 420,
                  child: schedule.loading
                      ? const Center(child: CircularProgressIndicator())
                      : MessageView(
                          icon: Icons.calendar_month_outlined,
                          title: 'Parrilla no disponible',
                          message: schedule.error,
                          actionLabel: 'Reintentar',
                          onAction: schedule.refresh,
                        ),
                ),
              ])
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (schedule.error != null) InlineNotice(schedule.error!),
                  for (final day in days.keys) ...[
                    _DayHeader(day: day, today: _sameDay(day, now)),
                    if (days[day]!.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Text('Sin emisiones programadas',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                      )
                    else
                      for (final e in days[day]!) _EntryTile(entry: e, onAir: e.isOnAirAt(now)),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text('Horario peninsular (Madrid).',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.today});
  final DateTime day;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = DateFormat("EEEE d 'de' MMMM", 'es').format(day);
    final text = today ? 'Hoy · $label' : label[0].toUpperCase() + label.substring(1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: today ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(text,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: today ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: FontWeight.w700,
                )),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onAir});
  final ScheduleEntry entry;
  final bool onAir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hm = DateFormat('HH:mm');
    final program = entry.program;
    final image = program == null ? null : context.watch<FeedRepository>().programImage(program.id);

    return InkWell(
      onTap: program == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PodcastScreen(program: program))),
      child: Container(
        color: onAir ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hm.format(entry.start), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text(hm.format(entry.end),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Artwork(
              url: image,
              fallbackAsset: program?.fallbackImage ?? 'assets/branding/logo_margenes.png',
              size: 44,
              radius: 10,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onAir)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('EN DIRECTO',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    ),
                  Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
            if (program != null) Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
