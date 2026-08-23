# 📄 OfficeFiles — The World's First Native Flutter DOCX Rendering Engine

<p align="center">
  <strong>Parse. Render. Pixel-Perfect.</strong><br/>
  A from-scratch Word document viewer engine built entirely in Flutter/Dart.<br/>
  No cloud. No conversion. No WebView. No PDF. Just raw XML parsing → native Flutter widgets.
</p>

---

## 🌟 What Is This?

**OfficeFiles** is a custom-built, offline `.docx` file rendering engine for Flutter that aims to display Microsoft Word documents **exactly as Microsoft Word renders them** — every margin, every font, every image, every table cell, every header, every footer, every bullet, every border, every color, every spacing value — reproduced pixel-for-pixel using native Flutter widgets.

This is **not** a wrapper around a PDF converter. This is **not** a WebView loading HTML. This is a **full Word rendering engine** written from scratch in Dart, parsing raw Office Open XML (OOXML) and building a Flutter widget tree that reproduces the exact visual layout Microsoft Word produces.

### Why Does This Exist?

Every existing Flutter "Word viewer" either:
- Converts `.docx` → PDF → displays the PDF (lossy, requires a server or heavy native library)
- Sends the file to a cloud API (requires internet, privacy concerns)
- Uses a WebView to render HTML (inconsistent, slow, not native)
- Extracts plain text only (loses all formatting)

**None of them actually render the Word document natively in Flutter.**

OfficeFiles changes that. It reads the `.docx` ZIP archive, parses every XML file inside it, builds an intermediate data model, resolves styles through the full inheritance chain, paginates the content into pages, and renders each page as a native Flutter widget tree — complete with precise A4 dimensions, exact margins, correct font sizes, inline and floating images, numbered/bulleted lists, tables with merged cells, headers, footers, and text effects.

---

## 🎯 Project Goals & Non-Negotiables

### What We ARE Doing
- ✅ Parsing the raw `.docx` XML ourselves (100% Dart-side)
- ✅ Building a Flutter widget tree that reproduces the exact visual layout Microsoft Word produces
- ✅ Targeting pixel-level fidelity: A4/Letter paper size, exact margins, exact font metrics, exact image positions, exact table cell sizes, headers, footers, page breaks, text effects, colors, borders — **everything**
- ✅ Working completely offline — no network requests, no cloud dependencies
- ✅ Supporting all major platforms: Android, iOS, Web, Windows, macOS, Linux

### What We Are NOT Doing
- ❌ Converting `.docx` to PDF and displaying the PDF
- ❌ Sending the file to any cloud API
- ❌ Using a WebView to render HTML
- ❌ Using any third-party Word rendering library
- ❌ Using `flutter_html` or any HTML-based approach
- ❌ Extracting plain text and displaying it in a `Text` widget

### The Standard
> **If you open the same `.docx` file in Microsoft Word and in OfficeFiles side by side, they should look identical.**

That is the bar. That is the goal. Every pixel matters.

---

## 📦 Understanding the .docx Format

