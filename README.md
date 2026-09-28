# Shuttr

**The digicam you never had, in your pocket.**

Android-first Flutter camera app that makes a phone shoot like a 2000s digicam — harsh flash, CCD colour, grain, orange date stamp. Camcorder video looks (VHS, MiniDV, Super 8, flip cam) come in v2. No ads, one-time unlock.

## Docs

- [CLAUDE.md](CLAUDE.md) — rules and conventions for Claude Code sessions
- [docs/PRODUCT.md](docs/PRODUCT.md) — audience, market, scope, pricing, metrics, risks
- [docs/STRATEGY.md](docs/STRATEGY.md) — long-term plan, money model, markets, scale/pivot triggers
- [docs/ROADMAP.md](docs/ROADMAP.md) — week-by-week timeline, phases and gates
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — stack, folder structure, render pipeline
- [docs/LOOKS.md](docs/LOOKS.md) — per-camera look specs and tuning process
- [docs/DECISIONS.md](docs/DECISIONS.md) — decision log
- [docs/PROGRESS.md](docs/PROGRESS.md) — current status and session log
- [docs/GTM.md](docs/GTM.md) — go-to-market plan

## Working with Claude Code

- `/start [goal]` — load current state, pick one feature for the session
- `/wrap` — update progress + decisions, propose a commit

## Getting started

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Requires Flutter (stable channel) and the Android SDK. App ID is currently a
placeholder (`dev.shuttr.shuttr`) pending a trademark/name check.
