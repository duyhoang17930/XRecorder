# Document App Component Style Audit and Transfer Plan

## Scope and reading rules

This is a static audit of `D:\Flutter\document_app`, focused on its app theme,
shared design-system widgets, and feature UI under `lib/src`. It checks the 16
component groups in the requested checklist. It does not treat a Flutter
Material default as a custom Document App definition.

Coverage labels:

- **Shared**: a reusable Document App widget or token defines the treatment.
- **Feature**: an app screen/editor defines a local treatment or uses a Material
  control with feature-specific values.
- **Partial**: a related pattern exists, but not the named reusable component.
- **Absent**: no app-owned implementation or style definition was found.

For transfer to xrecorder, reuse the measured geometry, surface treatment,
spacing, and interaction pattern. Resolve color and type through xrecorder's
existing `StudioColors` and Manrope tokens. Document App's blue palette and
SF Pro typography are recorded below as source values, not as a request to
replace xrecorder's semantic palette or typeface.

## Extracted design definitions

### Theme and visual foundation

Source of truth: `lib/design_system/src/theme/app_theme.dart`,
`office_app_colors.dart`, `app_gradients.dart`, and `document_colors.dart`.

| Token or rule | Document App definition |
|---|---|
| Brand/action blue | `#278BFA` (`AppTheme.blue` and `actionBlue`) |
| Light background gradient | `#EAF2FF` to `#EBF3FE`, with a card blend at stop `.48` |
| Dark background gradient | `#0D2138` to `#10233B`, with a card blend at stop `.48` |
| Light card/editor chrome | White |
| Dark card/editor chrome | `ColorScheme.surfaceContainer` |
| Accent border | Primary at 20% alpha light, 34% alpha dark |
| Shadow token | `#120B2447` light, `#33000000` dark |
| Type families | SF Pro Display for display/headline; SF Pro Text for body; NotoSans fallback |
| Type scale | Display 34/30/26 bold; headlines 34/28/24 bold; title 20 bold, 16 semibold; body 16 regular with 1.35 line height |
| Spacing | 4, 8, 12, 16, 24, 32dp |
| Corner radii | action 8, badge 12, thumbnail 8, menu 16, card 20, sheet 24, pill 999, button 14dp |
| General layout | 48dp minimum target; 600dp tablet breakpoint; 1200dp content max; 16dp page padding; 8dp bottom safe-area minimum |
| Editor chrome | Header min 56dp, ribbon min 72dp, icon sizes 20/24dp |
| Motion | press 120ms, ribbon 180ms, sheet 280/220ms, dialog 220/160ms; motion resolves to zero for reduced motion/accessibility navigation |
| Selection feedback | `HapticFeedback.selectionClick()` |

Document type accents are separate: Word `#2563EB`, Sheet `#16A34A`, Slide
`#F97316`, PDF `#DC2626`, Image `#7C3AED`; editor headers use slightly darker
light/dark variants. They should remain feature accents rather than replace the
app-wide action color.

### Components with explicit shared definitions

