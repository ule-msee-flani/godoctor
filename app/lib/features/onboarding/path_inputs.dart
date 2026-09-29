import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../services/geocoding.dart';

/// Kenya's 47 counties, for "where do you practise".
const kCounties = [
  'Baringo',
  'Bomet',
  'Bungoma',
  'Busia',
  'Elgeyo-Marakwet',
  'Embu',
  'Garissa',
  'Homa Bay',
  'Isiolo',
  'Kajiado',
  'Kakamega',
  'Kericho',
  'Kiambu',
  'Kilifi',
  'Kirinyaga',
  'Kisii',
  'Kisumu',
  'Kitui',
  'Kwale',
  'Laikipia',
  'Lamu',
  'Machakos',
  'Makueni',
  'Mandera',
  'Marsabit',
  'Meru',
  'Migori',
  'Mombasa',
  'Murang\'a',
  'Nairobi',
  'Nakuru',
  'Nandi',
  'Narok',
  'Nyamira',
  'Nyandarua',
  'Nyeri',
  'Samburu',
  'Siaya',
  'Taita-Taveta',
  'Tana River',
  'Tharaka-Nithi',
  'Trans Nzoia',
  'Turkana',
  'Uasin Gishu',
  'Vihiga',
  'Wajir',
  'West Pokot',
];

/// "Ruiru, Kiambu, Kenya" -> "Kiambu" when it's a county name.
String? countyFromPlace(String? place) {
  if (place == null) return null;
  for (final part in place.split(',').map((p) => p.trim())) {
    for (final c in kCounties) {
      if (part.toLowerCase() == c.toLowerCase() ||
          part.toLowerCase() == '$c county'.toLowerCase()) {
        return c;
      }
    }
  }
  return null;
}

