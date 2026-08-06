/// The packing-relevant shortlist shown as **Suggested** at the top of the icon
/// picker. Since #57 it is a fast path, not a limit — the full emoji set sits
/// below it, so anything the user wants is reachable.
///
/// Order matters: the picker renders these as one horizontally scrolling row,
/// so the leading few are the ones visible without scrolling.
///
/// Milestone 1 note: these render through the device's emoji font (Samsung
/// style on Galaxy, Apple style on iPhone). Swapping in bundled artwork so
/// every device looks identical is planned for a later milestone — the
/// picker UI and data model won't change.
const curatedIcons = <String>[
  '🎒', '🧳', '✈️', '🏖️', '⛱️', '🏝️',
  '🚗', '🚆', '🚢', '⛵', '🛶', '🚴',
  '🏔️', '🏕️', '🥾', '🎿', '🏂', '❄️',
  '🏃', '🏊', '⚽', '🏈', '🎾', '⛳',
  '💼', '🏙️', '🎸', '🎭', '🎡', '🎉',
  '👶', '🐕', '📷', '🎣', '🌂', '🛍️',
];