| Component family | Extracted definition |
|---|---|
| App surfaces/cards | `AppSurface`: card color, 20dp radius, divider border, themed shadow with 18dp blur and `(0, 8)` offset; default inner padding 16dp. Material `CardTheme` is flat, zero margin/elevation, white in light mode and `surfaceContainer` in dark mode. |
| Form fields | Filled; white fill in light mode and `surfaceContainerHighest` in dark mode. 14dp radius; no resting border; 1.5dp primary outline on focus. |
| Search field | 46dp normal / 36dp compact; 18dp / 14dp radius; 12dp / 10dp horizontal inset; accent border; blue-tinted shadow (`#183A9AEB`, blur 8, offset `(0,4)`); 18dp search glyph, 10dp icon/text gap, 15dp default input text. Clear button appears only with text. |
| App action sheet | Top radius 28dp; `surfaceContainer`; 40x3dp handle; safe-area bottom minimum 8dp; horizontal padding 22dp; scrollable; title 19dp bold; grouped inner surface radius 13dp; action row 52dp or 62dp with message; destructive actions get their own group and `#E64A55`. |
| Selection sheet | Same 28dp sheet and 40x3dp handle; centered 19dp bold title; inner group radius 13dp; 52dp rows; 1dp separators; selected check at 20dp in `#2588F8`. |
| Dialog | `AppDialog`: max width 480dp, max height 82% of viewport, 24dp horizontal/vertical inset, title padding 24dp, content 24dp horizontal + 16dp top, actions 24dp horizontal + 16dp vertical, scrollable content, transparent surface tint, clip anti-aliased. Shape falls back to the 20dp card radius. Filled action is `#278BFA`/white; disabled action uses `surfaceContainerHighest` and `onSurfaceVariant`. |
| Password dialog | Card radius 20dp; 16dp horizontal inset; content padding 16/20/16dp; title 20dp semibold; input 18dp semibold; 44dp buttons with 14dp radius; 12dp button gap; neutral cancel + blue submit. |
| Search interaction | Controller-driven clear action, search keyboard action, localized hint/tooltip, and submit support; home and templates reuse `AppSearchField`. |
| Press interaction | `AppPressable` uses InkWell plus 0.98 pressed scale over 120ms, with reduced-motion resolution. |
| Choice controls | Segmented control scrolls horizontally, has 48dp minimum height, no selected check icon, selected/idle fills from semantic chip tokens. Filter chips scroll horizontally with 8dp spacing and padded touch targets. |
| Editor actions | Editor toolbar action radius 8dp; 48dp minimum height (32dp icon-only, compact width 44dp); selected fill from editor selection color; disabled icon opacity `.4`; label 12dp; tooltip and semantics expose disabled reason/value. |
| Back action | 48x48dp target; 26dp chevron icon. |
| Navigation | Material navigation bar theme height 78dp; light background white at 94% opacity, dark background `surface`; selected indicator `primaryContainer`. Wide layout uses a scrollable `NavigationRail`. |
| Announcement/banner | Overlay card at safe top + app-bar height + 8dp; side insets 14dp; min height 64dp; radius 16dp; elevation 8; 38dp status icon tile; 14dp message; info/success/warning/error semantic accents; default timeout 4 seconds. |
| Empty/status state | Centered 48dp accent icon; 32dp outer padding; title uses `titleLarge`; centered message; optional action after 24dp. Loading uses a semantic circular progress indicator. Error/permission/offline/unsupported use distinct icons and localized text. |
| Badges | 12% accent fill; 12dp radius; 8dp padding; 24dp default icon; dark-mode accent blends 45% toward white. |
| App bar | White light / `surface` dark, zero elevation, transparent tint; title 22dp bold SF Pro Display; status/navigation bars follow theme brightness. |

### Important source limitation

`AppTheme` does **not** define global `FilledButtonTheme`, `OutlinedButtonTheme`,
`TextButtonTheme`, `IconButtonTheme`, `DialogTheme`, `BottomSheetTheme`, or
`PopupMenuTheme`. Most of these styles are inherited from Material 3 or supplied
locally by feature widgets. Treat the explicit values above as reusable
reference patterns; do not describe the source app as having one consistent
global value where it actually has local overrides.

Notable local variations to preserve as evidence:

- The app-shell create sheet and home filter sheet use 28dp top corners; the
  editor mode and color sheets use 30dp. The create sheet uses a 36x4dp handle;
  action and selection sheets use 40x3dp.
- Home filter actions are 46dp high with 12dp corners. Password dialog actions
  are 44dp high with 14dp corners.
- The Word editor has an intentionally separate bright-blue editor chrome,
  10dp radius, and a blue search toolbar. Its `wordPopupContent` overrides
  popup/dialog/sheet surfaces locally.
- App `PopupMenuButton` instances exist in Word editor tools, but there is no
  app-wide popup menu shape, elevation, padding, or item-height contract.

## Component-by-component audit

