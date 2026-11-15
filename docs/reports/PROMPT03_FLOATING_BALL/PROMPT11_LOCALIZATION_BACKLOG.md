# Prompt11 localization backlog

Targeted Prompt03B review only. These entries are review targets, not confirmed mistranslations. Keep edits scoped and ask native speakers to review in UI context.

| Locale / keys | Why review | Follow-up |
|---|---|---|
| German `photoPreview`, `videoAudioEffects`, `videoProject` | Existing strings mix English terms and German compounds (`Foto Preview`, `Video & Audio Effekte`, `Video Projekt`). | Native-speaker review for natural product terminology and consistent compounds. |
| Brazilian Portuguese `photoEditor`, `photoPreview` | Existing forms (`Fotografia Editor`, `Fotografia Previsão`) read mechanically and may not match common UI phrasing. | Review with a Brazilian Portuguese speaker in editor/preview context. |
| Arabic `floatingControlsPermissionGranted`, `floatingControlsPermissionRequired` | Permission explanations are long and include the notification’s “show controls in video” behavior. | Verify concise RTL rendering at 320 dp and ensure status/action meaning stays clear. |
| All locales `floatingControlsPermissionGranted`, `floatingControlsOpenHint`, `floatingControlsSettingsError` | These settings and accessibility messages are longer than nearby labels. | Check wrapping, screen-reader phrasing, and platform terminology in each locale. |
| All locales, app-wide | Prompt03B adjusted selected English sentence-case labels and a small set of library labels; this was not a whole-app copy audit. | Prompt11 should review remaining inconsistent terminology, awkward phrasing, and long labels by screen, with native-speaker review for non-English changes. |

No bulk translation rewrite was performed. The Prompt03B localization checker verified keys/placeholders/structure; it does not certify natural language quality.
