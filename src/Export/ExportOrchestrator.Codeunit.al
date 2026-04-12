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