The notes below cover every item in the supplied checklist. An absent item may
still be approximated by a platform widget; it has no dedicated Document App
component style to extract.

### 1. Buttons and actions

Reference files: `app_dialog.dart`, `app_password_dialog.dart`,
`app_choice_controls.dart`, `app_shell.dart`,
`design_system/src/widgets/editor/editor_action_button.dart`.

- **Primary Button — Feature:** Material filled buttons appear throughout; blue
  `#278BFA`/white is explicit inside `AppDialog`, while other screens use
  `ColorScheme` or local colors. No shared primary-button wrapper/theme.
- **Secondary Button — Feature:** neutral filled treatment appears in password
  and filter UI; generally `surfaceContainerHighest` with `onSurfaceVariant`.
- **Outlined Button — Feature:** used locally; no global outlined style.
- **Text Button — Feature:** used locally; no global text-button style.
- **Icon Button — Feature:** local icon buttons plus shared 48dp `AppBackButton`
  and 48dp settings button.
- **Floating Action Button (FAB) — Feature:** app shell create button is 60dp
  circle, blue, white icon, elevation 6, center-docked.
- **Loading Button — Partial:** no button wrapper. Sheet action rows can show a
  22dp spinner and busy state.
- **Split Button — Absent:** no dedicated split-button widget.
- **Toggle Button — Partial:** `AppSegmentedTabs` covers segmented selection;
  no standalone boolean toggle-button style.
- **Button Group — Feature:** editor actions are grouped in toolbar structures;
  there is no generic shared button-group component.

### 2. Bottom sheets

Reference files: `app_action_sheet.dart`, `app_shell_actions.dart`,
`app_page_widgets.dart`, `editor_mode_picker.dart`, `editor_color_picker.dart`.

- **Modal Bottom Sheet — Feature:** used extensively; local builders choose
  background, safe area, drag handle, animation, and shape.
- **Persistent Bottom Sheet — Absent:** no app-owned persistent sheet treatment.
- **Draggable Bottom Sheet — Absent:** no `DraggableScrollableSheet` usage.
- **Scrollable Bottom Sheet — Shared/Feature:** action sheets scroll; editor
  mode sheets cap height at 85%; document menus cap at 80%.
- **Action Sheet — Shared:** use the `AppActionSheet` definition above; the
  app-shell Create sheet is a separate grid/card composition.
- **Selection Bottom Sheet — Shared:** `AppSelectionSheet` and
  `EditorModePicker` provide single-selection patterns.
- **Multi-Select Bottom Sheet — Partial:** file-selection and filter state exist;
  `AppFilterChips` is reusable, but there is no common multi-select sheet.
- **Searchable Bottom Sheet — Absent:** no shared sheet combines search with
  choice rows.
- **Confirmation Bottom Sheet — Absent as a dedicated component:** confirmation
  is usually a dialog; action sheets can separate destructive actions.
- **Full-Screen Bottom Sheet — Absent:** tall sheets are scroll-controlled but
  no full-screen sheet contract exists.

### 3. Dialogs and modals

Reference files: `app_dialog.dart`, `text_input_dialog.dart`,
`app_password_dialog.dart`, `editor_number_dialog.dart`,
`editor_color_picker.dart`, `pdf_word_progress_dialog.dart`.

- **Alert Dialog — Shared:** `AppDialog` is the central custom dialog shell.
- **Confirmation Dialog — Feature:** built with `AppDialog` and localized
  actions; button role/color is selected by the caller.
- **Destructive Dialog — Feature:** destructive confirmation appears locally;
  no shared destructive-dialog widget/token.
- **Custom Dialog — Shared:** `AppDialog`, with per-call padding, shape, colors,
  title, scroll, and actions overrides.
- **Input Dialog — Shared:** `TextInputDialog`, password, numeric, hex color,
  and feature-specific form dialogs.
- **Selection Dialog — Partial:** primary reusable selection surfaces are
  bottom sheets; specialized selection dialogs exist in features.
