# MdViewer

A native, read-only Markdown viewer for macOS. It opens `.md`, `.markdown` and `.mdown`
files and renders them GitHub-style (tables, task lists, strikethrough, syntax-highlighted
code, light/dark mode) in a `WKWebView`. There is no editor.

## Features

- GitHub-flavored rendering: tables, task lists, strikethrough, raw HTML, heading anchors
- Syntax highlighting with bundled highlight.js (light and dark themes, offline)
- Outline sidebar: headings indented by level; click to scroll, current heading highlighted
  while scrolling; toggle with the toolbar button or ⌃⌘S
- Live reload: the view refreshes when the file changes on disk (including atomic saves
  from vim, VS Code, etc.) and keeps the scroll position
- Find in page: ⌘F opens the find bar, ⌘G / ⇧⌘G for next/previous, Esc closes it
- Relative images resolve next to the document; external links open in the default browser
- Math with KaTeX: `$inline$`, `$$display$$` and ```` ```math ```` blocks (prose like
  "costs $5 and $10" and anything inside code is left alone)
- Mermaid diagrams from ```` ```mermaid ```` blocks, following the theme and light/dark mode
- Themes (View > Theme): GitHub, Sepia, Academic (serif), High Contrast, each with light and
  dark variants; applied live to every window
- Zoom: ⌘+ / ⌘- / ⌘0, persisted
- Export as PDF… (⇧⌘E, paginated using the page setup's paper size) and Print… (⌘P)
- Quick Look: press Space on a Markdown file in Finder for a fully rendered preview
  (highlighting, math and diagrams included; GitHub theme following light/dark mode)

KaTeX and Mermaid are bundled and only loaded for documents that use them.

## Stack

- SwiftUI `DocumentGroup(viewing:)` with a read-only `FileDocument`
- [swift-markdown](https://github.com/swiftlang/swift-markdown) (cmark-gfm) for parsing,
  converted to HTML by a custom `MarkupVisitor`
- `WKWebView` with bundled [highlight.js](https://highlightjs.org) 11.11.1,
  [KaTeX](https://katex.org) 0.18.6 and [Mermaid](https://mermaid.js.org) 11.15.0
  (no network access at runtime), served from the app bundle through a custom
  `mdviewer-resource://` URL scheme handler

## Architecture

Three targets: the `MdViewer` app, the `MdViewerQuickLook` preview extension (embedded in
the app) and the `MdViewerCore` framework they share. The framework holds Domain,
Application, Ports, Adapters and the web assets, so both targets use one copy of the
rendering code and of the ~4 MB of JavaScript and fonts.

```
MdViewer/
  App/          Composition root (app target)
  Domain/       (MdViewerCore) MarkdownDocument, Heading, RenderedDocument, Slugifier,
                TableOfContents, ReaderTheme, PageZoom
  Application/  RenderDocument and WatchDocument use cases
  Ports/        MarkdownRenderer, FileWatcher, DocumentReader protocols
  Adapters/     SwiftMarkdownRenderer, HTMLPageTemplate, DispatchSourceFileWatcher,
                FileSystemDocumentReader, MathPreprocessor, PageSettingsScript,
                WebResourceLocator, BundleResourceSchemeHandler
  UI/           (app target) Document (MarkdownFile), Containers, Presentational views,
                Commands, Web (web view, printing)
  Resources/    Info.plist, assets (app); Web/ (MdViewerCore: CSS themes, viewer.js,
                highlight.js, KaTeX, Mermaid)
MdViewerQuickLook/  Quick Look preview extension (view-based, WKWebView)
MdViewerTests/  Swift Testing tests
Samples/        sample.md exercising every feature
```

Domain and Application do not import SwiftUI or WebKit.

## Requirements

- Xcode 27 / Swift 6.4
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46+

## Generate, build, test

`project.yml` is the source of truth; the generated `MdViewer.xcodeproj` is git-ignored.

```sh
xcodegen generate
xcodebuild -scheme MdViewer -destination 'platform=macOS' build
xcodebuild -scheme MdViewer -destination 'platform=macOS' test
```

Open `Samples/sample.md` with the built app to see every feature.

## Notes

- **App Sandbox is disabled** for now so the web view can load images referenced
  relative to the document (a sandboxed document app only gets access to the file itself,
  not its folder). Re-enabling it will require security-scoped folder access.
- The app is registered as a `Viewer` with `Alternate` handler rank, so it will not
  take over `.md` files from your editor.
- **Signing**: Debug builds are signed with the local "Apple Development" identity (team
  `736592UQPM` in `project.yml`), because pluginkit only loads the Quick Look extension
  with a real team signature. Without that certificate, build with
  `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=` (the app works; the extension will not load).
- **Quick Look**: the extension registers when the app is launched once. It is sandboxed
  (`app-sandbox`, `files.user-selected.read-only`, and `network.client`, which WebKit's
  web content process needs even for local pages; nothing is fetched from the network).
  Relative images next to the file do not load in the preview, since the sandbox only
  grants access to the previewed file. Check registration with
  `pluginkit -mAvvv -p com.apple.quicklook.preview | grep -i mdviewer` and try it with
  `qlmanage -p Samples/sample.md`.
- Debug builds honor `MDVIEWER_SCROLL_TO=<heading-slug>` and `MDVIEWER_EXPORT_PDF=<path>`
  environment variables for scripted checks, e.g.
  `open -a MdViewer.app --env MDVIEWER_EXPORT_PDF=/tmp/out.pdf Samples/sample.md`.

## Distribution

`scripts/release.sh` archives a Release build, exports it with Developer ID, notarizes
and staples it, and writes `build/MdViewer-<version>.zip` and `build/MdViewer-<version>.dmg`
(the dmg is signed, notarized and stapled too).

Requirements:

- A paid [Apple Developer Program](https://developer.apple.com/programs/) membership.
- A **Developer ID Application** certificate in the login keychain (Xcode > Settings >
  Accounts > Manage Certificates). The script stops right away if none is found.
- A notarytool keychain profile, created once:

  ```sh
  xcrun notarytool store-credentials MdViewerNotary \
    --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
  ```

Then:

```sh
NOTARY_PROFILE=MdViewerNotary ./scripts/release.sh
```

`TEAM_ID` can be set to override the team taken from the Developer ID certificate.
