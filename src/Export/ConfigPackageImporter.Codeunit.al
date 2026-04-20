namespace SimonOfHH.DemoData.Export;

using SimonOfHH.DemoData.Model;
using System.Reflection;
using System.IO;

/// <summary>
/// Imports tables and field configurations into a module definition from an existing
/// RapidStart / Configuration Package. Fields with "Include Field" = true in the package
/// are imported with Behavior = Include; all other fields default to Exclude.
/// Row filters defined in the package are imported as Table View.
/// </summary>
codeunit 70136 "Config. Package Importer"
{
    procedure ImportFromConfigPackage(ModuleDefinition: Record "Module Definition")
    var
        ConfigPackage: Record "Config. Package";
        ConfigPackageTable: Record "Config. Package Table";
        AllObjWithCaption: Record AllObjWithCaption;
        TableSel: Record "Table Selection";
        ImportedCount: Integer;
        UpdatedCount: Integer;
    begin
        if Page.RunModal(Page::"Config. Packages", ConfigPackage) <> Action::LookupOK then
            exit;

        ConfigPackageTable.SetRange("Package Code", ConfigPackage.Code);
        if not ConfigPackageTable.FindSet() then begin
            Message(NoTablesFoundMsg);
            exit;
        end;

        repeat
            if AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Table, ConfigPackageTable."Table ID") then begin
                if not TableSel.Get(ModuleDefinition.Code, ConfigPackageTable."Table ID") then begin
                    TableSel.Init();
                    TableSel."Module Code" := ModuleDefinition.Code;
                    TableSel.Validate("Table ID", ConfigPackageTable."Table ID");
                    TableSel.Insert(true);
                    ImportedCount += 1;
                end else
                    UpdatedCount += 1;
                this.ApplyConfigPackageBehaviors(ModuleDefinition.Code, ConfigPackage.Code, ConfigPackageTable."Table ID");
                this.ApplyConfigPackageFilter(ConfigPackage.Code, ConfigPackageTable."Table ID", TableSel);
            end;
        until ConfigPackageTable.Next() = 0;

        Message(ImportCompleteMsg, ImportedCount, UpdatedCount);
    end;

    local procedure ApplyConfigPackageBehaviors(ModuleCode: Code[20]; PackageCode: Code[20]; TableId: Integer)
    var
        FieldConfig: Record "Field Configuration";
    begin
        FieldConfig.SetRange("Module Code", ModuleCode);
        FieldConfig.SetRange("Table ID", TableId);
        if not FieldConfig.FindSet(true) then
            exit;

        repeat
            if FieldConfig."Is Primary Key" then
                FieldConfig.Behavior := FieldConfig.Behavior::Include
            else
                if FieldConfig.ShouldIncludeField() and this.IsFieldIncludedInPackage(PackageCode, TableId, FieldConfig."Field No.") then
                    FieldConfig.Behavior := FieldConfig.Behavior::Include
                else
                    FieldConfig.Behavior := FieldConfig.Behavior::Exclude;
            FieldConfig.Modify(true);
        until FieldConfig.Next() = 0;
    end;

    local procedure IsFieldIncludedInPackage(PackageCode: Code[20]; TableId: Integer; FieldNo: Integer): Boolean
    var
        ConfigPackageField: Record "Config. Package Field";
    begin
        if not ConfigPackageField.Get(PackageCode, TableId, FieldNo) then
            exit(false);
        exit(ConfigPackageField."Include Field");
    end;

    local procedure ApplyConfigPackageFilter(PackageCode: Code[20]; TableId: Integer; var TableSel: Record "Table Selection")
    var
        ConfigPackageFilter: Record "Config. Package Filter";
        RecRef: RecordRef;
        FldRef: FieldRef;
        FilterView: Text;
    begin
        ConfigPackageFilter.SetRange("Package Code", PackageCode);
        ConfigPackageFilter.SetRange("Table ID", TableId);
        if not ConfigPackageFilter.FindSet() then
            exit;

        RecRef.Open(TableId);
        repeat
            if RecRef.FieldExist(ConfigPackageFilter."Field ID") and (ConfigPackageFilter."Field Filter" <> '') then begin
                FldRef := RecRef.Field(ConfigPackageFilter."Field ID");
                FldRef.SetFilter(ConfigPackageFilter."Field Filter");
            end;
        until ConfigPackageFilter.Next() = 0;

        FilterView := RecRef.GetView();
        RecRef.Close();

        if not FilterView.Contains('WHERE') then
            exit;

        TableSel."Table View" := CopyStr(FilterView, 1, MaxStrLen(TableSel."Table View"));
        TableSel.Modify();
    end;

    var
        NoTablesFoundMsg: Label 'The selected configuration package contains no tables.';
        ImportCompleteMsg: Label '%1 table(s) added, %2 table(s) updated from configuration package.', Comment = '%1 = Number of newly added tables, %2 = Number of updated existing tables';
}