- **Loading Dialog — Feature:** PDF/Word conversion progress has a dedicated
  progress dialog, not a general loading-dialog primitive.
- **Full-Screen Dialog — Absent:** no shared full-screen dialog style.
- **Date/Time Dialog — Absent:** no app-owned date/time dialog implementation.
- **Bottom Dialog — Absent as a distinct component:** dialogs are centered;
  bottom-anchored modal UI is modeled as a sheet.

### 4. Menus and dropdowns

Reference files: `word_popup_theme.dart`, `word_more_menu.dart`,
`word_edit_toolbar.dart`, `word_insert_toolbar.dart`,
`word_print_panels.dart`, `pptx_ribbon.dart`.

- **Dropdown Menu — Feature:** `DropdownButton`/`DropdownButtonFormField` used
  in editor controls; no shared dropdown theme.
- **Popup Menu — Feature:** `PopupMenuButton` used in Word controls; Word popup
  wrapper uses the current `surface`, transparent tint, and on-surface text.
- **Context Menu — Feature:** document/editor selection menus are local editor
  UI; web editor has engine-specific context-menu behavior.
- **Overflow Menu — Feature:** Word “more” actions use a custom menu/sheet and
  blue/white Word chrome; no app-wide overflow widget.
- **Nested Menu — Absent:** no shared nested menu pattern.
- **Searchable Dropdown — Absent.**
- **Multi-Select Dropdown — Absent.**
- **Autocomplete Menu — Absent:** no Flutter autocomplete/search-anchor widget.
- **Cascading Menu — Absent.**
- **Command Menu — Absent as UI:** editor command dispatch exists, but no
  command-palette/menu component.

### 5. Inputs and forms

Reference files: `app_theme.dart`, `app_search_field.dart`,
`app_password_dialog.dart`, `text_input_dialog.dart`,
`editor_number_dialog.dart`, feature form dialogs.

- **Text Field — Theme:** filled surface, 14dp corners, no resting border,
  1.5dp primary focus border.
- **Text Area — Feature:** multi-line `TextField` use; inherits field theme
  unless locally overridden.
- **Password Field — Shared/Feature:** password dialog uses filled 14dp field,
  1dp local focus border, visibility toggle, 18dp semibold text.
- **Search Field — Shared:** `AppSearchField` dimensions, border, shadow, icons,
  and clear behavior are specified above.
- **Number Input — Feature:** numeric/decimal fields in `EditorNumberDialog`
  and PDF/Word flows; shared number dialog validates min/max.
- **OTP/PIN Input — Absent.**
- **Phone Input — Absent as a dedicated component.**
- **Email Input — Absent as a dedicated component.**
- **Checkbox — Feature:** Material checkboxes in spreadsheet/editor controls.
- **Radio Button — Absent from app-owned UI.**
- **Switch — Feature:** `SwitchListTile` in document tool options.
- **Slider — Feature:** Word drawing settings uses Material `Slider`.
- **Range Slider — Absent.**
- **Form Field — Theme/Feature:** theme supplies fill/border/focus; individual
  fields own labels, errors, keyboard types, and validation.
- **Form Validation — Feature:** inline error text and validators are local to
  each dialog/workflow; there is no global validation layout component.

### 6. Selection controls

Reference files: `app_choice_controls.dart`, `app_action_sheet.dart`,
`word_tool_groups.dart`, `editor_mode_picker.dart`.

- **Single Select — Shared:** `AppSelectionSheet`, `EditorModePicker`, and
  segmented control.
- **Multi Select — Partial:** home file-selection state and filter chips; no
  common multi-select dialog/sheet.
- **Segmented Control — Shared:** 48dp minimum height, horizontal scroll, no
  selected icon, selected/idle semantic fills.
- **Choice Chip — Feature:** Word editor tool groups use `ChoiceChip`.
- **Filter Chip — Shared:** horizontal scrolling, padded target, 8dp gap,
  semantic selected fill.
- **Input Chip — Absent.**
- **Selectable List Tile — Feature:** editor sheet rows use `ListTile.selected`
  and a selected check/accent.
