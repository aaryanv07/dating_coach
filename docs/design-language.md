# Design Language

ConvoCoach uses an original conversation mark: a rounded dialogue outline with
two balanced response points. It is rendered in Flutter for in-app branding and
generated as native Android/iOS launcher artwork from a reproducible Swift source.

The visual language is calm and high-contrast rather than neon or decorative.
Light mode uses a cool off-white canvas and white raised surfaces. Dark mode uses
charcoal and elevated graphite, avoiding pure black across every layer. Indigo,
teal, and berry roles provide distinct primary, secondary, and accent signals.

Components use semantic tokens, 4/8 pixel radii, generous spacing, 44 pixel
minimum targets, and system typography. Cards frame actual content or tools;
sections remain unframed. Status is always paired with icons and text.

Onboarding has three value pages followed by privacy, age confirmation, and mock
authentication, keeping the complete sequence to six conceptual screens. The
experience can be skipped only to the essential privacy and age gates.
