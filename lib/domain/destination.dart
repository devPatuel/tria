/// A folder the user can send files to, bound to a number key.
///
/// Slots are limited to 1..9 because they map directly to the number row of
/// the keyboard: the whole interaction model depends on the user never having
/// to look down at their hands.
class Destination {
  final int slot;
  final String label;
  final String path;

  Destination({required this.slot, required this.label, required this.path}) {
    if (slot < 1 || slot > 9) {
      throw ArgumentError.value(slot, 'slot', 'must be between 1 and 9');
    }
    if (label.isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
  }

  Map<String, dynamic> toJson() => {'slot': slot, 'label': label, 'path': path};

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
        slot: json['slot'] as int,
        label: json['label'] as String,
        path: json['path'] as String,
      );
}
