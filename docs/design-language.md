# Design Language

ConvoCoach uses an original pearl-and-wave conversation mark: a rounded dialogue
outline contains two flowing lines and one pearl-like response point. It is
rendered in Flutter for in-app branding and generated for native Android and iOS
launchers from the same original geometry through a reproducible Swift source.

The visual language is vibrant, private, high-contrast, and oceanic. Its
mermaid-inspired direction uses sea-glass aqua, deep-water navy, violet,
pearl-white, and restrained coral-pink fields without depicting or copying a
character. Dark mode uses deep ocean surfaces with brighter pearl, violet,
coral, and aqua roles. Headings may use the accessible
tertiary-to-primary-to-secondary iridescent gradient; paragraphs and controls
remain solid colors so readability never depends on an effect.

Components use semantic tokens, 8/14/22 pixel radii, generous spacing, at least
44 pixel targets, and heavy system headings with plain-language body copy. Cards
frame actual content or tools; sections remain unframed. Status is always paired
with icons and text. The near-black navigation surface makes four stable product
spaces easy to identify: Home, Chats, Stats, and Settings.

Home is upload-first. A balanced menu/brand/quick-add header frames one centered
promise, one dominant near-black screenshot action with a thin iridescent edge,
two secondary paths for manual text and saved chats, and one synthetic layered
preview. The preview floats directly in the backdrop instead of imitating a
competitor's framed composition. It is decorative rather than interactive, has
one semantic description, and uses no real conversation content. Import offers
only actionable choices; unavailable future features do not compete with the
current path.

The import experience follows one user-facing sequence: **Upload screenshots →
Review conversation → Analyze**. Screenshot selection starts on-device text
preparation automatically; OCR, initial ordering, speaker suggestions, context
assembly, and server-side model routing are implementation details, not choices
the user must configure. A failed preparation keeps temporary images available
for an explicit retry, and optional upload-order controls remain progressively
disclosed for recovery rather than appearing in the primary path.

Review Studio carries the same hierarchy into the privacy-critical correction
step: a restrained animated wave backdrop, a concise privacy badge, an
iridescent review heading, a plain-language review status, and a single
high-emphasis **Confirm and analyze** action. Technical data-quality checks and
event classification controls live under optional details. Speaker corrections,
highlighted uncertainty, source comparison, consent, and message editing remain
immediately understandable. Coaching still cannot begin until the user has
reviewed and explicitly confirmed the normalized sequence. The final action is
never silently inert: its label and adjacent live status identify the exact
remaining human decision. On success the app persists the reviewed sequence
internally and opens Conversation Coach directly; it does not send the user to
an intermediate saved-list task.

Depth comes from short perspective transforms, layered synthetic cards, shadows,
and parallax-like pointer response. It never requires a separate 3D engine,
never blocks a control, and never loops for decoration. Imported screenshots do
not appear inside decorative previews.

Shared vibrant backdrops add low-opacity wave lines, a restrained scale arc,
and pearl glows from semantic theme roles. The decorations are pointer-ignored,
excluded from accessibility semantics, and contain no user media. The visual
identity must remain calm and private; it does not use sexualized mermaid imagery,
constant bubbles, sparkles, or attention-seeking particle fields.

Supplied competitor references may inform hierarchy, simplicity, pastel energy,
high-contrast actions, and depth, but never provide reusable brand marks, assets,
exact compositions, copied trade dress, compatibility scoring, attachment
labels, or claims about another person's interest. The dark navigation dock uses
an original four-space information architecture, iridescent selected icons, a
shape-backed selected state, and an adaptive large-text layout. ConvoCoach's
wording keeps uncertainty and user agency explicit.

The global Stats space uses an iridescent score hero, two concise aggregate
tiles, reply performance, explicit plan confirmation, and a protected private
reflection. The score concerns only the user's self-ratings for authenticity,
clarity, and boundary alignment. Individual conversations and people never
receive a customer-facing score.

Onboarding has three value pages followed by privacy, age confirmation, and mock
authentication, keeping the complete sequence to six conceptual screens. The
experience can be skipped only to the essential privacy and age gates.