A `.docx` file is **not** a single file — it is a **ZIP archive** containing multiple XML files, images, and relationship metadata. This is the Office Open XML (OOXML) standard, defined in [ECMA-376](https://www.ecma-international.org/publications-and-standards/standards/ecma-376/) and [ISO/IEC 29500](https://www.iso.org/standard/71691.html).

### Inside a .docx ZIP Archive

When you unzip a `.docx` file, you find this structure:

```
mydocument.docx (ZIP archive)
├── [Content_Types].xml              ← MIME types for all parts
├── _rels/
│   └── .rels                        ← Top-level relationships
├── word/
│   ├── document.xml                 ← 🔴 MAIN BODY — all paragraphs, runs, tables, images
│   ├── styles.xml                   ← 🟡 Named styles (Normal, Heading1, Heading2, etc.)
│   ├── settings.xml                 ← Document-level settings (default tab stop, etc.)
│   ├── fontTable.xml                ← Font declarations
│   ├── theme/
│   │   └── theme1.xml               ← 🟡 Theme colors (dk1, dk2, lt1, lt2, accent1-6) & fonts
│   ├── numbering.xml                ← 🟡 List definitions (bullets, numbering formats)
│   ├── header1.xml                  ← Header content for section 1
│   ├── header2.xml                  ← Header content (first page, even page, etc.)
│   ├── footer1.xml                  ← Footer content for section 1
│   ├── footer2.xml                  ← Footer content (first page, even page, etc.)
│   ├── media/                       ← 🟢 Embedded images (PNG, JPEG, EMF, WMF, GIF)
│   │   ├── image1.png
│   │   ├── image2.jpeg
│   │   └── ...
│   ├── _rels/
│   │   └── document.xml.rels        ← 🟡 Relationships: rId → image/header/footer file paths
│   └── webSettings.xml
├── docProps/
│   ├── app.xml                      ← Application properties (Word version, etc.)
│   └── core.xml                     ← Dublin Core metadata (title, author, dates)
└── customXml/                       ← Custom XML data (optional)
```

### The Key Files We Parse

| File | Purpose | Priority |
|---|---|---|
| `word/document.xml` | **Main body content** — paragraphs, runs (text spans), tables, embedded images, section breaks | 🔴 Critical |
| `word/styles.xml` | All named style definitions (Normal, Heading1, etc.) with full formatting properties | 🟡 High |
| `word/theme/theme1.xml` | Theme color scheme (12 theme colors) and theme fonts (major/minor) | 🟡 High |
| `word/numbering.xml` | Abstract numbering definitions and concrete numbering instances for lists | 🟡 High |
| `word/_rels/document.xml.rels` | Relationship map: `rId1` → `media/image1.png`, `rId2` → `header1.xml`, etc. | 🟡 High |
| `word/header1.xml`, `footer1.xml` | Header/footer content (paragraphs, images, field codes for page numbers) | 🟢 Medium |
| `word/settings.xml` | Default tab stop width, compatibility settings, zoom level | 🟢 Medium |
| `word/fontTable.xml` | Font declarations and substitutions | 🔵 Low |
| `[Content_Types].xml` | MIME type registry for all parts | 🔵 Low |

---

## 📐 OOXML Unit Systems — The Foundation of Everything

Microsoft Word uses **four distinct unit systems** throughout its XML. Getting these conversions wrong means every dimension, every margin, every font size, every image, and every spacing value will be incorrect. This is the single most important thing to understand.

### Unit Reference Table

| Unit | Full Name | Relationship | Where Used |
|---|---|---|---|
| **DXA** | Twentieths of a Point (aka Twips) | **1440 DXA = 1 inch = 72 points** | Page size, margins, indentation, tab stops, spacing before/after, cell widths |
| **EMU** | English Metric Units | **914400 EMU = 1 inch = 72 points** | Image dimensions, drawing positions, inline/floating object sizes |
| **Half-points** | Half of a typographic point | **2 half-points = 1 point** | Font sizes (`<w:sz>` values) — `val="24"` means 12pt |
| **Twentieths of a point** | 1/20 of a typographic point | **20 twentieths = 1 point** | Line spacing (`<w:line>` values), character spacing |
| **Eighths of a point** | 1/8 of a typographic point | **8 eighths = 1 point** | Border widths (`<w:sz>` on borders) — `sz="4"` means 0.5pt |

### Conversion Formulas (to Screen Pixels at 96 DPI)

```
DXA → pixels:          px = dxa / 1440 × 96
EMU → pixels:          px = emu / 914400 × 96
Half-points → pt:      pt = halfPt / 2.0
Half-points → pixels:  px = halfPt / 2 × 96 / 72
Twentieths → pixels:   px = twentieths / 20 × 96 / 72
Eighths → pixels:      px = eighths / 8 × 96 / 72
Points → pixels:       px = pt × 96 / 72
```

### Common Values & What They Mean

| OOXML Value | Unit | Real-World Meaning |
|---|---|---|
| `pgSz w="11906" h="16838"` | DXA | A4 paper: 210mm × 297mm (8.27" × 11.69") |
| `pgSz w="12240" h="15840"` | DXA | US Letter: 8.5" × 11" |
| `pgMar top="1440"` | DXA | 1-inch top margin |
| `sz val="24"` | Half-points | 12pt font size |
| `sz val="22"` | Half-points | 11pt font size (Word's default for Calibri) |
| `spacing line="276"` | Twentieths of pt | 1.15× line spacing (Word's default) |
| `spacing line="240"` | Twentieths of pt | Single (1.0×) line spacing |
| `spacing line="360"` | Twentieths of pt | 1.5× line spacing |
| `spacing line="480"` | Twentieths of pt | Double (2.0×) line spacing |
| `spacing before="240"` | DXA | 12pt spacing before paragraph |
| `ind left="720"` | DXA | 0.5-inch left indent |
| `ind firstLine="720"` | DXA | 0.5-inch first-line indent |
| `cx="2743200"` (in drawing) | EMU | 3 inches (image width) |
| `defaultTabStop val="720"` | DXA | Default tab stop every 0.5 inches |

### A4 Page in Pixels (at 96 DPI)

```
Width:  11906 DXA / 1440 × 96 = 793.7 px
Height: 16838 DXA / 1440 × 96 = 1122.5 px

With 1-inch (1440 DXA) margins:
Content area width:  (11906 - 1440 - 1440) / 1440 × 96 = 601.1 px
Content area height: (16838 - 1440 - 1440) / 1440 × 96 = 930.5 px
```

---

## 🏗️ Architecture — Four-Layer Engine Design

The engine is organized into four strictly separated layers, plus a utilities layer:

```
┌─────────────────────────────────────────────────────────┐
│                    📱 UI LAYER                          │
│  ViewerScreen · FilePicker · InteractiveViewer          │
│  (Flutter widgets — user interaction & display host)    │
├─────────────────────────────────────────────────────────┤
│                  🎨 RENDERER LAYER                      │
│  DocumentRenderer · PageRenderer · ParagraphRenderer    │
│  RunRenderer · TableRenderer · ImageRenderer            │
│  ListRenderer · HeaderFooterRenderer · DrawingRenderer  │
│  PaginationEngine                                       │
│  (Flutter widgets — converts models to visual output)   │
├─────────────────────────────────────────────────────────┤
│                   🧱 MODEL LAYER                        │
│  DocumentModel · SectionModel · ParagraphModel          │
│  RunModel · TableModel · ImageModel · StyleModel        │
│  NumberingModel · HeaderFooterModel · ThemeModel         │
│  (Pure Dart — zero Flutter imports — serializable)      │
├─────────────────────────────────────────────────────────┤
│                   📄 PARSER LAYER                       │
│  DocxParser (orchestrator) · DocumentParser             │
│  StylesParser · NumberingParser · ThemeParser            │
│  RelationshipParser · HeaderFooterParser · SectionParser │
│  (Pure Dart — reads ZIP archive, parses XML → models)   │
├─────────────────────────────────────────────────────────┤
│                   🔧 UTILS LAYER                        │
│  UnitConverter · ColorResolver · FontMapper             │
│  StyleResolver                                          │
│  (Shared utilities used by parsers & renderers)         │
└─────────────────────────────────────────────────────────┘
```

### Layer Rules
1. **Models** have **zero** Flutter dependencies — they are pure Dart data classes
2. **Parsers** only depend on models and utils — they produce models from XML
3. **Renderers** depend on models and utils — they consume models and produce Flutter widgets
4. **UI** depends on renderers and parsers — it orchestrates the flow
5. **Utils** are shared across all layers

---

## 📁 Project Structure

```
lib/
├── main.dart                              ← App entry point
├── screens/
│   └── viewer_screen.dart                 ← Main document viewer screen
├── widgets/
│   └── file_picker_widget.dart            ← Reusable file picker button
└── word_engine/
    ├── parser/
    │   ├── docx_parser.dart               ← 🎯 Orchestrator: unzips .docx, coordinates all parsers
    │   ├── document_parser.dart           ← Parses word/document.xml (paragraphs, runs, tables)
    │   ├── styles_parser.dart             ← Parses word/styles.xml (named style definitions)
    │   ├── numbering_parser.dart          ← Parses word/numbering.xml (list format definitions)
    │   ├── theme_parser.dart              ← Parses word/theme/theme1.xml (color scheme)
    │   ├── relationship_parser.dart       ← Parses _rels/document.xml.rels (rId → file path map)
    │   ├── header_footer_parser.dart      ← Parses headerN.xml / footerN.xml
    │   └── section_parser.dart            ← Extracts section properties (page size, margins)
    ├── model/
    │   ├── document_model.dart            ← Top-level document: sections + styles + numbering + theme
    │   ├── section_model.dart             ← Section: page dimensions, margins, header/footer refs, content blocks
    │   ├── paragraph_model.dart           ← Paragraph: alignment, spacing, indent, style ref, runs
    │   ├── run_model.dart                 ← Run: text content + character-level formatting (font, bold, color, etc.)
    │   ├── table_model.dart               ← Table → TableRow → TableCell (width, span, merge, borders, paragraphs)
    │   ├── image_model.dart               ← Embedded image: raw bytes, dimensions (EMU), wrap type, position
    │   ├── style_model.dart               ← Named style: type, basedOn chain, paragraph + run properties
    │   ├── numbering_model.dart           ← Numbering: abstract definitions, level formats, concrete instances
    │   ├── header_footer_model.dart       ← Header/footer: list of paragraphs
    │   └── theme_model.dart               ← Theme: color scheme map (dk1, lt1, accent1-6, etc.)
    ├── renderer/
    │   ├── document_renderer.dart         ← Root widget: iterates sections, lays out pages
    │   ├── page_renderer.dart             ← Single page: white A4 rectangle with margins, header, footer, content
    │   ├── paragraph_renderer.dart        ← Paragraph: RichText with TextSpan children, alignment, indent
    │   ├── run_renderer.dart              ← Text run: builds TextStyle with full formatting
    │   ├── table_renderer.dart            ← Table: cell grid with borders, shading, merged cells
    │   ├── list_renderer.dart             ← List items: bullet/number label + paragraph content
    │   ├── header_footer_renderer.dart    ← Header/footer: positioned at top/bottom of page
    │   ├── drawing_renderer.dart          ← Inline/floating images and drawings
    │   └── pagination_engine.dart         ← Splits content blocks across multiple pages
    └── utils/
        ├── unit_converter.dart            ← DXA↔px, EMU↔px, half-points↔pt, points↔px
        ├── color_resolver.dart            ← Hex colors, theme color lookup, tint/shade modifiers
        ├── font_mapper.dart               ← Maps Word fonts → cross-platform Flutter font families
        └── style_resolver.dart            ← Resolves effective style through basedOn inheritance chain
```

---

## 🔄 Complete Data Flow — From File Pick to Pixels

```
┌──────────────────┐
│  User picks file │
│  (.docx = ZIP)   │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│              DocxParser.parse()                   │
│  ┌─────────────────────────────────────────────┐ │
│  │  ZipDecoder().decodeBytes(fileBytes)         │ │
│  │  → Archive of XML files + media binaries     │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  ┌─── Parse in Order ──────────────────────────┐ │
│  │  1. RelationshipParser → Map<rId, path>     │ │
│  │  2. ThemeParser → ThemeModel (color scheme)  │ │
│  │  3. StylesParser → Map<styleId, StyleModel>  │ │
│  │  4. NumberingParser → NumberingParseResult    │ │
│  │  5. HeaderFooterParser → HeaderFooterModels  │ │
│  │  6. DocumentParser → SectionModel + blocks   │ │
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  Output: DocumentModel (complete document tree)   │
└────────┬─────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│          StyleResolver.resolve()                  │
│                                                   │
│  For each run in each paragraph:                  │
│    Direct run rPr (highest priority)              │
│      ↓ falls through to                           │
│    Character style (rStyle)                       │
│      ↓ falls through to                           │
│    Paragraph's default rPr (pPr/rPr)              │
│      ↓ falls through to                           │
│    Paragraph style (pStyle → styles.xml)          │
│      ↓ falls through to                           │
│    basedOn chain (Heading1 → Normal → defaults)   │
│      ↓ falls through to                           │
│    Document default style                         │
│                                                   │
│  Output: EffectiveStyle per run                   │
└────────┬─────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│       PaginationEngine.paginate()                 │
│                                                   │
│  Input: List<blocks> + SectionModel               │
│                                                   │
│  Algorithm:                                       │
│    - Track currentY on current page               │
│    - Estimate each block's height                 │
│    - When block would overflow → start new page   │
│    - Respect keepWithNext, keepLines,              │
│      pageBreakBefore                              │
│                                                   │
│  Output: List<PageContent> (blocks per page)      │
└────────┬─────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────┐
│          Flutter Widget Tree                      │
│                                                   │
│  DocumentRenderer                                 │
│    └─ Column of pages                             │
│        └─ PageRenderer (per page)                 │
│            ├─ Container (white, A4, shadow)        │
│            └─ Stack                               │
│                ├─ Header (Positioned top)          │
│                ├─ Content (Positioned margins)     │
│                │   └─ Column                      │
│                │       ├─ ParagraphRenderer        │
│                │       │   └─ RichText             │
│                │       │       └─ TextSpan(s)      │
│                │       ├─ ListRenderer             │
│                │       │   └─ Row [label, content] │
│                │       ├─ TableRenderer            │
│                │       │   └─ Table widget          │
│                │       └─ ImageRenderer            │
│                │           └─ Image.memory          │
│                └─ Footer (Positioned bottom)       │
└──────────────────────────────────────────────────┘
```

---

## 🔍 OOXML Parsing Deep Dive

### How We Parse Each XML Element

#### Paragraphs (`<w:p>`)

A paragraph is the primary block-level element. Every piece of text in a Word document lives inside a paragraph.

```xml
<w:p>
  <w:pPr>                                          <!-- Paragraph Properties -->
    <w:pStyle w:val="Heading1"/>                    <!-- Style reference -->
    <w:jc w:val="center"/>                          <!-- Alignment: left|center|right|both(justify)|distribute -->
    <w:spacing w:before="240"                       <!-- Space before paragraph (DXA) -->
               w:after="120"                        <!-- Space after paragraph (DXA) -->
               w:line="276"                         <!-- Line spacing value (twentieths of pt) -->
               w:lineRule="auto"/>                  <!-- Line rule: auto|exact|atLeast -->
    <w:ind w:left="720"                             <!-- Left indent (DXA) -->
           w:right="0"                              <!-- Right indent (DXA) -->
           w:firstLine="720"/>                      <!-- First-line indent (DXA); negative = hanging -->
    <w:numPr>                                       <!-- Numbering (list) reference -->
      <w:ilvl w:val="0"/>                           <!-- Indent level (0-8) -->
      <w:numId w:val="1"/>                          <!-- Numbering instance ID -->
    </w:numPr>
    <w:keepNext/>                                   <!-- Keep with next paragraph (same page) -->
    <w:keepLines/>                                  <!-- Keep all lines together (no page break within) -->
    <w:pageBreakBefore/>                            <!-- Force page break before this paragraph -->
    <w:shd w:val="clear" w:fill="FFFF00"/>          <!-- Paragraph background shading -->
    <w:pBdr>                                        <!-- Paragraph borders -->
      <w:top w:val="single" w:sz="4" w:color="000000"/>
      <w:bottom w:val="single" w:sz="4" w:color="000000"/>
      <w:left w:val="single" w:sz="4" w:color="000000"/>
      <w:right w:val="single" w:sz="4" w:color="000000"/>
    </w:pBdr>
    <w:tabs>                                        <!-- Custom tab stops -->
      <w:tab w:val="left" w:pos="2880"/>            <!-- 2 inches from left margin -->
      <w:tab w:val="center" w:pos="4680"/>
      <w:tab w:val="right" w:pos="9360"/>
    </w:tabs>
    <w:rPr>...</w:rPr>                              <!-- Default run properties for this paragraph -->
  </w:pPr>
  <w:r>...</w:r>                                    <!-- Run 1 -->
  <w:r>...</w:r>                                    <!-- Run 2 -->
  <w:hyperlink r:id="rId2">                         <!-- Hyperlink wrapping runs -->
    <w:r>...</w:r>
  </w:hyperlink>
  <w:bookmarkStart w:id="0" w:name="section1"/>     <!-- Bookmark -->
</w:p>
```

#### Runs (`<w:r>`)

A run is a contiguous span of text with uniform character formatting. When formatting changes mid-paragraph, a new run begins.

```xml
<w:r>
  <w:rPr>                                           <!-- Run Properties (character formatting) -->
    <w:rStyle w:val="Strong"/>                      <!-- Character style reference -->
    <w:rFonts w:ascii="Calibri"                     <!-- Font for ASCII characters -->
              w:hAnsi="Calibri"                     <!-- Font for high-ANSI characters -->
              w:cs="Arial"/>                        <!-- Font for complex scripts (Arabic, etc.) -->
    <w:sz w:val="28"/>                              <!-- Font size: 28 half-points = 14pt -->
    <w:szCs w:val="28"/>                            <!-- Font size for complex scripts -->
    <w:b/>                                          <!-- Bold (presence = true) -->
    <w:bCs/>                                        <!-- Bold for complex scripts -->
    <w:i/>                                          <!-- Italic -->
    <w:u w:val="single"/>                           <!-- Underline: single|double|dotted|dash|wave|none -->
    <w:strike/>                                     <!-- Strikethrough -->
    <w:dstrike/>                                    <!-- Double strikethrough -->
    <w:color w:val="FF0000"/>                       <!-- Text color (hex RGB) -->
    <w:color w:themeColor="accent1" w:themeTint="BF"/> <!-- Theme-based color -->
    <w:highlight w:val="yellow"/>                   <!-- Highlight color (named color) -->
    <w:shd w:val="clear" w:fill="FFFF00"/>          <!-- Run background/shading -->
    <w:vertAlign w:val="superscript"/>              <!-- Vertical alignment: superscript|subscript -->
    <w:caps/>                                       <!-- Display as ALL CAPS -->
    <w:smallCaps/>                                  <!-- Display as Small Caps -->
    <w:spacing w:val="20"/>                         <!-- Character spacing (twentieths of pt) -->
    <w:kern w:val="24"/>                            <!-- Kerning threshold (half-points) -->
    <w:lang w:val="en-US"/>                         <!-- Language tag -->
    <w:shadow/>                                     <!-- Text shadow effect -->
    <w:outline/>                                    <!-- Outline text effect -->
    <w:emboss/>                                     <!-- Emboss text effect -->
    <w:engrave/>                                    <!-- Engrave text effect -->
  </w:rPr>
  <w:t xml:space="preserve">Hello World </w:t>     <!-- Text content -->
  <w:tab/>                                          <!-- Tab character -->
  <w:br/>                                           <!-- Line break (no type = soft break) -->
  <w:br w:type="page"/>                             <!-- Page break -->
  <w:br w:type="column"/>                           <!-- Column break -->
  <w:sym w:font="Wingdings" w:char="F0E0"/>         <!-- Symbol character -->
  <w:drawing>...</w:drawing>                        <!-- Inline/floating image -->
</w:r>
```

> **⚠️ CRITICAL — Boolean Toggle Properties:**
> 
> For elements like `<w:b/>`, `<w:i/>`, `<w:strike/>`, etc.:
> - **Element present with no `val` attribute** → `true` (bold IS on)
> - **Element present with `val="0"` or `val="false"`** → `false` (explicitly NOT bold)
> - **Element absent** → `null` (inherit from style chain)
> 
> This is a **three-state boolean** (true / false / inherit). Getting this wrong means bold text becomes un-bold, or normal text becomes bold. Most implementations get this wrong.

#### Tables (`<w:tbl>`)

```xml
<w:tbl>
  <w:tblPr>                                         <!-- Table Properties -->
    <w:tblStyle w:val="TableGrid"/>                 <!-- Table style reference -->
    <w:tblW w:w="9360" w:type="dxa"/>               <!-- Total table width -->
    <w:jc w:val="center"/>                          <!-- Table alignment on page -->
    <w:tblInd w:w="0" w:type="dxa"/>                <!-- Table indentation from margin -->
    <w:tblBorders>                                  <!-- Table-level borders -->
      <w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:left w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:right w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="000000"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="000000"/>
    </w:tblBorders>
    <w:tblCellMar>                                  <!-- Default cell margins -->
      <w:top w:w="0" w:type="dxa"/>
      <w:left w:w="108" w:type="dxa"/>              <!-- 108 DXA ≈ 0.075 inches -->
      <w:bottom w:w="0" w:type="dxa"/>
      <w:right w:w="108" w:type="dxa"/>
    </w:tblCellMar>
  </w:tblPr>
  <w:tblGrid>                                       <!-- Column width definitions -->
    <w:gridCol w:w="2340"/>                          <!-- Column 1 width (DXA) -->
    <w:gridCol w:w="2340"/>                          <!-- Column 2 width (DXA) -->
    <w:gridCol w:w="4680"/>                          <!-- Column 3 width (DXA) -->
  </w:tblGrid>
  <w:tr>                                             <!-- Table Row -->
    <w:trPr>
      <w:trHeight w:val="567" w:hRule="exact"/>      <!-- Row height (DXA), rule: auto|exact|atLeast -->
      <w:tblHeader/>                                 <!-- Repeat this row as header on each page -->
      <w:cantSplit/>                                 <!-- Don't split this row across pages -->
    </w:trPr>
    <w:tc>                                           <!-- Table Cell -->
      <w:tcPr>
        <w:tcW w:w="2340" w:type="dxa"/>             <!-- Cell width -->
        <w:gridSpan w:val="2"/>                      <!-- Horizontal merge: spans 2 columns -->
        <w:vMerge w:val="restart"/>                  <!-- Vertical merge START -->
        <w:vMerge/>                                  <!-- Vertical merge CONTINUE (no val = continue) -->
        <w:tcBorders>...</w:tcBorders>               <!-- Cell-level border overrides -->
        <w:shd w:val="clear" w:fill="D9E1F2"/>       <!-- Cell background color -->
        <w:vAlign w:val="center"/>                   <!-- Vertical alignment: top|center|bottom -->
        <w:tcMar>...</w:tcMar>                       <!-- Cell-level margin overrides -->
        <w:textDirection w:val="tbRl"/>              <!-- Rotated text direction -->
      </w:tcPr>
      <w:p>...</w:p>                                 <!-- Cell content = paragraphs -->
      <w:p>...</w:p>
    </w:tc>
  </w:tr>
</w:tbl>
```

#### Images / Drawings (`<w:drawing>`)

```xml
<w:drawing>
  <!-- INLINE image — flows with text like a character -->
  <wp:inline distT="0" distB="0" distL="0" distR="0">
    <wp:extent cx="2743200" cy="1828800"/>           <!-- Size in EMU (3" × 2") -->
    <wp:docPr id="1" name="Picture 1"/>
    <a:graphic>
      <a:graphicData uri="...drawingml/2006/picture">
        <pic:pic>
          <pic:blipFill>
            <a:blip r:embed="rId5"/>                 <!-- rId → relationship → image file path -->
          </pic:blipFill>
          <pic:spPr>
            <a:xfrm>
              <a:ext cx="2743200" cy="1828800"/>     <!-- Display size in EMU -->
            </a:xfrm>
          </pic:spPr>
        </pic:pic>
      </a:graphicData>
    </a:graphic>
  </wp:inline>

  <!-- FLOATING / ANCHORED image — positioned relative to page/column/paragraph -->
  <wp:anchor behindDoc="0" locked="0" layoutInCell="1" allowOverlap="0"
             simplePos="0" relativeHeight="251659264"
             distT="114300" distB="114300" distL="114300" distR="114300">
    <wp:positionH relativeFrom="column">
      <wp:align>center</wp:align>                    <!-- Or: <wp:posOffset>EMU</wp:posOffset> -->
    </wp:positionH>
    <wp:positionV relativeFrom="paragraph">
      <wp:posOffset>0</wp:posOffset>
    </wp:positionV>
    <wp:extent cx="2743200" cy="1828800"/>
    <wp:wrapSquare wrapText="bothSides"/>            <!-- Text wrap: square, tight, through, topAndBottom, none -->
    <!-- ... graphic data same as inline ... -->
  </wp:anchor>
</w:drawing>
```

#### Section Properties (`<w:sectPr>`)

```xml
<w:sectPr>
  <w:pgSz w:w="11906" w:h="16838"/>                 <!-- Page size (A4) -->
  <w:pgMar w:top="1440" w:right="1440"              <!-- Margins (DXA) -->
           w:bottom="1440" w:left="1440"
           w:header="709" w:footer="709"             <!-- Header/footer distances from edge -->
           w:gutter="0"/>                            <!-- Gutter margin (for binding) -->
  <w:headerReference w:type="default" r:id="rId1"/>  <!-- Default header (all pages) -->
  <w:headerReference w:type="first" r:id="rId2"/>    <!-- First page header -->
  <w:headerReference w:type="even" r:id="rId3"/>     <!-- Even page header -->
  <w:footerReference w:type="default" r:id="rId4"/>
  <w:titlePg/>                                       <!-- Enable different first page header/footer -->
  <w:cols w:space="708"/>                            <!-- Multi-column layout spacing -->
</w:sectPr>
```

#### Field Codes (Page Numbers, Dates)

```xml
<!-- These appear in headers/footers for page numbers, total pages, dates, etc. -->
<w:r><w:fldChar w:fldCharType="begin"/></w:r>        <!-- Field start -->
<w:r><w:instrText> PAGE </w:instrText></w:r>          <!-- Field instruction -->
<w:r><w:fldChar w:fldCharType="separate"/></w:r>      <!-- Separator -->
<w:r><w:t>1</w:t></w:r>                              <!-- Cached/display value -->
<w:r><w:fldChar w:fldCharType="end"/></w:r>           <!-- Field end -->
```

---

## 🎨 Critical Rendering Challenges & Solutions

These are the exact situations where most Word viewers break. Each one is a hard problem with a specific solution.

### 1. Font Kerning & Letter Spacing Collapse

**Problem:** Word uses Windows system fonts (Calibri, Times New Roman, Arial) which have different metrics than the cross-platform fallbacks (Roboto, etc.). When substituting fonts, text that fits on one line in Word wraps to two lines in Flutter because the fallback font is slightly wider.

**Solution:**
- Apply font-specific letter-spacing compensation (e.g., Calibri → Roboto needs ~2% tighter tracking)
- Force `textScaleFactor: 1.0` on all `RichText` widgets to override system font scaling
- Wrap the document viewer in `MediaQuery` with `textScaleFactor: 1.0`

### 2. Paragraph Spacing Collapse (Not Additive!)

**Problem:** Most implementations set `padding` on each paragraph equal to its `spacingBefore` + `spacingAfter`. This **doubles the gap** because paragraph A's `spacingAfter` and paragraph B's `spacingBefore` both get rendered.

**The actual Word rule:** Word collapses spacing between adjacent paragraphs — it uses the **maximum** of (A's spacingAfter, B's spacingBefore), not the sum.

```
Spacing between A and B = max(A.spacingAfter, B.spacingBefore)
```

**Exception:** If `contextualSpacing` is set on a paragraph AND the adjacent paragraph has the same style, spacing is completely suppressed (0px gap).

### 3. Numbered List Alignment

**Problem:** Numbers `1.` through `9.` are narrower than `10.` through `99.`. Naïve implementations using `Row([Text("1."), Text("content")])` cause the text column to shift rightward at item 10.

**The actual Word model:** Each numbering level defines:
- `ind left="720"` — where the text content starts (measured from margin)
- `ind hanging="360"` — how far the number label hangs LEFT of the text start

The number label occupies a **fixed-width box** of exactly `hanging` DXA pixels, right-aligned within that box. This means `1.` and `10.` both end at the same horizontal position, and the text always starts at `left`.

### 4. Line Spacing — Three Different Rules

| Rule | Meaning | Calculation |
|---|---|---|
| `auto` | Proportional to font size | `height = lineValue / 240 × 1.2` (multiplier) |
| `exact` | Fixed height (may clip tall text) | `height = lineValue / 20 × 96/72` (absolute px) |
| `atLeast` | Minimum height (expands for tall text) | `height = max(exact_value, natural_height)` |

The `auto` default of `240` = single spacing (1.0×). `276` = 1.15× (Word's default). `480` = double spacing.

### 5. Style Inheritance Chain

Resolving the effective formatting for any piece of text requires walking a multi-level inheritance chain:

```
Priority (highest → lowest):
━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Direct run properties (<w:r><w:rPr>)     ← Explicit formatting on this run
2. Character style (<w:rStyle val="Strong">) ← Named character style
3. Paragraph default rPr (<w:pPr><w:rPr>)    ← Default run formatting for this paragraph
4. Paragraph style (<w:pStyle val="Heading1">) → its rPr from styles.xml
5. basedOn chain (Heading1 → Normal → document defaults)
6. Document default style ("Normal" or "Default Paragraph Font")
```

Each property is resolved independently — a run can have bold from the direct formatting, font size from the paragraph style, and color from the basedOn chain.

### 6. Three-State Boolean Properties

Properties like `bold`, `italic`, `strikethrough` have **three states**, not two:

| XML | Meaning | Value |
|---|---|---|
| `<w:b/>` | Bold is ON | `true` |
| `<w:b w:val="0"/>` | Bold is explicitly OFF | `false` |
| _(element absent)_ | Inherit from style chain | `null` |

Getting this wrong means styled headings lose their bold, or body text becomes randomly bold.

### 7. Image Rendering (Inline vs Floating)

| Type | XML Element | Behavior |
|---|---|---|
| **Inline** | `<wp:inline>` | Flows with text like a character — use `WidgetSpan` inside `RichText` |
| **Floating** | `<wp:anchor>` | Positioned relative to page/column/paragraph — use `Positioned` in page `Stack` |

Floating images have text wrap modes:
- `wrapSquare` — text wraps around bounding box
- `wrapTight` — text wraps tightly to shape
- `wrapTopAndBottom` — text above and below only
- `wrapNone` (behind/in front) — text flows through/under/over

### 8. Table Cell Merging

**Horizontal merge:** `<w:gridSpan w:val="2"/>` — cell spans 2 grid columns. The cell width = sum of spanned column widths.

**Vertical merge:**
- `<w:vMerge w:val="restart"/>` — starts a new vertical merge group
- `<w:vMerge/>` (no val) — continues the merge from the cell above
- The continuation cells render as empty (their content is hidden)

Flutter's `Table` widget does **not** natively support cell spanning. For complex tables, we use a `Stack` with absolutely-positioned cells computed from column widths and row heights.

### 9. Tab Stop Rendering

Tab stops are critical for header/footer alignment patterns like:

```
Company Name                    Document Title                    Page 1
[left-aligned]                  [center-aligned]                  [right-aligned]
```

This is achieved with three tab stops:
1. Left tab at 0 DXA
2. Center tab at 4680 DXA (page center)
3. Right tab at 9360 DXA (right margin)

Implementation requires splitting text at `<w:tab/>` characters and positioning each segment at its computed tab stop position.

### 10. Text Effects

| Word Effect | Implementation |
|---|---|
| `<w:shadow/>` | `TextStyle.shadows` with offset shadow |
| `<w:outline/>` | Stroke text with `CustomPainter` using `Paint()..style = PaintingStyle.stroke` |
| `<w:emboss/>` | Two shadows: light top-left + dark bottom-right |
| `<w:engrave/>` | Two shadows: dark top-left + light bottom-right |
| `<w:caps/>` | `text.toUpperCase()` |
| `<w:smallCaps/>` | `text.toUpperCase()` with `fontSize × 0.8` |
| Superscript | `fontSize × 0.65` with positive baseline shift via `WidgetSpan` + `Transform.translate` |
| Subscript | `fontSize × 0.65` with negative baseline shift |
| Double strikethrough | `CustomPainter` drawing two lines through text center |

---

## 📋 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  archive: ^3.4.10            # Unzip .docx (it's a ZIP archive)
  xml: ^6.5.0                 # Parse OOXML files
  file_picker: ^11.0.2        # Native file picker dialog
  path_provider: ^2.1.3       # Temp directory for file extraction
  google_fonts: ^6.2.1        # Cross-platform font loading (Roboto, Georgia, etc.)
  flutter_cache_manager: ^3.3.1 # Cache extracted assets
  cupertino_icons: ^1.0.8     # iOS-style icons
```

**Deliberately NOT included:**
- ❌ No `docx_to_pdf` — we don't convert
- ❌ No `webview_flutter` — we don't use WebView
- ❌ No `flutter_html` — we don't render HTML
- ❌ No cloud SDK — we don't upload files

---

## 🗺️ Implementation Roadmap

### Phase 1 — MVP (Show Basic Documents Correctly)

| Feature | Description | Status |
|---|---|---|
| ZIP extraction | Unzip `.docx`, read XML and binary files | ✅ Done |
| Relationship parsing | Map `rId` → file paths for images, headers, footers | ✅ Done |
| Theme parsing | Extract theme color scheme (dk1, lt1, accent1-6) | ✅ Done |
| Style parsing | Parse named styles with full property extraction | ✅ Done |
| Numbering parsing | Parse abstract/concrete numbering definitions | ✅ Done |
| Document parsing | Parse paragraphs, runs with all formatting properties | ✅ Done |
| Table parsing | Parse table structure, rows, cells, widths | ✅ Done |
| Unit conversion | DXA↔px, EMU↔px, half-points↔pt conversions | ✅ Done |
| Color resolution | Hex colors, theme colors, auto color, tint/shade | ✅ Done |
| Font mapping | Map Word fonts to cross-platform equivalents | ✅ Done |
| Style resolution | Resolve effective style through basedOn chain | ✅ Done |
| Page rendering | White A4 page with exact margins, shadow | ✅ Done |
| Paragraph rendering | RichText with alignment, indentation | ✅ Done |
| Run rendering | Full TextStyle: font, size, bold, italic, underline, color | ✅ Done |
| Line spacing | Auto / exact / atLeast line spacing rules | ✅ Done |
| Spacing collapse | Max(after, before) between adjacent paragraphs | ✅ Done |
| Font kerning compensation | Calibri → Roboto letter-spacing adjustment | ✅ Done |
| System text scale override | Force textScaleFactor: 1.0 | ✅ Done |
| Isolate parsing | Parse in background isolate (non-blocking UI) | ✅ Done |
| Interactive viewer | Pinch-to-zoom, pan, scroll | ✅ Done |
| **Numbered lists** | Decimal, bullet, letter, roman numeral lists | 🔧 In Progress |
| **Table rendering** | Wire tables into page renderer | 🔧 In Progress |
| **Image rendering** | Inline images via WidgetSpan | 🔧 In Progress |
| **Header/footer rendering** | Load and display header/footer XML | 🔧 In Progress |
| **Multi-page pagination** | Split content across pages at correct breakpoints | 🔧 In Progress |
| **First-line indent** | Apply first-line / hanging indent | 📋 Planned |
| **Paragraph borders** | Top/bottom/left/right borders with styles | 📋 Planned |
| **Paragraph shading** | Background color on paragraphs | 📋 Planned |

### Phase 2 — Full Fidelity

| Feature | Description |
|---|---|
| Floating images | Anchored images with text wrap (square, tight, topAndBottom) |
| Advanced tables | Cell merging (horizontal gridSpan + vertical vMerge), per-cell borders, cell shading |
| Custom tab stops | Left, center, right, decimal tab stops with leader characters (dots, dashes) |
| Text effects | Shadow, outline, emboss, engrave |
| Superscript/Subscript | Proper baseline shift with reduced font size |
| Small caps | Uppercase rendering with 80% font size |
| Double strikethrough | Two lines through text via CustomPainter |
| Symbol characters | Wingdings, Symbol font character rendering |
| Multi-column sections | Two/three column page layouts |
| Text boxes | `<w:textbox>` rendering as floating positioned content |
| Paragraph-level contextual spacing | Suppress spacing between same-style paragraphs |
| Field codes | Live page numbers, total pages, dates in headers/footers |

### Phase 3 — Polish & Power Features

| Feature | Description |
|---|---|
| Thumbnail generation | Generate page thumbnail previews |
| Text search | Search within rendered document |
| Text selection & copy | Select and copy text from rendered pages |
| Zoom controls | Zoom to fit, zoom to width, zoom to page buttons |
| Page navigator | "Page 2 of 5" indicator, page jump |
| Night/dark mode | Invert page colors for dark reading |
| Page snap scrolling | Snap to page boundaries while scrolling |
| Bookmarks & TOC | Navigate via bookmarks and table of contents |
| Print support | Print rendered pages |
| Performance optimization | Lazy rendering, viewport culling, caching |

### Not Planned (Known Limitations)

| Feature | Reason |
|---|---|
| EMF/WMF vector images | Complex legacy format — show placeholder |
| Complex scripts (Arabic/Hebrew RTL) | Requires BiDi layout engine — partial support only |
| SmartArt / Charts (`<c:chart>`) | Extremely complex rendering — show placeholder |
| Equation Editor (`<m:oMath>`) | Requires math layout engine — future consideration |
| Macros / VBA | Security risk, not relevant for viewing |
| Tracked changes (revision marks) | Display accepted version only |
| Watermarks (`<v:shape>` in header) | VML format — future consideration |
| Comments | Display clean version only |
| Exact font metrics (100% reflow fidelity) | Font substitution inherently changes metrics — close approximation only |

---

## 🧪 Testing Strategy

### Unit Tests (`test/word_engine/`)

| Test Category | What We Test |
|---|---|
| **Parser tests** | Feed raw XML strings → assert model output matches expected values |
| **Unit conversion** | DXA, EMU, half-point conversions against known values |
| **Color resolution** | Hex, theme, auto, tint/shade calculations |
| **Style resolution** | Multi-level inheritance chain resolution |
| **Numbering** | Counter state across paragraphs, level resets |

### Key Test Cases

1. Paragraph with all formatting options (bold, italic, underline, color, size, font)
2. Nested numbered lists (3 levels deep, mixed bullet/decimal)
3. Table with horizontally merged cells (`gridSpan`) and vertically merged cells (`vMerge`)
4. Inline image with known EMU dimensions → correct pixel output
5. Floating image with text wrap
6. Header with three tab stops (left / center / right alignment pattern)
7. Style inheritance chain: run → character style → paragraph rPr → paragraph style → basedOn → Normal
8. Page break forcing new page
9. Section break with different margins/page size
10. Spacing collapse between adjacent paragraphs
11. Three-state boolean: `<w:b/>` vs `<w:b w:val="0"/>` vs absent
12. `auto` color resolution (black for text, transparent for background)

---

## 🏃 How to Run

### Prerequisites
- Flutter SDK ^3.12.1
- Dart SDK ^3.12.1

### Setup
```bash
git clone <repository-url>
cd officefiles
flutter pub get
```

### Run
```bash
flutter run
```

### Usage
1. Launch the app
2. Tap the folder icon (📁) in the app bar
3. Pick any `.docx` file
4. The document renders as a paginated, zoomable view with pixel-accurate formatting

---

## 📖 References & Standards

| Resource | Description |
|---|---|
| [ECMA-376 Standard](https://www.ecma-international.org/publications-and-standards/standards/ecma-376/) | The official Office Open XML (OOXML) specification |
| [ISO/IEC 29500](https://www.iso.org/standard/71691.html) | ISO version of the OOXML standard |
| [Microsoft OOXML Documentation](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-oe376/) | Microsoft's implementation notes |
| [Open XML SDK Documentation](https://learn.microsoft.com/en-us/office/open-xml/open-xml-sdk) | Programmatic reference for OOXML structures |

---

## 🤝 Contributing

This is a hard, multi-sprint engineering project. If you want to contribute:

1. Read this README thoroughly — understand the OOXML format and our architecture
2. Look at the Phase roadmap and pick an unstarted feature
3. Write parser + model + renderer for that feature
4. Add unit tests
5. Submit a PR with before/after screenshots showing the rendering improvement

---

## 📄 License

This project is private and not published to pub.dev.

---

<p align="center">
  <em>Built with 💙 in Flutter — parsing XML so you don't have to.</em>
</p>
#   o f f i c e f i l e s  
 