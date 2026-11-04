# Design: Recovery Aurora

The app is dark only, built on Apple's Human Interface Guidelines: clarity (large numerals, one idea per card), deference (data is the interface), depth (a lit card edge and soft shadow, no borders).

The full system, with live component previews, is published as the Recovery Aurora design system artifact. In code, the tokens live in `ios/AchillesRecovery/Design/Theme.swift`.

## Colour

| Token | Hex | Use |
|---|---|---|
| bg | `#070B14` | screen background |
| card | `#0F1626` | cards, tab bar |
| cardRaised | `#141C31` | inputs, pressed rows, set rows |
| text / textMuted | `#EAF0FF` / `#7B88A8` | text. Muted is 12pt and up only |
| recovery | `#00F5A0` | WHOOP recovery, primary buttons, done sets |
| strain | `#00B4FF` | WHOOP strain, training |
| sleep / sleepInk | `#7C5CFF` / `#A593FF` | sleep graphics / sleep text |
| nutrition | `#FFB547` | calories, protein, PR badges |
| water | `#4DE8FF` | water, swelling |
| alert | `#FF6B81` | pain, low days. Always paired with a word |
| onAccent | `#04110C` | text on filled accents. Never put text on a sleep fill |

One colour per metric, on every screen.

## Rules

- Rings are activity-ring style: round caps, a 16% track, a blurred glow. One hero cluster per screen.
- Motion is 150 to 300 ms. Rings fill with a spring (SwiftUI `trim`), and reduced motion shows them instantly.
- Touch targets are at least 44pt. Text is at least 12pt. Body text meets WCAG AA on every surface.
- No emoji icons: SF Symbols only. No coloured left-border cards. No gradients on cards.
- The aurora gradient (recovery to strain to sleep) is only a faint wash behind the screen title.

## Anti-patterns

- Light theme or white surfaces.
- More than one glowing numeral per screen.
- Colour as the only signal for status.
