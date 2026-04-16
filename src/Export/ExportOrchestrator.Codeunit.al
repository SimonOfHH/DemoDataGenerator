namespace SimonOfHH.DemoData.Export;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Generator;
using SimonOfHH.DemoData.Core;

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
        ModuleGenerator: Codeunit "Module Generator";
        EnumExtGenerator: Codeunit "Enum Extension Generator";
        AppManifestGenerator: Codeunit "App Manifest Generator";
        ALFormatter: Codeunit "AL Formatter";
        ZipHelper: Codeunit "Zip Helper";

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
    end;

    /// <summary>
    /// Convenience overload that generates and exports (downloads) the module in one step.
    /// Equivalent to calling Run(ModuleDef, true).
    /// </summary>
    procedure Run(ModuleDef: Record "Module Definition")
    begin
        this.Run(ModuleDef, true);
    end;
    /// <summary>
    /// Validates, generates, and downloads the complete AL extension.
    /// </summary>
    procedure Run(ModuleDef: Record "Module Definition"; Export: Boolean)
    var
        ModuleContainer: Codeunit "CodeGen Module Container";
    begin
        // 1. Validate
        this.PreGenerateValidateModule(ModuleDef);
        // 2. Generate codeunits and manifest
        this.GenerateModule(ModuleDef, ModuleContainer);
        // 3. Post-generation validation (e.g. ID range capacity)
        this.PostGenerateValidateModule(ModuleDef, ModuleContainer);

        // 4. Assemble and download zip
        if Export then begin
            this.AssembleZip(ModuleDef, ModuleContainer);

            // 5. Update status
            ModuleDef.Status := "Module Status"::Generated;
            ModuleDef.Modify(true);

            Message(GenerationCompleteMsg, ModuleDef.Name);
        end;
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
        TableSel: Record "Table Selection";
        FieldConfig: Record "Field Configuration";
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

        // At least one table selected
        TableSel.SetRange("Module Code", ModuleDef.Code);
        if TableSel.IsEmpty() then
            ErrorInfoDetail.AppendLine(NoTablesSelectedErr);

        // Every table must have a Data Level assigned
        TableSel.SetRange("Data Level", "Data Level"::" ");
        if not TableSel.IsEmpty() then
            ErrorInfoDetail.AppendLine(MissingDataLevelErr);

        // Every table must have at least one non-excluded field
        TableSel.SetRange("Data Level");
        if TableSel.FindSet() then
            repeat
                if TableSel."Helper Codeunit Name" = '' then
                    ErrorInfoDetail.AppendLine(StrSubstNo(MissingHelperCodeunitErr, TableSel."Table Name"));
                if TableSel."Data Codeunit Name" = '' then
                    ErrorInfoDetail.AppendLine(StrSubstNo(MissingDataCodeunitErr, TableSel."Table Name"));
                FieldConfig.SetRange("Module Code", TableSel."Module Code");
                FieldConfig.SetRange("Table ID", TableSel."Table ID");
                FieldConfig.SetFilter(Behavior, '<>%1', FieldConfig.Behavior::Exclude);
                if FieldConfig.IsEmpty() then
                    ErrorInfoDetail.AppendLine(StrSubstNo(NoFieldsConfiguredErr, TableSel."Table Name"));
            until TableSel.Next() = 0;
        if ErrorInfoDetail.Length() > 0 then begin
            ValidationErrorInfo.Title := ErrorInfoTitleLbl;
            ValidationErrorInfo.Message := StrSubstNo(ErrorInfoMsg, ModuleDef.Name);
            ValidationErrorInfo.DetailedMessage := ErrorInfoDetail.ToText();
            Error(ValidationErrorInfo);
        end;
    end;

    local procedure AssembleZip(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container")
    begin
        this.AssembleZip(
            ModuleDef,
            ModuleContainer.GetHelperCodeunits(),
            ModuleContainer.GetDataCodeunits(),
            ModuleContainer.GetModuleCodeunit(),
            ModuleContainer.GetEnumExtension(),
            ModuleContainer.GetManifestCodeunit());
    end;

    local procedure AssembleZip(
        ModuleDef: Record "Module Definition";
        HelperCUs: List of [Codeunit "CodeGen Codeunit"];
        DataCUs: List of [Codeunit "CodeGen Codeunit"];
        ModuleCU: Codeunit "CodeGen Codeunit";
        EnumExt: Codeunit "CodeGen Enum Extension";
        AppManifest: Codeunit "CodeGen App Manifest")
    var
        HelperCU: Codeunit "CodeGen Codeunit";
        DataCU: Codeunit "CodeGen Codeunit";
        BasePath: Text;
        PublisherSafe, ModuleSafe : Text;
        DataLevelFolder: Text;
    begin
        PublisherSafe := this.ALFormatter.SanitizeIdentifier(ModuleDef.Publisher);
        ModuleSafe := this.ALFormatter.SanitizeIdentifier(ModuleDef.Name);
        BasePath := ModuleSafe + '/';

        this.ZipHelper.Initialize();

        // app.json
        this.ZipHelper.AddTextFile(BasePath + 'app.json', AppManifest.ToString());

        // Module codeunit
        this.ZipHelper.AddTextFile(
            BasePath + 'src/' + ModuleSafe + 'Module.Codeunit.al',
            ModuleCU.ToString());

        // Enum extension
        this.ZipHelper.AddTextFile(
            BasePath + 'src/' + ModuleSafe + 'ModuleEnum.EnumExt.al',
            EnumExt.ToString());

        // Helper codeunits
        foreach HelperCU in HelperCUs do
            this.ZipHelper.AddTextFile(
                BasePath + 'src/Helpers/' + this.ALFormatter.SanitizeIdentifier(HelperCU.Name()) + '.Codeunit.al',
                HelperCU.ToString());

        // Data codeunits — organized by data level folder
        foreach DataCU in DataCUs do begin
            // Look up the table selection to determine the data level folder
            DataLevelFolder := this.GetDataLevelFolder(DataCU.DataLevel());
            this.ZipHelper.AddTextFile(
                BasePath + 'src/' + DataLevelFolder + this.ALFormatter.SanitizeIdentifier(DataCU.Name()) + '.Codeunit.al',
                DataCU.ToString());
        end;

        // Review & polish prompt for Copilot
        this.ZipHelper.AddTextFile(BasePath + '.github/prompts/review-generated-code.prompt.md', this.GetReviewPromptContent());

        // Download
        this.ZipHelper.Download(PublisherSafe + '_' + ModuleSafe + '_' + ModuleDef."App Version" + '.zip');
    end;

    local procedure GetDataLevelFolder(DataLevel: Enum SimonOfHH.DemoData.Model."Data Level"): Text
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
        Content.AppendLine('| `src/3.Transactions/` | Skeleton only - NOT implemented, see item 6 below |');
        Content.AppendLine('| `src/4.Historical Data/` | Skeleton only - NOT implemented, see item 6 below |');
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
        Content.AppendLine('### 6. Transaction and Historical Data - Requires Manual Implementation');
        Content.AppendLine('');
        Content.AppendLine('Data codeunits in `3.Transactions/` and `4.Historical Data/` contain only skeleton procedures (`CreateTransactionalData()` / `CreateHistoricalData()`). The generator does not implement them because transactional and historical data require posting documents, which cannot be reliably automated from a static data snapshot.');
        Content.AppendLine('');
        Content.AppendLine('**Actions:**');
        Content.AppendLine('');
        Content.AppendLine('- Implement these manually following Contoso patterns in existing modules (e.g. ContosoSales, ContosoPurchase).');
        Content.AppendLine('- Or remove these tables from Transactions/Historical level if they are not relevant for demo posting.');
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

    var
        MissingNameErr: Label 'Module Name must be specified.';
        MissingRangeErr: Label 'ID Range Start and End must be specified.';
        InvalidRangeErr: Label 'ID Range Start must be less than or equal to ID Range End.';
        MissingEnumOrdinalErr: Label 'Enum Ordinal must be specified (non-zero).';
        MissingEnumValueErr: Label 'Enum Value Name must be specified.';
        NoTablesSelectedErr: Label 'At least one table must be selected.';
        MissingDataLevelErr: Label 'All selected tables must have a Data Level assigned.';
        NoFieldsConfiguredErr: Label 'Table "%1" has no fields configured (all excluded).', Comment = '%1 = Table Name';
        TooManyObjectsErr: Label 'Generated objects exceed the available ID range capacity (%1).', Comment = '%1 = Capacity';
        GenerationCompleteMsg: Label 'Module "%1" generated successfully. The zip file has been downloaded.', Comment = '%1 = Module Name';
        MissingHelperCodeunitErr: Label 'Table "%1" has no Helper Codeunit Name specified.', Comment = '%1 = Table Name';
        MissingDataCodeunitErr: Label 'Table "%1" has no Data Codeunit Name specified.', Comment = '%1 = Table Name';
}
