# Motion System

Motion communicates page progression, hierarchy, selection, loading, and
completion. It is never required to access a control.

| Token | Duration | Use |
| --- | ---: | --- |
| Fast | 160 ms | Press and selection feedback |
| Normal | 220 ms | Reveal and theme transitions |
| Deliberate | 280 ms | Page progression |
| Loading pulse | 900 ms | Subtle repeating skeleton only |

Standard transitions use an ease-out cubic curve. Press feedback uses a short
spring-like ease-out-back curve with small scale travel. Tappable cards scale to
98.5 percent and buttons scale to 98 percent while pressed. Onboarding metrics
draw from zero to their mock values; page content uses opacity and translation
only.

The startup experience uses one non-looping 280 ms sequence with at most three
visual moments: the brand mark, a decorative conversation signal, and the brand
copy. It navigates as soon as the sequence completes and contains no timer beyond
the animation duration. The Home screen similarly limits entrance motion to the
heading and two primary cards. Navigation remains available throughout ordinary
screen reveals.

The first onboarding page continues that opening experience with an original
ConvoCoach composition: a semantic-token gradient, an oversized setup headline,
and a tilted coaching-style preview card. The preview enters once with opacity,
translation, and scale over the deliberate 280 ms token. Its internal card tilt
is static, does not loop, and does not imply a personality, desirability, or
compatibility score. Decorative preview copy is exposed as one concise image
description so assistive technology does not have to traverse fake controls.
Large text remains enabled for real headings, guidance, and actions.

`MotionScope` combines the operating-system `disableAnimations` preference with
the in-app Reduce Motion setting. Normal durations resolve to zero when reduction
is active, the startup route advances on the next frame, press scaling is
instant, and skeleton loaders stop repeating at a static midpoint.

## Bounded depth effects

ConvoCoach uses 2.5D transforms rather than a 3D engine. The Home preview may
tilt by at most 0.06 radians around its vertical axis and 0.045 radians around
its horizontal axis while a pointer moves across it. It returns to neutral over
the 160 ms fast token, does not capture the scroll gesture, and remains fully
static when motion reduction is active.

The screenshot import screen uses one 280 ms synthetic card-stack spread when
the selected count changes. It never renders imported image bytes in the
decorative stack. Root-tab changes use one 220 ms opacity and small horizontal
translation, while a complete coaching result uses one 280 ms opacity,
translation, scale, and shallow perspective reveal. No individual result card
stages separately, keeping each screen within the three-major-moment limit.

Reduced motion removes Home tilt updates, card-stack interpolation, tab
transitions, and coaching-result perspective. All final content, hierarchy, and
actions remain identical.

## Oceanic surface reveal

Shared oceanic backdrops reveal their decorative wave field once with 18 pixels
of vertical travel and opacity over the deliberate 280 ms token. Pearl glows and
scale arcs remain static, and the wave field never loops or follows the device
gyroscope. The splash disables this extra backdrop interpolation because its
existing 280 ms brand sequence already contains the maximum three major visual
moments.

When reduced motion is active, the wave field starts in its final position with
zero duration. Decorative painting ignores pointer input, is isolated behind a
repaint boundary, and exposes no additional accessibility nodes.
