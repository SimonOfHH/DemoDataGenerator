# Demo Data Generator for Business Central

A code generator that reads live Business Central tables and produces complete AL extensions following Microsoft's **Contoso Coffee Demo Dataset** architecture. Configure your tables, tweak field behaviors, hit Generate — and download a ready-to-compile `.al` extension that plugs directly into the Contoso framework.

## Why?

Setting up demo data or consistent initialization data in Business Central is painful:

- Good demo prep takes a lot of time
- Data gets stale, inconsistent, or breaks across versions
- Everyone reinvents the wheel
- Copying production data into demos creates compliance risk

Microsoft's Contoso Coffee Demo Dataset introduced a clean, code-based pattern for demo data — but writing those modules by hand is tedious and repetitive. This tool automates the boilerplate so you can focus on what matters: the data itself.

## What It Generates

For each module you configure, the generator produces a complete AL extension containing:

| Generated Object | Purpose |
|---|---|
| **app.json** | Manifest with auto-detected dependencies |
| **Module Codeunit** | Implements `"Contoso Demo Data Module"` interface |
| **Enum Extension** | Extends `"Contoso Demo Data Module"` enum (Enum 5160) |
| **Helper Codeunits** | One per helper group — contain `Insert*` procedures with the `Get / Validate / Insert\|Modify` pattern |
| **Data Codeunits** | One per table — contain `OnRun` triggers that call helper Insert procedures with literal values from your live data |
| **Copilot Review Prompt** | `.github/prompts/review-generated-code.prompt.md` — a GitHub Copilot agent prompt bundled in the ZIP that guides you through reviewing and polishing the auto-generated code |

The generated code follows the exact same patterns used in Microsoft's own Contoso modules (`ContosoBank`, `ContosoCustomerVendor`, etc.).

## Features

### Module Configuration

- Define modules with name, publisher, ID ranges, app identity, and namespace
- Declare Contoso module dependencies (Foundation, Finance, CRM, Bank, etc.)
- Auto-generated App ID on creation

### Table Selection

- Select any BC table via lookup
- Auto-populate field configurations from table metadata
- Auto-detect primary key fields
- Assign data levels: Setup Data, Master Data, Transaction Data, Historical Data
- Group tables by helper codeunit (e.g., all bank-related tables share one "Contoso Bank" helper)
- Customizable helper and data codeunit names (with 30-char limit awareness)
- **Table filtering** — use **Apply Filter** to open a `FilterPageBuilder` dialog for any selected table, define field filters interactively, and save the resulting view. The saved filter is applied at generation time so the generated data codeunit only inserts the matching subset of records. Use **Clear Filter** to remove a saved filter, and **Open Table with Filter** to browse the table with the saved filter pre-applied for verification.

### Field Behaviors

Each field can be configured with one of the following behaviors:

| Behavior | What It Does |
|---|---|
| **Include** | Generates the field value as an inline AL literal |
| **Label Field** | Creates a global `Label` constant and uses the label variable in the Insert call |
| **Dynamic Field** | Generates a placeholder procedure that returns a default value — intended to be replaced by the developer |
| **Procedure with Token-Label** | Generates an accessor procedure backed by a `Label` variable — useful for values that should be translatable |
| **Reference Value** | Generates a helper procedure that returns a cross-table reference value by table/field ID. **Note:** When the referenced table contains more records than are actually referenced, the generator falls back to the first available reference value. Review the generated getter calls to ensure they map to the correct values for your scenario. |
| **Exclude** | Skips the field entirely (default for FlowFields, Blobs, MediaSets, system fields, obsoleted fields) |

Additionally, Text and Code fields can be marked as **Locked Label**, which adds `Locked = true` to the generated Label declaration — preventing the value from being translated.

### Date Handling

- **Relative to WorkDate** — calculates the day offset from the current WorkDate and generates `CalcDate('<+5D>', WorkDate())` expressions, keeping demo data relevant regardless of when it's generated
- **Replace Year with WorkDate-Year** — keeps day and month, replaces the year with the current WorkDate year
- **Replace Month and Year** — keeps only the day, replaces month and year from WorkDate
- **Replace with WorkDate** — substitutes the date entirely with `WorkDate()`

### DateFormula Fields

DateFormula fields are automatically detected and wrapped in an `EvaluateDateFormula()` helper procedure in the generated code, since AL does not allow direct DateFormula literal assignment.

### Dependency Management

- Auto-detects app dependencies from field Source App IDs
- Resolves installed app metadata (name, publisher, version) automatically
- Supports an "Apps to Exclude" list to skip dependencies on apps you don't want to reference
- Always includes the Contoso Coffee Demo Dataset as a mandatory dependency

### Export / Import

- Export module definitions (including all table selections and field configurations) to JSON
- Import previously exported modules into other environments
- Automatic cleanup on import: removes tables/fields that don't exist in the target environment

### Sample Module

A ready-made sample module definition is included in the [`.sample/`](.sample/) folder:

| File | Description |
|---|---|
| [`.sample/CONTOSO-BANK.json`](.sample/CONTOSO-BANK.json) | Mirrors the standard **Contoso Bank** module — covers Bank Account Posting Groups, Bank Export/Import Setup, Payment Methods, Bank Accounts, Gen. Journal Batches, and Payment Registration Setup. Useful as a starting point or to verify that your environment produces output matching the official Contoso Bank pattern. |

