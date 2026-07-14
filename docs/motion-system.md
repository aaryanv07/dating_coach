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
spring-like ease-out-back curve with small scale travel. Onboarding metrics draw
from zero to their mock values; page content uses opacity and translation only.

`MotionScope` combines the operating-system `disableAnimations` preference with
the in-app Reduce Motion setting. Normal durations resolve to zero when reduction
is active, and skeleton loaders stop repeating at a static midpoint.