/// A small heading over a second question on the same screen.
class SubQuestion extends StatelessWidget {
  const SubQuestion(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 10),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

/// A roomy single-line (or short multi-line) answer.
class TextAnswer extends StatefulWidget {
  const TextAnswer({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.keyboard = TextInputType.text,
    this.capitalization = TextCapitalization.sentences,
    this.maxLength = 120,
    this.maxLines = 1,
    this.autofocus = false,
    this.digitsOnly = false,
    this.prefix,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final TextInputType keyboard;
  final TextCapitalization capitalization;
  final int maxLength;
  final int maxLines;
  final bool autofocus;
  final bool digitsOnly;
  final String? prefix;

  @override
  State<TextAnswer> createState() => _TextAnswerState();
}

class _TextAnswerState extends State<TextAnswer> {
  late final _ctrl = TextEditingController(text: widget.value ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboard,
      textCapitalization: widget.capitalization,
      maxLength: widget.maxLength,
      maxLines: widget.maxLines,
      minLines: 1,
      inputFormatters: widget.digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: Theme.of(context).textTheme.titleMedium,
      decoration: InputDecoration(
        hintText: widget.hint,
        counterText: '',
        prefixText: widget.prefix,
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// Big tappable answers. [multi] lets several be picked; [exclusive]
/// values (like "None") clear the others.
class ChoiceAnswer extends StatelessWidget {
  const ChoiceAnswer({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multi = false,
    this.exclusive = const {},
    this.compact = false,
  });

  final List<(String value, String label, IconData? icon)> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool multi;
  final Set<String> exclusive;

  /// Chips instead of full-width tiles (for long lists).
  final bool compact;

  void _tap(String v) {
    HapticFeedback.selectionClick();
    if (!multi) {
      onChanged({v});
      return;
    }
    final next = {...selected};
    if (next.contains(v)) {
      next.remove(v);
    } else if (exclusive.contains(v)) {
      next
        ..clear()
        ..add(v);
    } else {
      next
        ..removeAll(exclusive)
        ..add(v);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (compact) {
      return Wrap(
        spacing: 8,
        runSpacing: 10,
        children: [
          for (final (v, label, icon) in options)
            _Chip(
              label: label,
              icon: icon,
              on: selected.contains(v),
              onTap: () => _tap(v),
            ),
        ],
      );
    }
    return Column(
      children: [
        for (final (v, label, icon) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: selected.contains(v)
                    ? AppColors.primarySoft
                    : AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected.contains(v)
                      ? AppColors.primary
                      : AppColors.border,
                  width: selected.contains(v) ? 1.8 : 1,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _tap(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: AppColors.primary),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            label,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        AnimatedScale(
                          duration: const Duration(milliseconds: 180),
                          scale: selected.contains(v) ? 1 : 0,
                          child: const Icon(
                            LucideIcons.circleCheck,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: on ? AppColors.primary : AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: on ? AppColors.primary : AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: on ? Colors.white : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: on ? Colors.white : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A date (birthday), picked from a calendar that opens on the year.
class DateAnswer extends StatelessWidget {
  const DateAnswer({super.key, required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _BigButton(
      icon: LucideIcons.cake,
      label: value == null
          ? 'Choose your date of birth'
          : DateFormat('d MMMM yyyy').format(value!),
      filled: value != null,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(now.year - 30, now.month, now.day),
          firstDate: DateTime(now.year - 110),
          lastDate: now,
          initialDatePickerMode: DatePickerMode.year,
          helpText: 'Date of birth',
        );
        if (picked != null) onChanged(picked);
      },
      trailing: value == null
          ? null
          : Text(
              '${_age(value!)} yrs',
              style: text.labelLarge?.copyWith(color: AppColors.primary),
            ),
    );
  }

  static int _age(DateTime d) {
    final n = DateTime.now();
    var a = n.year - d.year;
    if (n.month < d.month || (n.month == d.month && n.day < d.day)) a--;
    return a;
  }
}

/// Where: the app's map and search, or the phone's location.
class LocationAnswer extends StatelessWidget {
  const LocationAnswer({
    super.key,
    required this.name,
    required this.lat,
    required this.lng,
    required this.onChanged,
  });

  final String? name;
  final double? lat;
  final double? lng;
  final ValueChanged<Place> onChanged;

  @override
  Widget build(BuildContext context) {
    final has = lat != null && lng != null;
    return _BigButton(
      icon: LucideIcons.mapPin,
      label: has
          ? (name?.isNotEmpty == true ? name! : 'Location saved')
          : 'Find my place on the map',
      filled: has,
      onTap: () async {
        final picked = await context.push<Place>(
          '/account/location',
          extra: has ? Place(name: name ?? '', lat: lat!, lng: lng!) : null,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.primarySoft : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: filled ? AppColors.primary : AppColors.border,
          width: filled ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              trailing ??
                  Icon(
                    filled ? LucideIcons.pencil : LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.inkSoft,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A number picked on a slider, shown big ("7 years").
class NumberAnswer extends StatelessWidget {
  const NumberAnswer({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 40,
    required this.unit,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// (singular, plural)
  final (String, String) unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Text(
            value >= max ? '$max+' : '$value',
            key: ValueKey(value),
            style: text.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        Text(value == 1 ? unit.$1 : unit.$2, style: text.titleMedium),
        const SizedBox(height: 16),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v.round());
          },
        ),
      ],
    );
  }
}

/// Opening hours: "Open 24 hours", or from–to.
class HoursAnswer extends StatelessWidget {
  const HoursAnswer({super.key, required this.value, required this.onChanged});

  /// "24 hours" or "08:00-20:00".
  final String? value;
  final ValueChanged<String> onChanged;

  TimeOfDay? _part(int i) {
    final m = RegExp(
      r'^(\d{2}):(\d{2})-(\d{2}):(\d{2})$',
    ).firstMatch(value ?? '');
    if (m == null) return null;
    return TimeOfDay(
      hour: int.parse(m.group(i == 0 ? 1 : 3)!),
      minute: int.parse(m.group(i == 0 ? 2 : 4)!),
    );
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final allDay = value == '24 hours';
    final from = _part(0) ?? const TimeOfDay(hour: 8, minute: 0);
    final to = _part(1) ?? const TimeOfDay(hour: 20, minute: 0);
    Future<void> pick(bool start) async {
      final t = await showTimePicker(
        context: context,
        initialTime: start ? from : to,
      );
      if (t != null) {
        onChanged(
          start ? '${_fmt(t)}-${_fmt(to)}' : '${_fmt(from)}-${_fmt(t)}',
        );
      }
    }

    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Open 24 hours'),
          value: allDay,
          onChanged: (on) =>
              onChanged(on ? '24 hours' : '${_fmt(from)}-${_fmt(to)}'),
        ),
        if (!allDay)
          Row(
            children: [
              Expanded(
                child: _BigButton(
                  icon: LucideIcons.sunrise,
                  label: 'Opens ${from.format(context)}',
                  filled: value != null,
                  onTap: () => pick(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BigButton(
                  icon: LucideIcons.sunset,
                  label: 'Closes ${to.format(context)}',
                  filled: value != null,
                  onTap: () => pick(false),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A photo: tap to choose from the gallery.
class PhotoAnswer extends StatelessWidget {
  const PhotoAnswer({super.key, required this.preview, required this.onPick});

  /// Image to show (picked bytes or current photo), if any.
  final ImageProvider? preview;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onPick,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 58,
              backgroundColor: AppColors.primarySoft,
              backgroundImage: preview,
              child: preview == null
                  ? const Icon(
                      LucideIcons.camera,
                      size: 32,
                      color: AppColors.primary,
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.plus,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