- **Radio Group — Absent.**
- **Checkbox Group — Feature:** spreadsheet option groups use checkbox tiles;
  no shared checkbox-group widget.
- **Tag Selector — Partial:** filter chips cover the tag-like selection shape;
  no separate tag-selector component.

### 7. Navigation

Reference files: `app_theme.dart`, `app_shell.dart`,
`design_system/src/widgets/app_back_button.dart`, `word_page_indicator.dart`.

- **Bottom Navigation Bar — Shared/Feature:** 78dp themed M3 navigation surface;
  mobile app shell places a persistent 60dp create FAB at center dock.
- **Navigation Rail — Feature:** wide layout uses scrollable `NavigationRail`.
- **Navigation Drawer — Absent:** no drawer implementation.
- **App Bar — Theme/Feature:** white light / surface dark, no elevation/tint,
  22dp bold title; editor headers have local variants.
- **Sliver App Bar — Absent as an app-owned pattern.**
- **Tab Bar — Absent as Material `TabBar`.**
- **Scrollable Tabs — Partial:** horizontally scrolling segmented controls and
  editor ribbon groups provide related behavior.
- **Breadcrumbs — Absent.**
- **Stepper — Absent.**
- **Page Indicator — Feature:** Word/PPTX page or slide indicators use editor
  specific local treatments.
- **Back Button — Shared:** 48x48dp target, 26dp chevron, localized tooltip.
- **Navigation Menu — Feature:** Create sheet, document menus, and editor menus
  use local action destinations.

### 8. Cards and containers

Reference files: `app_surface.dart`, `app_theme.dart`, `app_page_widgets.dart`,
`home_document_widgets.dart`, `template_page_widgets.dart`.

- **Basic Card — Shared:** `AppSurface`, 20dp radius, divider border, themed
  soft shadow, 16dp default padding.
- **Outlined Card — Partial:** App surfaces add a divider border; no separate
  outlined-card widget.
- **Elevated Card — Partial:** `AppSurface` uses shadow; Material `CardTheme`
  itself stays at elevation zero.
- **Expandable Card — Absent as a reusable component.**
- **Action Card — Feature:** Create/tool cards use icon + label + subtitle,
  local accent colors and press affordance.
- **Selection Card — Feature:** home filter cards use selected `primaryContainer`
  fill, 1.5dp primary border, 12dp radius, 58dp height.
- **List Card — Feature:** file/recent/template cards compose local thumbnails,
  text, and action controls.
- **Image Card — Feature:** image/document thumbnails occur inside file cards;
  no generic image-card API.
- **Information Panel — Feature:** settings and conversion panels compose
  `AppSurface`/local cards.
- **Accordion — Absent.**
- **Expansion Tile — Absent:** no `ExpansionTile` use found.

### 9. Lists and data display

Reference files: `app_surface.dart`, `app_page_widgets.dart`,
`file_picker_page.dart`, `scan_review_page.dart`, spreadsheet engine controls.

- **List Tile Group — Feature:** selection/action sheets compose rows with
  1dp separators inside rounded 13/24dp groups.
- **Grouped List — Feature:** screens organize lists under local section
  headings; no group-list widget.
- **Section Header — Shared:** `AppSectionHeader` pairs title with optional
  action using `titleLarge`.
- **Grid View — Feature:** responsive home/tool/template grids use local
  breakpoints and card layouts.
- **Reorderable List — Feature:** scan pages and merge-order dialog use
  `ReorderableListView` with drag handles.
- **Swipeable List Item — Absent:** no `Dismissible` implementation.
- **Data Table — Feature:** spreadsheet editor renders its own grid; no Material
  `DataTable` style.
- **Key-Value Row — Feature:** document/detail/settings summaries are local rows.
- **Empty State — Shared:** 48dp primary icon, 32dp padding, title, centered
  message, optional action.
- **Infinite Scroll List — Partial:** large/recent lists are scrollable and
  some paginated/lazy; no common infinite-scroll component contract.
