#!/usr/bin/env python3
"""Generate 100 survey JSON files (smartphone usage) under data/surveys/. Idempotent."""
from __future__ import annotations

import json
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent / "data" / "surveys"

QUESTION_BANK = [
    (
        "How many hours per day do you use your smartphone on weekdays?",
        ["Under 1h", "1–2h", "3–4h", "5h or more"],
    ),
    (
        "Which activity do you use your phone for most often?",
        ["Messaging", "Social feeds", "Video streaming", "Work email / docs"],
    ),
    (
        "Do you use screen-time limits or focus modes?",
        ["Never tried", "Sometimes", "Daily", "Strict automated rules"],
    ),
    (
        "How do you usually unlock your phone?",
        ["PIN only", "Fingerprint", "Face unlock", "Pattern"],
    ),
    (
        "Where do you charge your phone overnight?",
        ["Bedside", "Kitchen / living area", "Office desk", "Rarely overnight"],
    ),
    (
        "How often do you install app updates within a week of release?",
        ["Immediately", "Within a few days", "When reminded", "Rarely"],
    ),
    (
        "Do you use a password manager on your phone?",
        ["No", "Built-in OS vault", "Third-party app", "Hybrid / hardware key"],
    ),
    (
        "Which mobile OS do you primarily use?",
        ["iOS", "Android", "Both regularly", "Other / flip phone"],
    ),
    (
        "How do you handle notifications during sleep?",
        ["All on", "Only calls", "Scheduled summary", "Do not disturb always"],
    ),
    (
        "How often do you back up photos from your phone?",
        ["Never", "Monthly", "Weekly", "Continuous cloud sync"],
    ),
    (
        "Do you use mobile hotspot for laptop internet?",
        ["Never", "Rarely", "Weekly", "Daily"],
    ),
    (
        "Preferred map app for driving?",
        ["Apple Maps", "Google Maps", "Waze", "Built-in car system only"],
    ),
    (
        "How do you discover new apps?",
        ["App store charts", "Friend recommendations", "News / blogs", "Ads"],
    ),
    (
        "Do you use a smartwatch paired with your phone?",
        ["No", "Basic notifications", "Fitness tracking", "Deep integration"],
    ),
    (
        "How concerned are you about app privacy permissions?",
        ["Not very", "Somewhat", "Very — I read prompts", "I use tracker blockers"],
    ),
    (
        "How often do you restart or power-cycle your phone?",
        ["Almost never", "Monthly", "Weekly", "When it misbehaves"],
    ),
    (
        "Do you use voice assistants (Siri / Google) daily?",
        ["Never", "Rarely", "A few times a week", "Multiple times daily"],
    ),
    (
        "How do you pay in stores most often?",
        ["Physical card", "Phone NFC wallet", "QR code apps", "Cash"],
    ),
    (
        "What drains your battery fastest?",
        ["Video calls", "Games", "GPS navigation", "Background sync / hotspot"],
    ),
    (
        "How many messaging apps do you actively check daily?",
        ["1", "2–3", "4–5", "6+"],
    ),
]


def build_survey(index: int, rng: random.Random) -> dict:
    picks = rng.sample(QUESTION_BANK, k=5)
    return {
        "survey_id": f"phone-usage-{index:03d}",
        "topic": "Smartphone usage habits",
        "version": 1,
        "questions": [
            {"id": j + 1, "prompt": q, "options": opts}
            for j, (q, opts) in enumerate(picks)
        ],
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(1, 101):
        path = OUT / f"survey-{i:03d}.json"
        rng = random.Random(42_000 + i)
        data = build_survey(i, rng)
        raw = json.dumps(data, separators=(",", ":"))
        if len(raw) > 1900:
            raise SystemExit(f"Survey {i} too long for API content cap: {len(raw)}")
        path.write_text(raw + "\n", encoding="utf-8")
    print(f"Wrote 100 surveys to {OUT}")


if __name__ == "__main__":
    main()
