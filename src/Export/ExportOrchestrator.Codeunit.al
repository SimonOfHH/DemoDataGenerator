namespace SimonOfHH.DemoData.Export;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Generator;
using SimonOfHH.DemoData.Core;
using SimonOfHH.DemoData.Segments;

/// <summary>
/// Master entry point for code generation and download.
/// Validates the module, allocates object IDs, calls all generators,
/// assembles the output into a folder-structured zip, and triggers download.
/// </summary>
codeunit 70130 "Export Orchestrator"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        HelperGenerator: Codeunit "Helper Generator";
        DataGenerator: Codeunit "Data Generator";
        DocumentDataGenerator: Codeunit "Document Data Generator";
        ModuleGenerator: Codeunit "Module Generator";
        EnumExtGenerator: Codeunit "Enum Extension Generator";
        AppManifestGenerator: Codeunit "App Manifest Generator";
        ALFormatter: Codeunit "AL Formatter";
        ZipHelper: Codeunit "Zip Helper";
        SegmentSyncManager: Codeunit "Segment Sync Manager";
        SegmentFileAssembler: Codeunit "Segment File Assembler";
        CodeSegmentStore: Codeunit "Code Segment Store";

    /// <summary>
    /// Runs all generators (manifest, enum extension, module, helper, data) in the correct order
    /// and populates the ModuleContainer with the resulting AST nodes. Does not export.
    /// </summary>
    /// <param name="ModuleDef">The module definition whose tables and settings drive generation.</param>
    /// <param name="ModuleContainer">Receives all generated code objects; must be passed by reference as generators mutate its ID counters.</param>
    procedure GenerateModule(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container")
    begin
        ModuleContainer.Init(ModuleDef."ID Range Start");
        this.AppManifestGenerator.Generate(ModuleDef, ModuleContainer);
        this.EnumExtGenerator.Generate(ModuleDef, ModuleContainer);
        this.ModuleGenerator.Generate(ModuleDef, ModuleContainer);
        this.HelperGenerator.Generate(ModuleDef, ModuleContainer);
        this.DataGenerator.Generate(ModuleDef, ModuleContainer);
        this.DocumentDataGenerator.Generate(ModuleDef, ModuleContainer);
    end;

    /// <summary>
    /// Convenience overload that generates and exports (downloads) the module in one step.
    /// Equivalent to calling Run(ModuleDef, true, false).
    /// </summary>
    procedure Run(ModuleDef: Record "Module Definition")
    begin
        this.Run(ModuleDef, true, false);
    end;

    /// <summary>
    /// Equivalent to calling Run(ModuleDef, Export, false).
    /// </summary>
    procedure Run(ModuleDef: Record "Module Definition"; Export: Boolean)
    begin
        this.Run(ModuleDef, Export, false);
    end;

    /// <summary>
    /// Validates, generates, reconciles segments, and downloads the complete AL extension.
    /// </summary>
    /// <param name="ForceRegenerate">When true, every non-Locked segment is overwritten with the
    /// freshly generated text even if the developer had edited it, discarding those edits.</param>
    procedure Run(ModuleDef: Record "Module Definition"; Export: Boolean; ForceRegenerate: Boolean)
    var
        ModuleContainer: Codeunit "CodeGen Module Container";
    begin
        // 1. Validate
        this.PreGenerateValidateModule(ModuleDef);
        // 2. Generate codeunits and manifest
        this.GenerateModule(ModuleDef, ModuleContainer);
        // 3. Post-generation validation (e.g. ID range capacity)
        this.PostGenerateValidateModule(ModuleDef, ModuleContainer);

        // 4. Reconcile segments - runs regardless of Export, so callers can sync/force-regenerate
        // without downloading anything (see "Sync Segments" / "Force Regenerate (No Download)").
        if ForceRegenerate then
            this.CodeSegmentStore.ForceRegenerateAll(ModuleDef.Code);
        this.SegmentSyncManager.SyncFromContainer(ModuleDef, ModuleContainer);

        if not Export then
            exit;

        // 5. Assemble and download zip
        if not this.ConfirmConflictsIfAny(ModuleDef) then
            exit;

        this.AssembleZip(ModuleDef, ModuleContainer);

        // 6. Update status
        ModuleDef.Status := "Module Status"::Generated;
        ModuleDef.Modify(true);

        Message(GenerationCompleteMsg, ModuleDef.Name);
    end;

    /// <summary>
    /// Warns the developer before export if any segment is Modified or in Conflict, since export
    /// ships the MANUAL version of a conflicted segment, not the freshly generated one. Returns
    /// false if the developer cancels.
    /// </summary>
    local procedure ConfirmConflictsIfAny(ModuleDef: Record "Module Definition"): Boolean
    var
        ConflictCount: Integer;
        ModifiedCount: Integer;
        ConflictWarningQst: Label 'This module has %1 segment(s) in Conflict and %2 manually modified segment(s). Exporting will keep your manual edits and skip the freshly generated version for conflicted segments - review them first via the Code Segment list if unsure. Continue exporting?', Comment = '%1 = Conflict Count, %2 = Modified Count';
    begin
        ConflictCount := this.CodeSegmentStore.GetConflictCount(ModuleDef.Code);
        ModifiedCount := this.CodeSegmentStore.GetModifiedCount(ModuleDef.Code);
        if (ConflictCount = 0) and (ModifiedCount = 0) then
            exit(true);
        exit(Confirm(ConflictWarningQst, true, ConflictCount, ModifiedCount));
    end;

    local procedure PostGenerateValidateModule(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container")
    var
        UsedObjectCount: Integer;
        RangeCapacity: Integer;
    begin
        // Validate total fits in range
        UsedObjectCount := ModuleContainer.GetNextCodeunitId(false) - ModuleDef."ID Range Start";
        RangeCapacity := ModuleDef."ID Range End" - ModuleDef."ID Range Start" + 1;
        if UsedObjectCount > RangeCapacity then
            Error(TooManyObjectsErr, RangeCapacity);
    end;

    local procedure PreGenerateValidateModule(ModuleDef: Record "Module Definition")
    var
        TableSelection: Record "Table Selection";
        FieldConfig: Record "Field Configuration";
        DocumentGroup: Record "Document Group";
        DocumentGroupLink: Record "Document Group Link";
        ErrorInfoDetail: TextBuilder;
        ErrorInfoMsg: Label 'Module "%1" has validation errors which must be resolved before code generation can proceed. Please see details for more information.', Comment = '%1 = Module Name';
        ErrorInfoTitleLbl: Label 'Validation Errors';
        ValidationErrorInfo: ErrorInfo;
    begin
        if ModuleDef.Name = '' then
            ErrorInfoDetail.AppendLine(MissingNameErr);

        if ModuleDef."ID Range Start" = 0 then
            ErrorInfoDetail.AppendLine(MissingRangeErr);

        if ModuleDef."ID Range End" = 0 then
            ErrorInfoDetail.AppendLine(MissingRangeErr);

        if ModuleDef."ID Range Start" > ModuleDef."ID Range End" then
            ErrorInfoDetail.AppendLine(InvalidRangeErr);

        if ModuleDef."Enum Ordinal" = 0 then
            ErrorInfoDetail.AppendLine(MissingEnumOrdinalErr);

        if ModuleDef."Enum Value Name" = '' then
            ErrorInfoDetail.AppendLine(MissingEnumValueErr);

        if ModuleDef."Base Namespace" = '' then
            ErrorInfoDetail.AppendLine(MissingBaseNamespaceErr);

        // At least one table selected
        TableSelection.SetRange("Module Code", ModuleDef.Code);
        if TableSelection.IsEmpty() then
            ErrorInfoDetail.AppendLine(NoTablesSelectedErr);

        // Every table must have a Data Level assigned
        TableSelection.SetRange("Data Level", "Data Level"::" ");
        if not TableSelection.IsEmpty() then
            ErrorInfoDetail.AppendLine(MissingDataLevelErr);

        // Every table must have at least one non-excluded field
        TableSelection.SetRange("Data Level");
        if TableSelection.FindSet() then
            repeat
                if TableSelection."Helper Codeunit Name" = '' then
                    ErrorInfoDetail.AppendLine(StrSubstNo(MissingHelperCodeunitErr, TableSelection."Table Name"));
                if TableSelection."Data Codeunit Name" = '' then
                    ErrorInfoDetail.AppendLine(StrSubstNo(MissingDataCodeunitErr, TableSelection."Table Name"));
                FieldConfig.SetRange("Module Code", TableSelection."Module Code");
                FieldConfig.SetRange("Table ID", TableSelection."Table ID");
                FieldConfig.SetFilter(Behavior, '<>%1', FieldConfig.Behavior::Exclude);
                if FieldConfig.IsEmpty() then
                    ErrorInfoDetail.AppendLine(StrSubstNo(NoFieldsConfiguredErr, TableSelection."Table Name"));
            until TableSelection.Next() = 0;

        // Every Document Group must have exactly one Header table assigned
        DocumentGroup.SetRange("Module Code", ModuleDef.Code);
        if DocumentGroup.FindSet() then
            repeat
                if DocumentGroup.GetHeaderTableID() = 0 then
                    ErrorInfoDetail.AppendLine(StrSubstNo(MissingGroupHeaderErr, DocumentGroup.Code));
            until DocumentGroup.Next() = 0;

        // Every Line-role table must have at least one Document Group Link field mapping configured
        TableSelection.Reset();
        TableSelection.SetRange("Module Code", ModuleDef.Code);
        TableSelection.SetRange("Group Role", TableSelection."Group Role"::Line);
        if TableSelection.FindSet() then
            repeat
                DocumentGroupLink.SetRange("Module Code", TableSelection."Module Code");
                DocumentGroupLink.SetRange("Table ID", TableSelection."Table ID");
                if DocumentGroupLink.IsEmpty() then
                    ErrorInfoDetail.AppendLine(StrSubstNo(MissingGroupLinkErr, TableSelection."Table Name"));
            until TableSelection.Next() = 0;

        if ErrorInfoDetail.Length() > 0 then begin
            ValidationErrorInfo.Title := ErrorInfoTitleLbl;
            ValidationErrorInfo.Message := StrSubstNo(ErrorInfoMsg, ModuleDef.Name);
            ValidationErrorInfo.DetailedMessage := ErrorInfoDetail.ToText();
            Error(ValidationErrorInfo);
        end;
    end;

    /// <summary>
    /// Assembles the zip from the "Code Segment" store (populated by "Segment Sync Manager",
    /// which Run() calls before this) rather than directly from the AST's ToString() - this is
    /// what preserves any manual edits the developer made to a previously exported file.
    /// app.json and the JSON data snapshots are the only exceptions: they cannot carry AL
    /// comment markers, so they are always taken directly from the freshly generated AST/JSON.
    /// </summary>
    local procedure AssembleZip(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container")
    var
        DataFile: Codeunit "CodeGen Data File";
        ArtifactKey: Text;
        DataLevelFolder: Text;
        PublisherSafe, ModuleSafe : Text;
    begin
        PublisherSafe := this.ALFormatter.SanitizeIdentifier(ModuleDef.Publisher);
        ModuleSafe := this.ALFormatter.SanitizeIdentifier(ModuleDef.Name);

        this.ZipHelper.Initialize();

        // app.json — whole-file, always freshly generated (JSON cannot carry comment markers)
        this.ZipHelper.AddTextFile('app.json', ModuleContainer.GetManifestCodeunit().ToString());

        // Module codeunit (single file per module)
        ArtifactKey := ModuleContainer.GetModuleCodeunit().Name();
        if ArtifactKey <> '' then
            this.AddAssembledFile(ModuleDef.Code, "Code Artifact Kind"::"Module Codeunit", ArtifactKey);

        // Enum extension (single file per module)
        ArtifactKey := ModuleContainer.GetEnumExtension().Name();
        if ArtifactKey <> '' then
            this.AddAssembledFile(ModuleDef.Code, "Code Artifact Kind"::"Enum Extension", ArtifactKey);

        // Helper codeunits
        foreach ArtifactKey in this.SegmentFileAssembler.GetArtifactKeys(ModuleDef.Code, "Code Artifact Kind"::"Helper Codeunit") do
            this.AddAssembledFile(ModuleDef.Code, "Code Artifact Kind"::"Helper Codeunit", ArtifactKey);

        // Data codeunits (includes "Document Data Generator"'s stub codeunits) - each one's own
        // stored File Path already encodes its Data Level folder (set by "Segment Sync Manager")
        foreach ArtifactKey in this.SegmentFileAssembler.GetArtifactKeys(ModuleDef.Code, "Code Artifact Kind"::"Data Codeunit") do
            this.AddAssembledFile(ModuleDef.Code, "Code Artifact Kind"::"Data Codeunit", ArtifactKey);

        // Transaction/Historical JSON data snapshots — whole-file, always freshly generated
        foreach DataFile in ModuleContainer.GetDataFiles() do begin
            DataLevelFolder := this.GetDataLevelFolder(DataFile.DataLevel());
            this.ZipHelper.AddTextFile('src/' + DataLevelFolder + DataFile.FileName(), DataFile.Content());
        end;

        // Review & polish prompt for Copilot
        this.ZipHelper.AddTextFile('.github/prompts/review-generated-code.prompt.md', this.GetReviewPromptContent());

        // Transaction/Historical data generation prompt for Copilot (only relevant when such data was captured)
        if ModuleContainer.GetDataFiles().Count() > 0 then
            this.ZipHelper.AddTextFile('.github/prompts/generate-transaction-data.prompt.md', this.GetTransactionDataPromptContent());

        // Download
        this.ZipHelper.Download(PublisherSafe + '_' + ModuleSafe + '_' + ModuleDef."App Version" + '.zip');
    end;

    local procedure AddAssembledFile(ModuleCode: Code[20]; ArtifactKind: Enum "Code Artifact Kind"; ArtifactKey: Text)
    var
        ArtifactKeyTrunc: Text[100];
    begin
        ArtifactKeyTrunc := CopyStr(ArtifactKey, 1, MaxStrLen(ArtifactKeyTrunc));
        this.ZipHelper.AddTextFile(
            this.SegmentFileAssembler.GetFilePath(ModuleCode, ArtifactKind, ArtifactKeyTrunc),
            this.SegmentFileAssembler.AssembleFile(ModuleCode, ArtifactKind, ArtifactKeyTrunc));
    end;

    /// <summary>
    /// Maps a Data Level to the relative output folder used within the exported zip. Made
    /// internal (not local) so "Segment Sync Manager" and "Segment File Assembler" can compute
    /// the exact same "Code Segment"."File Path" without duplicating (and risking drift from)
    /// this mapping.
    /// </summary>
    internal procedure GetDataLevelFolder(DataLevel: Enum SimonOfHH.DemoData.Model."Data Level"): Text
    begin
        case DataLevel of
            "Data Level"::"Setup Data":
                exit('1.Setup Data/');
            "Data Level"::"Master Data":
                exit('2.Master Data/');
            "Data Level"::"Transaction Data":
                exit('3.Transactions/');
            "Data Level"::"Historical Data":
                exit('4.Historical/');
        end;
        exit('');
    end;

    local procedure GetReviewPromptContent(): Text
    var
        Content: TextBuilder;
    begin
        // YAML frontmatter
        Content.AppendLine('---');
        Content.AppendLine('agent: ''agent''');
        Content.AppendLine('description: ''Review and polish auto-generated Contoso Coffee Demo Data AL extension''');
        Content.AppendLine('---');
        Content.AppendLine('');
        // Title
        Content.AppendLine('# Review & Polish: Auto-Generated Contoso Demo Data Extension');
        Content.AppendLine('');
        Content.AppendLine('This AL extension was **fully auto-generated** by the [Demo Data Generator](https://github.com/SimonOfHH/DemoDataGenerator) tool for Microsoft Dynamics 365 Business Central. It reads live BC table data and produces AL codeunits following the **Contoso Coffee Demo Dataset** architecture.');
        Content.AppendLine('');
        Content.AppendLine('The structure is correct, but the generated code needs human review and polish before it is production-ready.');
        Content.AppendLine('');
        Content.AppendLine('---');
        Content.AppendLine('');
        // Framework references
        Content.AppendLine('## Framework References');
        Content.AppendLine('');
        Content.AppendLine('- **Contoso Repo**: https://github.com/microsoft/ALAppExtensions/tree/main/Apps/W1/ContosoCoffeeDemoDataset/app');
        Content.AppendLine('- **Coding Patterns**: https://github.com/microsoft/ALAppExtensions/blob/main/Apps/W1/ContosoCoffeeDemoDataset/app/Coding-Patterns.md');
        Content.AppendLine('- **Getting Started**: https://github.com/microsoft/ALAppExtensions/blob/main/Apps/W1/ContosoCoffeeDemoDataset/app/Getting-Started.md');
        Content.AppendLine('');
        Content.AppendLine('---');
        Content.AppendLine('');
        // Archive structure
        Content.AppendLine('## What Is In This Archive');
        Content.AppendLine('');
        Content.AppendLine('| File | Purpose |');
        Content.AppendLine('|---|---|');
        Content.AppendLine('| `app.json` | Manifest with auto-detected dependencies |');
        Content.AppendLine('| `src/<Name>Module.Codeunit.al` | Implements "Contoso Demo Data Module" interface |');
        Content.AppendLine('| `src/<Name>ModuleEnum.EnumExt.al` | Extends Enum 5160 "Contoso Demo Data Module" |');
        Content.AppendLine('| `src/Helpers/<Name>.Codeunit.al` | Insert* procedures - one per configured helper group |');
        Content.AppendLine('| `src/1.Setup Data/` | Data codeunits for Setup Data level |');
        Content.AppendLine('| `src/2.Master Data/` | Data codeunits for Master Data level |');
        Content.AppendLine('| `src/3.Transactions/` | Stub codeunits + `*.data.json` snapshots - see item 6 below |');
        Content.AppendLine('| `src/4.Historical Data/` | Stub codeunits + `*.data.json` snapshots - see item 6 below |');
        Content.AppendLine('');
        Content.AppendLine('---');
        Content.AppendLine('');
        // Marker comments - IMPORTANT: must survive review edits
        Content.AppendLine('## IMPORTANT: `// >>> DDG ...` / `// <<< DDG ...` Marker Comments');
        Content.AppendLine('');
        Content.AppendLine('Every `.al` file in this archive is wrapped, section by section, in paired comment lines that look like this:');
        Content.AppendLine('');
        Content.AppendLine('```al');
        Content.AppendLine('    // >>> DDG HELPER.BANK.INSERT.36');
        Content.AppendLine('    procedure InsertBankAccount(...)');
        Content.AppendLine('    ...');
        Content.AppendLine('    // <<< DDG HELPER.BANK.INSERT.36');
        Content.AppendLine('```');
        Content.AppendLine('');
        Content.AppendLine('These are NOT leftover debug output and should NOT be deleted or treated as noise to clean up. The Demo Data Generator tool uses them to track this code as a "segment" so that regenerating this module later (e.g. after adding a table, or refreshing the underlying data) can detect and preserve the edits made during this review instead of silently overwriting them.');
        Content.AppendLine('');
        Content.AppendLine('**When editing this code:**');
        Content.AppendLine('');
        Content.AppendLine('- Freely edit, rename, or rewrite the code BETWEEN a `// >>> DDG ...` line and its matching `// <<< DDG ...` line - that is exactly what these markers are for.');
        Content.AppendLine('- Leave the marker lines themselves in place, with their Segment ID text unchanged, and do not move a marker pair''s content across a file/procedure boundary.');
        Content.AppendLine('- It is fine to add brand-new code (e.g. a helper procedure) that is NOT between any marker pair - it will be picked up as a "manually added" block the next time this source is re-imported into the tool.');
        Content.AppendLine('- If a marker line is deleted or its Segment ID text is changed, that specific piece of code will no longer be recognized on re-import; it is not harmful, but that one edit will not be tracked for the incremental-regeneration workflow the next time this module changes.');
        Content.AppendLine('');
        Content.AppendLine('---');
        Content.AppendLine('');
        // Review checklist
        Content.AppendLine('## Review Checklist');
        Content.AppendLine('');
        // 1. Labels
        Content.AppendLine('### 1. Label Values - Make Human-Readable');
        Content.AppendLine('');
        Content.AppendLine('Labels are generated directly from raw database field values. A field containing the value `CUST-001` results in a label like `CUST001Lbl: Label ''CUST-001''`.');
        Content.AppendLine('');
        Content.AppendLine('**Actions:**');
        Content.AppendLine('');
        Content.AppendLine('- Replace technical label texts with human-readable equivalents where appropriate.');
        Content.AppendLine('- For Code/Key values (not meant for translation): use the `Tok` suffix and add `Locked = true`.');
        Content.AppendLine('- For display text: keep the `Lbl` suffix and make the text human-readable (e.g. "Sales Invoice" instead of "SALSINV").');
        Content.AppendLine('- Add `MaxLength =` on every Label declaration, matching the target field length.');
        Content.AppendLine('- Refer to the Coding Patterns document for the full Tok/Lbl naming convention.');
        Content.AppendLine('');
        // 2. Accessor procedure names + return types
        Content.AppendLine('### 2. Accessor Procedure Names - Use PascalCase and Correct Return Types');
        Content.AppendLine('');
        Content.AppendLine('Generated accessor procedures derive their names from raw database values. If the source data was in uppercase or contained underscores, the procedures may be named like `CUST_NO_001()` or `SALESPERSON_CODE()`. The generator also consistently returns `Text[n]` for all accessors, regardless of the target field type.');
        Content.AppendLine('');
        Content.AppendLine('**Actions:**');
        Content.AppendLine('');
        Content.AppendLine('- Rename all accessor procedures to PascalCase: `CustomerNo001()`, `SalespersonCode()`.');
        Content.AppendLine('- The procedure name should clearly describe what it returns.');
        Content.AppendLine('- Update all call sites when renaming.');
        Content.AppendLine('- Verify the return type matches the target field type: accessor procedures returning values for `Code[n]` fields must return `Code[n]`, not `Text[n]`.');
        Content.AppendLine('');
        // 3. Reference value getters
        Content.AppendLine('### 3. Reference Value Getters - Verify They Point to the Right Records');
        Content.AppendLine('');
        Content.AppendLine('For fields with "Reference Value" behavior, the generator creates getter procedures using `FindFirst()` on the referenced table. When the referenced table has more records than are actually used, the generator defaults to the first available record.');
        Content.AppendLine('');
        Content.AppendLine('**Actions:**');
        Content.AppendLine('');
        Content.AppendLine('- Open each reference getter procedure and verify the returned value is the record you intend to reference.');
        Content.AppendLine('- Adjust the lookup filter or hard-code the correct value where needed.');
        Content.AppendLine('');
        // 4. Existing Contoso helpers
        Content.AppendLine('### 4. Check for Existing Contoso Helper Codeunits');
        Content.AppendLine('');
        Content.AppendLine('Before keeping a generated custom Insert procedure, check whether the Contoso framework already provides an official helper codeunit for that table in `DemoTool/Contoso Helpers/` in the Contoso repository.');
        Content.AppendLine('');
        Content.AppendLine('Standard helpers include (not exhaustive):');
        Content.AppendLine('');
        Content.AppendLine('- **Contoso GL Account** - GL Accounts and Chart of Accounts');
        Content.AppendLine('- **Contoso Posting Group** - Gen./VAT Posting Groups');
        Content.AppendLine('- **Contoso Customer/Vendor** - Customers and Vendors');
        Content.AppendLine('- **Contoso Item** - Items, Item Variants, and related tables');
        Content.AppendLine('- **Contoso Bank** - Bank Accounts, Payment Methods');
        Content.AppendLine('- **Contoso Fixed Asset** - Fixed Assets and FA setup tables');
        Content.AppendLine('- **Contoso HR** - Employees and HR-related tables');
        Content.AppendLine('- **Contoso Manufacturing** - Production BOM, Routing, Work Centers');
        Content.AppendLine('- **Contoso Inventory** - Locations, Bins, Transfer Routes');
        Content.AppendLine('');
        Content.AppendLine('If an official helper exists for your table, replace the generated Insert call with the standard helper. This reduces code, ensures localization compatibility, and improves maintainability.');
        Content.AppendLine('');
        Content.AppendLine('If you keep a generated helper instead of the official one, **compare its parameter list against the official helper signature**. The generator captures only the fields it encounters in the snapshot — it may silently omit parameters that are present in the official helper. Missing parameters mean fields are left blank on inserted records without any compile error.');
        Content.AppendLine('');
        // 5. Duplicate primary key collisions
        Content.AppendLine('### 5. Check for Duplicate Primary Key Collisions');
        Content.AppendLine('');
        Content.AppendLine('The generator exports data rows independently per table. It cannot detect when multiple rows in the source data map to the same primary key in the target `Insert*` call. This commonly happens with journal batches (Template + Batch Name) and setup tables (single-record tables or user-keyed tables).');
        Content.AppendLine('');
        Content.AppendLine('**Actions:**');
        Content.AppendLine('');
        Content.AppendLine('- For each data codeunit, scan the `Insert*` calls and verify no two calls share the same primary key argument values.');
        Content.AppendLine('- Where duplicate keys exist, either assign the correct distinct key values or remove the duplicate calls.');
        Content.AppendLine('- Add a `// TODO` comment where the correct key values need to be sourced from the original data.');
        Content.AppendLine('');
        // 6. Transaction / Historical data
        Content.AppendLine('### 6. Transaction and Historical Data - Generate from the JSON Snapshot');
        Content.AppendLine('');
        Content.AppendLine('Data codeunits in `3.Transactions/` and `4.Historical Data/` contain only a `// TODO` stub. Instead of unreliable literal `Insert` calls, the generator captured the live document data as JSON snapshot(s) next to each stub codeunit (`*.data.json`).');
        Content.AppendLine('');
        Content.AppendLine('**Actions:**');
        Content.AppendLine('');
        Content.AppendLine('- Run the bundled `.github/prompts/generate-transaction-data.prompt.md` Copilot prompt for each stub codeunit, attaching the relevant BC symbols it asks for.');
        Content.AppendLine('- Or remove these tables/groups from Transactions/Historical level if they are not relevant for demo posting.');
        Content.AppendLine('');
        // 7. Sensitive / environment-specific records
        Content.AppendLine('### 7. Remove Sensitive or Environment-Specific Records');
        Content.AppendLine('');
        Content.AppendLine('The generator captured a snapshot of live data. Review each data codeunit and remove or anonymize Insert calls for records that:');
        Content.AppendLine('');
        Content.AppendLine('- Contain personal data (names, addresses, contact information).');
        Content.AppendLine('- Are test or internal records not suitable for a demo company.');
        Content.AppendLine('- Reference environment-specific objects (specific users, internal counters, machine identifiers).');
        Content.AppendLine('- Would cause import errors in a clean environment (e.g. references to records that do not exist in a fresh company).');
        Content.AppendLine('');
        // 8. Remove unused variable declarations
        Content.AppendLine('### 8. Remove Unused Variable Declarations');
        Content.AppendLine('');
        Content.AppendLine('The generator declares variables for every helper codeunit that was configured, even when the resulting `OnRun` body does not actually call that helper after review or refactoring.');
        Content.AppendLine('');
        Content.AppendLine('**Actions:**');
        Content.AppendLine('');
        Content.AppendLine('- After all other edits are complete, scan every `var` block in `OnRun` and local procedures.');
        Content.AppendLine('- Remove any variable that is declared but not referenced in the procedure body.');
        Content.AppendLine('');
        // 9. Verify app.json dependencies
        Content.AppendLine('### 9. Verify app.json Dependencies');
        Content.AppendLine('');
        Content.AppendLine('The `app.json` was auto-generated with dependencies detected from field Source App IDs. Verify:');
        Content.AppendLine('');
        Content.AppendLine('- All listed dependencies are actually used by the generated code.');
        Content.AppendLine('- The Contoso Coffee Demo Dataset dependency is present (it is mandatory).');
        Content.AppendLine('- Version numbers are appropriate and not overly restrictive.');
        Content.AppendLine('');
        // 10. Replace Option with named enums
        Content.AppendLine('### 10. Replace `Option` Parameters with Named Enums');
        Content.AppendLine('');
        Content.AppendLine('The generator uses `Option` for fields that have a named Enum type in the base application (e.g. `Bal. Account Type`, payment direction). `Option` loses compile-time safety and IntelliSense support.');
        Content.AppendLine('');
        Content.AppendLine('**Actions:**');
        Content.AppendLine('');
        Content.AppendLine('- For each `Option` parameter in a generated helper procedure, check whether the corresponding table field is backed by a named Enum.');
        Content.AppendLine('- If so, replace `Option` with the Enum type, e.g. `Enum "Gen. Journal Account Type"` or `Enum "Payment Balance Account Type"`.');
        Content.AppendLine('- Update all call sites to pass the Enum value instead of an integer literal.');
        Content.AppendLine('');
        Content.AppendLine('---');
        Content.AppendLine('');
        // What not to change
        Content.AppendLine('## What NOT to Change');
        Content.AppendLine('');
        Content.AppendLine('The following patterns must remain exactly as generated to stay compatible with the Contoso framework:');
        Content.AppendLine('');
        Content.AppendLine('- The procedure signatures in the module codeunit: `CreateSetupData()`, `CreateMasterData()`, `CreateTransactionalData()`, `CreateHistoricalData()`, `GetDependencies()`, `RunConfigurationPage()`.');
        Content.AppendLine('- The enum extension targeting `Enum 5160 "Contoso Demo Data Module"` and its `Implementation` mapping.');
        Content.AppendLine('- The `InherentEntitlements = X` and `InherentPermissions = X` properties on all codeunits.');
        Content.AppendLine('- The `OverwriteData` field and `SetOverwriteData()` procedure in helper codeunits.');
        Content.AppendLine('- The `Get / Validate / Insert|Modify` pattern in helper Insert procedures.');
        Content.AppendLine('');
        Content.AppendLine('---');
        Content.AppendLine('');
        // Quick reference
        Content.AppendLine('## Quick Reference: Tok/Lbl Label Pattern');
        Content.AppendLine('');
        Content.AppendLine('From the official Contoso Coding Patterns - two label types are used:');
        Content.AppendLine('');
        Content.AppendLine('- **Tok label**: for code values used as keys. Add `Locked = true` to prevent translation.');
        Content.AppendLine('  Example: `SalesInvoiceTok: Label ''SINV'', MaxLength = 20, Locked = true;`');
        Content.AppendLine('');
        Content.AppendLine('- **Lbl label**: for display/description text. Translatable, no `Locked`.');
        Content.AppendLine('  Example: `SalesInvoiceLbl: Label ''Sales Invoice'', MaxLength = 100;`');
        Content.AppendLine('');
        Content.AppendLine('Pair each Tok label with a public accessor procedure so that other code can reference the value without coupling to the string literal. This is the "Descriptive Methods" pattern in the Contoso Coding Patterns document.');
        Content.AppendLine('');
        Content.AppendLine('For full code examples, see:');
        Content.AppendLine('https://github.com/microsoft/ALAppExtensions/blob/main/Apps/W1/ContosoCoffeeDemoDataset/app/Coding-Patterns.md');
        exit(Content.ToText());
    end;

    /// <summary>
    /// Builds the Copilot prompt guiding the dev through turning a captured Transaction/Historical
    /// JSON data snapshot (and dev-supplied BC symbols) into a real data codeunit, replacing the
    /// generated stub. Historical Data additionally asks for a posting step after document creation.
    /// </summary>
    local procedure GetTransactionDataPromptContent(): Text
    var
        Content: TextBuilder;
    begin
        // YAML frontmatter
        Content.AppendLine('---');
        Content.AppendLine('agent: ''agent''');
        Content.AppendLine('description: ''Generate Transaction/Historical data codeunits from a captured JSON snapshot''');
        Content.AppendLine('---');
        Content.AppendLine('');
        Content.AppendLine('# Generate Transaction/Historical Data From JSON Snapshot');
        Content.AppendLine('');
        Content.AppendLine('This extension has one or more stub data codeunits in `src/3.Transactions/` and/or `src/4.Historical Data/` whose `OnRun` trigger only contains a `// TODO` comment. Next to each stub codeunit is a `*.data.json` file - a raw snapshot of the live source data, captured because generating reliable AL for documents/postings generically is not possible from a static data snapshot (this is a known, deliberate limitation of the generator; see the tool''s README).');
        Content.AppendLine('');
        Content.AppendLine('Your job: replace each stub''s `// TODO` body with real AL that (re)creates the data described in its paired JSON file.');
        Content.AppendLine('');
        Content.AppendLine('---');
        Content.AppendLine('');
        Content.AppendLine('## JSON Snapshot Shape');
        Content.AppendLine('');
        Content.AppendLine('Two shapes are used, depending on whether the tables were configured as a Document Group in the generator:');
        Content.AppendLine('');
        Content.AppendLine('- **Grouped (Header + Line tables)**: a JSON array of documents. Each document object has one property per Header field, plus one array property per Line table (keyed by the Line table''s name) containing that document''s correlated line rows.');
        Content.AppendLine('- **Standalone (no Document Group)**: a flat JSON array, one object per row, one property per configured field. No correlation between files is implied.');
        Content.AppendLine('');
        Content.AppendLine('All values were captured as their live, raw display value (numbers/booleans stay typed; dates, codes, enums, etc. are formatted text). Treat the JSON purely as reference data to recreate - do not assume it is already in the exact format your target fields expect.');
        Content.AppendLine('');
        Content.AppendLine('---');
        Content.AppendLine('');
        Content.AppendLine('## Before You Ask Copilot to Generate Code');
        Content.AppendLine('');
        Content.AppendLine('Attach the relevant BC symbols to the chat context so Copilot can generate correct, compiling code instead of guessing:');
        Content.AppendLine('');
        Content.AppendLine('- The standard BC table(s)/page(s) involved (e.g. `Sales Header`, `Sales Line`), if this is a standard document type.');
        Content.AppendLine('- Any bespoke/custom codeunits or libraries in this workspace that already provide document-creation helpers - prefer those over hand-rolled `Insert` calls.');
        Content.AppendLine('- The paired `*.data.json` file itself.');
        Content.AppendLine('');
        Content.AppendLine('---');
        Content.AppendLine('');
        Content.AppendLine('## What To Generate');
        Content.AppendLine('');
        Content.AppendLine('- **Transaction Data**: create the open document(s)/record(s) described in the JSON only. Do not post anything.');
        Content.AppendLine('- **Historical Data**: create the same open document(s), then also invoke the correct posting routine so the data ends up posted, matching how the Contoso Coffee Demo Dataset itself separates "create" (`3.Transactions/`) from "create + post" (`4.Historical Data/`, e.g. see `Create Posted Sales Data` / `Create Posted Analytics Data` in the Contoso repository for the pattern).');
        Content.AppendLine('- Follow the existing Contoso coding patterns used elsewhere in this extension/workspace (Get/Validate/Insert style helpers, Tok/Lbl label conventions) - see `Coding-Patterns.md` in the Contoso Coffee Demo Dataset repository.');
        Content.AppendLine('- Posting requires the target company to already have consistent, matching Setup/Master data (G/L Accounts, VAT Posting Setup, No. Series, Posting Groups, Dimensions). If posting fails locally, check that setup first before assuming the generated code is wrong.');
        Content.AppendLine('');
        Content.AppendLine('---');
        Content.AppendLine('');
        Content.AppendLine('## Reference: Common Document Type -> Posting Codeunit');
        Content.AppendLine('');
        Content.AppendLine('**This table is a non-exhaustive starting point only.** Always search the attached symbols and this workspace first for a local or bespoke posting routine, and prioritize that over anything listed here.');
        Content.AppendLine('');
        Content.AppendLine('| Document / Journal | Typical Posting Codeunit |');
        Content.AppendLine('|---|---|');
        Content.AppendLine('| Sales Header (Order/Invoice/...) | `Sales-Post` |');
        Content.AppendLine('| Purchase Header (Order/Invoice/...) | `Purch.-Post` |');
        Content.AppendLine('| Gen. Journal Line | `Gen. Jnl.-Post Line` |');
        Content.AppendLine('| Item Journal Line | `Item Jnl.-Post Line` |');
        Content.AppendLine('| FA Journal Line | `FA Jnl.-Post Line` |');
        Content.AppendLine('| Transfer Header | `TransferOrder-Post Shipment` / `TransferOrder-Post Receipt` |');
        Content.AppendLine('');
        exit(Content.ToText());
    end;

    var
        MissingNameErr: Label 'Module Name must be specified.';
        MissingRangeErr: Label 'ID Range Start and End must be specified.';
        InvalidRangeErr: Label 'ID Range Start must be less than or equal to ID Range End.';
        MissingEnumOrdinalErr: Label 'Enum Ordinal must be specified (non-zero).';
        MissingEnumValueErr: Label 'Enum Value Name must be specified.';
        MissingBaseNamespaceErr: Label 'Base Namespace must be specified.';
        NoTablesSelectedErr: Label 'At least one table must be selected.';
        MissingDataLevelErr: Label 'All selected tables must have a Data Level assigned.';
        NoFieldsConfiguredErr: Label 'Table "%1" has no fields configured (all excluded).', Comment = '%1 = Table Name';
        TooManyObjectsErr: Label 'Generated objects exceed the available ID range capacity (%1).', Comment = '%1 = Capacity';
        GenerationCompleteMsg: Label 'Module "%1" generated successfully. The zip file has been downloaded.', Comment = '%1 = Module Name';
        MissingHelperCodeunitErr: Label 'Table "%1" has no Helper Codeunit Name specified.', Comment = '%1 = Table Name';
        MissingDataCodeunitErr: Label 'Table "%1" has no Data Codeunit Name specified.', Comment = '%1 = Table Name';
        MissingGroupHeaderErr: Label 'Document Group "%1" has no Header table assigned.', Comment = '%1 = Document Group Code';
        MissingGroupLinkErr: Label 'Table "%1" has Group Role = Line but no Document Group Link field mappings configured.', Comment = '%1 = Table Name';
}