- **Pull-to-Refresh — Feature:** home recent documents uses Material
  `RefreshIndicator`.

### 10. Feedback and status

Reference files: `app_announcement_bar.dart`, `app_status_view.dart`,
`app_empty_state.dart`, `document_loading_overlay.dart`,
`tool_icon_badge.dart`, `document_type_badge.dart`.

- **Snackbar — Feature:** Material `SnackBar` used for a small set of actions;
  no app-specific `SnackBarTheme`.
- **Toast — Absent as an app-owned component.**
- **Banner — Shared:** `AppAnnouncementBar`, top overlay card with status
  icon/accent, 4-second default timeout and optional action.
- **Inline Alert — Shared/Feature:** `AppStatusView`/local status panels use
  distinct status icon, localized title/message, optional action.
- **Tooltip — Feature:** Material `Tooltip` appears on editor/icon actions; no
  custom tooltip theme.
- **Popover — Absent as a shared component.**
- **Progress Bar — Feature:** Material linear/circular progress indicators,
  sometimes with local labels/color/stroke width.
- **Circular Progress — Feature:** used for loading and busy states; a 22dp,
  2dp-stroke spinner appears in action rows.
- **Loading Overlay — Shared/Feature:** `DocumentLoadingOverlay` supplies a
  document/editor loading surface; other workflows compose local overlays.
- **Skeleton Loader — Absent.**
- **Badge — Shared:** 12dp radius, 12% accent background, 8dp padding; document
  and tool badges derive foreground from semantic accent.
- **Status Indicator — Shared:** `AppStatusView` maps loading/empty/offline/
  permission/unsupported/error to distinct icon and live-region text.
- **Error State — Shared/Feature:** status view and error/retry pages.
- **Success State — Feature:** conversion result and action completion screens;
  no generic success-state widget.

### 11. Pickers

Reference files: `editor_color_picker.dart`, `editor_number_dialog.dart`,
`document_color_picker.dart`, `presentation_shape_picker.dart`,
`tool_file_picker.dart`.

- **Date Picker — Absent:** no app-owned Material date picker usage.
- **Time Picker — Absent.**
- **Date Range Picker — Absent.**
- **Color Picker — Shared/Feature:** editor color picker uses a 30dp sheet,
  drag handle, responsive 6-column circular swatches (42–58dp), 14dp spacing,
  selected check, plus a hex input dialog.
- **File Picker — Feature/native:** `file_picker` plugin opens the platform
  picker; in-app document selection uses file cards and search.
- **Image Picker — Feature/native:** picker is injected into Word editor flows;
  there is no shared custom image-picker surface.
- **Wheel Picker — Absent.**
- **Number Picker — Feature:** numeric dialog and number fields; no wheel picker.
- **Duration Picker — Absent.**
- **Option Picker — Shared:** `AppSelectionSheet` and `EditorModePicker`, with
  52dp rows, separators, selected accent/check.

### 12. Media and visual

Reference files: `document_thumbnail_service.dart`, `file_picker_page.dart`,
`scan_crop_page.dart`, `presentation_shape_picker.dart`,
`word_media_actions.dart`.

- **Avatar — Absent.**
- **Avatar Group — Absent.**
- **Image Viewer — Feature:** document/PDF/image preview surfaces; no generic
  `ImageViewer` widget.
- **Image Carousel — Absent as a shared image carousel.**
- **Image Cropper — Feature:** scan crop screen has custom crop/gesture UI.
- **Video Player Controls — Absent as an app-owned player component.**
- **Audio Player Controls — Absent as an app-owned player component.**
- **Thumbnail — Feature:** document thumbnails are rendered by the thumbnail
  service and file-card components; radius token is 8dp.
- **Zoomable Image — Partial:** document viewers support their own zoom/gesture
  behavior; no reusable image zoom widget.
- **Media Preview — Feature:** file/document preview pages and scan review use
  editor-specific chrome, not a shared media-preview card.

