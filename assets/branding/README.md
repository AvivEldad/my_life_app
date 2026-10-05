# LifeForge logo

`lifeforge-logo.png` is the full-resolution master for the app launcher icons.
Created with the built-in image generation tool.

Design prompt: Design a refined, production-ready app launcher logo for LifeForge, a personal self-improvement app for taking action, building habits, and making steady progress. Single bold geometric emblem: three ascending steps smoothly integrated into an upward arrow, expressing a path of daily progress. Warm amber gold #FFC107 with a subtle orange-gold gradient, on an opaque full-bleed deep charcoal #121212 square background. Confident, calm, purposeful, clean minimal graphic design. Strong simple silhouette readable at 32 pixels. Emblem centered within the middle 60 percent of the canvas so it remains fully visible in circular app icon masks. Balanced negative space, crisp edges, mostly flat treatment. No text, no letters, no characters, no ball, no checkmark, no decorative sparkles, no mockup, no external frame, no rounded outer canvas corners. Square image.

To regenerate the platform sizes from this master on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/update_app_icons.ps1
```

The script updates Android, iOS, macOS, Windows, and web launcher icons. Rebuild and install the app to see the new icon; hot reload does not update launcher resources.
