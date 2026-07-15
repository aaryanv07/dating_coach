# Accessibility Foundation

Phase 2 establishes:

- semantic labels for branding, onboarding progress, privacy, age, and primary
  actions;
- text and icons in addition to status color;
- touch targets of at least 44 logical pixels;
- system text scaling with a scrollable onboarding composition above 130 percent;
- reduced-motion support from both system and application preferences;
- high-contrast light and dark semantic color roles;
- live-region semantics for empty, error, and offline states;
- familiar Material navigation icons with visible labels.

Tests exercise 200 percent text scale on a compact 390 by 844 viewport, essential
age-action semantics, touch-target sizing, reduced-duration resolution, and
non-color state messaging. Device screen-reader and switch-control audits remain
required before release.

Phase 3 profile dropdowns expand within their fields and constrain selected
labels while retaining full labels in the open menu. The profile route is also
covered at 200 percent text scale on the compact viewport.

Phase 4 adds semantic readiness and low-confidence announcements, text labels in
addition to status icons, keyboard-accessible fields and menus, Command/Control-Z
undo and Shift-Command/Control-Z redo, source-image semantics, and explicit
44-pixel app-bar actions. The Review Studio uses wrapping/vertical quality rows
at 200 percent text scale to prevent horizontal clipping. VoiceOver, TalkBack,
hardware-keyboard traversal, and switch-control still require physical-device
audits before release.

Phase 5 adds a text-and-icon extraction review-note panel, announces it as a
semantic region, keeps low-confidence text labels, and exposes a non-blocking
cancel-extraction action. Unknown speakers remain explicit selectable values.
VoiceOver and TalkBack behavior during native OCR progress still requires a
physical-device audit.