### 13. Layout and structure

Reference files: `app_theme.dart`, `office_app_colors.dart`,
`app_surface.dart`, `app_shell.dart`.

- **Spacer — Feature:** standard 4/8/12/16/24/32dp spacing tokens.
- **Divider — Theme/Feature:** semantic outline/divider values; local lists use
  1dp separators with 35% outline-variant alpha.
- **Vertical Divider — Feature:** used beside desktop navigation rail.
- **Section Container — Shared:** `AppSurface` plus `AppSectionHeader`.
- **Responsive Grid — Feature:** 600dp tablet threshold; app content max 1200dp;
  feature grids select columns based on available width.
- **Wrap Layout — Feature:** pickers/chips use `Wrap` with explicit spacing.
- **Safe Area Container — Shared pattern:** sheets and page shell use `SafeArea`;
  minimum bottom inset 8dp.
- **Scrollable Container — Feature:** `ListView`, `SingleChildScrollView`, and
  sliver lists; sheets cap at local viewport fractions.
- **Sticky Header — Absent as a shared component.**
- **Collapsible Section — Absent as a shared component.**
- **Adaptive Scaffold — Feature:** mobile bottom navigation/FAB; wide layout
  switches to `NavigationRail`; content respects 600dp and 1200dp layout tokens.

### 14. Gestures and interactions

Reference files: `app_pressable.dart`, `app_motion.dart`,
`app_action_sheet.dart`, `scan_crop_page.dart`, reorderable lists.

- **Swipe Action — Absent:** no dismiss/swipe-action list row.
- **Drag Handle — Feature:** 40x3dp sheet handle; reorderable rows use drag
  handle glyphs.
- **Drag and Drop — Partial:** reorder lists and scan crop gestures exist; no
  general app drag/drop wrapper.
- **Long Press Menu — Feature/Partial:** editor selection/context behaviors are
  local; no shared long-press menu component.
- **Dismissible Item — Absent:** no `Dismissible` use.
- **Reorder Handle — Feature:** reorderable list rows show drag handle icon.
- **Pull-to-Refresh Indicator — Feature:** home uses `RefreshIndicator`.
- **Gesture Feedback — Shared:** `AppPressable` scales to .98 over 120ms and
  uses InkWell; reduced motion disables the animation.
- **Haptic Feedback Wrapper — Partial:** selection haptic helper exists in
  `AppMotion`; no generic wrapper for all gestures.

### 15. Search and filtering

Reference files: `app_search_field.dart`, `home_search_widgets.dart`,
`app_page_widgets.dart`, `home_page.dart`, `media_sort.dart`.

- **Search Bar — Shared:** `AppSearchField`, exact geometry above.
- **Search Suggestions — Partial:** home search displays matching document
  results; no separate suggestions dropdown component.
- **Search History — Absent as a dedicated feature/component.**
- **Filter Panel — Feature:** home `_FilterSheet` presents type cards.
- **Filter Bottom Sheet — Feature:** top radius 28dp; handle 52x4dp; 24dp
  horizontal inset; title 21dp bold; 2-column cards 58dp high; selected card
  uses primary-container fill/1.5dp primary border; actions 46dp high/12dp radius.
- **Sort Menu — Feature:** local sort choice UI; no shared sort menu component.
- **Filter Chips — Shared:** horizontal scroll; 8dp gap; selected semantic fill.
- **Search Result Item — Feature:** home result uses file/document card patterns.
- **Clear Filters Button — Feature:** reset action in filter sheet; no standalone
  global button wrapper.

### 16. Onboarding and utility

Reference files: `app_empty_state.dart`, `app_status_view.dart`,
`app_page_widgets.dart`, `document_handoff.dart`,
`design_system/src/widgets/editor/editor_header.dart`.

- **Onboarding Page — Absent:** splash screen exists, but no onboarding flow.
- **Feature Highlight — Absent.**
- **Coach Mark — Absent.**
- **Spotlight Overlay — Absent.**
- **Permission Prompt — Partial/native:** permission states are surfaced in app
  status/workflow UI; the OS owns the native permission prompt.