To use it: open the **Demo Data Modules** list page → **Import** → select the JSON file.

### Code Generation Details

- Generates properly indented, formatted AL code
- Handles name sanitization (special characters, PascalCase conversion, 30-char object name limits with smart abbreviation)
- Supports AL namespaces throughout (configurable base namespace, auto-derived sub-namespaces for Helpers and DemoData)
- Organizes data codeunits into data-level folders (1.Setup Data, 2.Master Data, 3.Transactions, 4.Historical)
- Pre-generation validation with detailed error info (missing names, invalid ranges, unconfigured tables)
- Post-generation validation (object count vs. ID range capacity)
- Preview ID allocation before generating
- Downloads the complete extension as a structured ZIP file
- Bundles a **Copilot review prompt** (`.github/prompts/review-generated-code.prompt.md`) in the ZIP — open the extracted folder in VS Code and invoke the prompt via GitHub Copilot Chat to get guided, context-aware feedback on labels, naming, Contoso helper usage, sensitive data, and more

## Requirements

- Business Central **27.0** or later (runtime 16.0)
- Target: Cloud (SaaS)
- The Contoso Coffee Demo Dataset must be available in the target environment where the **generated** extension will be installed (it is *not* needed at generation time)

## Installation

1. Download the latest `.app` file from Releases (or compile from source)
2. Upload and install in your Business Central environment
3. Search for **"Demo Data Modules"** to open the main list page

## Usage

1. **Create a Module** — open the Module Definition Card, fill in Name, Publisher, ID Range, and Enum Ordinal
2. **Add Tables** — use the "Add Tables" action to select BC tables you want to generate demo data for
3. **Configure Fields** — click into each table's field configuration to set behaviors (Include, Label Field, Dynamic Field, etc.)
4. **Set Data Levels** — assign each table to Setup Data, Master Data, Transaction Data, or Historical Data
5. **Preview** — use "Preview ID Allocation" to verify object IDs fit your range
6. **Generate** — click "Generate & Download" to produce and download the ZIP

The downloaded ZIP contains a complete, compilable AL extension ready to be opened in VS Code.

<!-- TODO: Add screenshots here -->

## Architecture

```
src/
├── Model/          # Persistent tables and enums (Module Definition, Table Selection, Field Configuration)
├── UI/             # Pages (cards, lists, subpages, lookups)
├── CodeGen/        # In-memory AST model (codeunit, procedure, variable, enum extension nodes)
├── Generator/      # Code generators (Helper, Data, Module, Enum Extension, App Manifest)
├── Core/           # AL formatting, code templates, identifier utilities
└── Export/         # Export orchestrator, ZIP assembly, JSON export/import
```

The generation pipeline:

1. **Model** — user configures module, tables, and fields via the UI
2. **Generators** — read live BC data via `RecordRef` and build an in-memory AST using CodeGen nodes
3. **CodeGen nodes** — serialize themselves to AL source code via `ToString()` methods
4. **Export Orchestrator** — validates, assembles all generated code into a folder-structured ZIP, and triggers download

## Known Limitations

- **Guid default values** — the formatter currently outputs Guid defaults as single-quoted strings rather than proper AL Guid literals
- **Reference Field validation** — the Reference Table ID / Reference Field ID fields on Field Configuration lack cross-field validation (the AL language doesn't support this kind of table relation natively)
- **No integration events** — the codebase doesn't expose events for extensibility yet
- **Transaction / Historical data levels** — these data levels are not yet supported by the generator. Tables assigned to Transaction Data or Historical Data will have skeleton `Create*Data` procedures generated, but the actual data generation logic is not implemented yet. This is a fundamentally different problem than Setup/Master data and will require a different approach.

## Roadmap

<!-- Add planned improvements and features here -->

- [x] **Record filtering** — Allow optional table filters (e.g. "Customer where Country = DE") so users can generate targeted subsets instead of full table dumps
- [ ] **Data preview / dry run** — Show a summary page before export (tables, record counts, codeunit count, estimated LOC) so users can verify scope before downloading
- [ ] **Multi-module batch export** — "Generate All" action on the Module Definition List that assembles all modules into a single ZIP
- [ ] **Media / MediaSet field support** — Handle image and blob fields via Base64 export and a corresponding import helper pattern
- [ ] **Test codeunit generation** — Auto-generate a basic test codeunit per module that installs the demo data and asserts key records exist
- [ ] **Transaction Data / Historical Data level support** — Extend generation to cover the remaining Contoso data levels
- [ ] **Record count / LOC warnings** — Flag tables with very high record counts that would produce unreasonably large codeunits, and suggest filtering or splitting
- [ ] Integration events for generator extensibility
- [ ] Reference Field validation UI (lookup for Field ID filtered by Reference Table ID)

## Contributing

Contributions are welcome! Please open an issue to discuss larger changes before submitting a PR.

## License

<!-- TODO: Choose and add a license (e.g., MIT) -->

---

*This README was written with the help of AI.*
