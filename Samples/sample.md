# MdViewer Sample

A document exercising every supported feature. Jump to [Tables](#tables) or [Code](#code-blocks).

## Inline formatting

Text with *emphasis*, **strong**, ***both***, ~~strikethrough~~, and `inline code`.
Characters that need escaping: 5 < 6 & "quotes" > 'apostrophes'.

This line ends with a hard break\
and this one continues after it. This is a soft
break inside the same paragraph.

## Links and images

- External: [Swift.org](https://swift.org "The Swift website")
- Autolink: <https://github.com/swiftlang/swift-markdown>
- Anchor: [back to top](#mdviewer-sample)

Relative image next to the document:

![MdViewer logo](images/logo.svg)

## Block quotes

> Markdown is intended to be as easy-to-read and easy-to-write as is feasible.
>
> > Nested quotes work too.

## Lists

1. First
2. Second
   - Nested bullet
   - Another one
3. Third

Starting at five:

5. Five
6. Six

### Task list

- [x] Parse Markdown with swift-markdown
- [x] Render HTML in a WKWebView
- [ ] Add an outline sidebar

## Tables

| Feature        | Status | Priority |
| :------------- | :----: | -------: |
| Headings       |   ✅   |        1 |
| Tables         |   ✅   |        2 |
| Math           |   ❌   |       99 |

## Code blocks

```swift
struct Greeter {
    let name: String
    func greet() -> String { "Hello, \(name) <3" }
}
```

```json
{ "name": "MdViewer", "readOnly": true }
```

```
Plain fenced block without a language.
```

    Indented code block.

## HTML passthrough

<details>
<summary>Click to expand</summary>

Hidden content with <kbd>⌘</kbd> + <kbd>O</kbd> inline HTML.

</details>

---

## Duplicate heading

## Duplicate heading

The second heading above gets the slug `duplicate-heading-1`.