- **Empty Placeholder — Shared:** `AppEmptyState`, 48dp icon and centered copy.
- **Error Retry View — Shared/Feature:** `AppStatusView` accepts an action;
  error pages/workflows supply retry actions locally.
- **Keyboard Accessory Bar — Partial:** editor/search toolbars can sit adjacent
  to editing workflows, but there is no generic keyboard accessory component.
- **Copy-to-Clipboard Button — Partial:** editor utilities can copy content;
  no shared clipboard button style.
- **Share Action — Feature:** `DocumentHandoff` and platform share UI; no
  reusable share-button component.

## Transfer implementation plan for xrecorder

The first transfer pass already adds dialog/menu/search radius tokens, changes
form fields to the filled/no-resting-outline treatment, restyles the shared
search field, and documents the extracted component rules. Remaining work should
follow this order:

1. **Freeze semantic mapping.** Keep xrecorder's orange/teal, recording/error
   semantics, Manrope, and Light/Dark color extensions. Add only missing
   geometry tokens when a target component needs them.
2. **Normalize global Material controls.** Define explicit filled, outlined,
   text, icon, input, chip, menu, dialog, and sheet themes in xrecorder so
   feature pages inherit the same geometry and state colors.
3. **Normalize shared overlays.** Keep `showStudioBottomSheet`,
   `showStudioDialog`, `StudioDialog`, `StudioSheetHeader`; make their corner,
   handle, safe-area, scroll, and motion values the sole shared contract.
4. **Finish shared input/selection primitives.** Apply the search-field shape to
   all search uses; standardize dropdown/menu surfaces, chip/segmented states,
   checkbox/switch/slider focus and disabled states.
5. **Audit local overrides by feature.** Start with recording/setup and media,
   then editor dialogs/menus and settings. Replace one-off styling only where
   the inherited component can preserve layout and behavior.
6. **Keep absent component families out of scope until used.** The audit's
   Absent entries describe source coverage, not a requirement to add unused
   onboarding, avatar, date-picker, or menu variants to the recorder.
7. **Review the implemented result.** Compare Light/Dark, narrow/wide, and large
   text layouts against the extracted values; check that selected, disabled,
   error, destructive, loading, and focused states retain semantic contrast.

## Source files audited

- `lib/design_system/src/theme/app_theme.dart`
- `lib/design_system/src/theme/office_app_colors.dart`
- `lib/design_system/src/theme/app_motion.dart`
- `lib/design_system/src/theme/app_gradients.dart`
- `lib/design_system/src/theme/document_colors.dart`
- `lib/design_system/src/widgets/app_surface.dart`
- `lib/design_system/src/widgets/app_search_field.dart`
- `lib/design_system/src/widgets/app_action_sheet.dart`
- `lib/design_system/src/widgets/app_dialog.dart`
- `lib/design_system/src/widgets/app_password_dialog.dart`
- `lib/design_system/src/widgets/text_input_dialog.dart`
- `lib/design_system/src/widgets/app_choice_controls.dart`
- `lib/design_system/src/widgets/app_pressable.dart`
- `lib/design_system/src/widgets/app_announcement_bar.dart`
- `lib/design_system/src/widgets/app_status_view.dart`
- `lib/design_system/src/widgets/app_empty_state.dart`
- `lib/design_system/src/widgets/document_loading_overlay.dart`
- `lib/design_system/src/widgets/document_type_badge.dart`
- `lib/design_system/src/widgets/tool_icon_badge.dart`
- `lib/design_system/src/widgets/editor/editor_action_button.dart`
- `lib/design_system/src/widgets/editor/editor_mode_picker.dart`
- `lib/design_system/src/widgets/editor/editor_color_picker.dart`
- `lib/design_system/src/widgets/editor/editor_number_dialog.dart`
- Relevant app shell, home/filter, settings, file picker, scan, and Word/Office
  editor screens under `lib/src`.
