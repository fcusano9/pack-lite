/// The packing-relevant shortlist, injected as the icon picker's **first tab**
/// and the one it opens on. Since #57 it is a fast path, not a limit — every
/// other emoji is one tab or one search away.
///
/// Order matters: these fill the tab's grid top-left first, so the leading few
/// are what a user sees the instant the sheet opens.
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
