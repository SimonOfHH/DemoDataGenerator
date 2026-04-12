namespace SimonOfHH.DemoData.Generator;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Export;
using SimonOfHH.DemoData.Core;

/// <summary>
/// Generates Contoso-style helper codeunits — one per unique Helper Group.
/// Each helper codeunit contains Insert* procedures for all tables in that group,
/// following the OverwriteData / Get / Validate / Insert|Modify pattern.
/// </summary>
codeunit 70120 "Helper Generator"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        IdentifierHelper: Codeunit "Identifier Helper";

    /// <summary>
    /// Generates all helper codeunits for the given module.
    /// Increments NextObjectId for each generated helper.
    /// </summary>
    procedure Generate(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container"): List of [Codeunit "CodeGen Codeunit"]
    var
        TableSelection: Record "Table Selection";
        HelperCU: Codeunit "CodeGen Codeunit";
        Results: List of [Codeunit "CodeGen Codeunit"];
        HelperGroups: List of [Text];
        GroupName: Text;
    begin
        // Collect unique helper groups
        TableSelection.SetRange("Module Code", ModuleDef.Code);
        if TableSelection.FindSet() then
            repeat
                if not HelperGroups.Contains(TableSelection."Helper Group") then
                    HelperGroups.Add(TableSelection."Helper Group");
            until TableSelection.Next() = 0;

        // Generate one helper codeunit per group
        foreach GroupName in HelperGroups do begin
            Clear(HelperCU);
            HelperCU := this.BuildHelperCodeunit(ModuleDef.Code, GroupName, ModuleContainer.GetNextCodeunitId(true), ModuleDef."Base Namespace");
            Results.Add(HelperCU);
            ModuleContainer.AddHelperCodeunit(HelperCU);
        end;

        exit(Results);
    end;

    /// <summary>
    /// Assembles a complete helper codeunit for one helper group: sets namespace and usings,
    /// adds the OverwriteData global + setter procedure, generates one Insert procedure per table
    /// in the group, and appends any reference-value getter procedures.
    /// </summary>
    local procedure BuildHelperCodeunit(ModuleCode: Code[20]; GroupName: Text; ObjectId: Integer; BaseNamespace: Text): Codeunit "CodeGen Codeunit"
    var
        ModuleDefinition: Record "Module Definition";
        TableSelection: Record "Table Selection";
        HelperCU: Codeunit "CodeGen Codeunit";
        SetOverwriteProc: Codeunit "CodeGen Procedure";
        InsertProc: Codeunit "CodeGen Procedure";
        ParamVar: Codeunit "CodeGen Variable";
        OverwriteVar: Codeunit "CodeGen Variable";
        CUName, Namespace : Text;
        TableNames: List of [Text];
        UsedNamespaces: List of [Text];
    begin
        ModuleDefinition.Get(ModuleCode);
        // Collect table names for Permissions property
        TableSelection.SetRange("Module Code", ModuleCode);
        TableSelection.SetRange("Helper Group", GroupName);
        if TableSelection.FindSet() then
            repeat
                TableNames.Add(TableSelection."Table Name");
                if TableSelection."AL Namespace" <> '' then
                    if not UsedNamespaces.Contains(TableSelection."AL Namespace") then
                        UsedNamespaces.Add(TableSelection."AL Namespace");
            until TableSelection.Next() = 0;

        CUName := this.IdentifierHelper.GetHelperCodeunitName(ModuleDefinition."Helper Prefix", GroupName);

        HelperCU.Initialize(ObjectId, CUName);

        if BaseNamespace <> '' then
            HelperCU.Namespace(BaseNamespace + '.Helpers');
        if UsedNamespaces.Count() > 0 then
            foreach Namespace in UsedNamespaces do
                HelperCU.AddUsing(Namespace);
        HelperCU.AddProperty('InherentEntitlements', 'X');
        HelperCU.AddProperty('InherentPermissions', 'X');

        HelperCU.AddProperty('Permissions', this.BuildPermissions(TableNames));

        // OverwriteData global variable
        Clear(OverwriteVar);
        OverwriteVar.Init('OverwriteData', 'Boolean', 0, '', '');
        HelperCU.AddGlobalVariable(OverwriteVar);

        // SetOverwriteData procedure
        Clear(SetOverwriteProc);
        SetOverwriteProc.Init('SetOverwriteData');
        Clear(ParamVar);
        ParamVar.Init('Overwrite', 'Boolean', 0, '', '');
        SetOverwriteProc.AddParameter(ParamVar);
        SetOverwriteProc.AddCodeLine('OverwriteData := Overwrite;');
        HelperCU.AddProcedure(SetOverwriteProc);

        // Generate one Insert* procedure per table in this group
        TableSelection.Reset();
        TableSelection.SetRange("Module Code", ModuleCode);
        TableSelection.SetRange("Helper Group", GroupName);
        TableSelection.SetCurrentKey("Module Code", "Data Level", "Sort Order");
        if TableSelection.FindSet() then
            repeat
                Clear(InsertProc);
                InsertProc := this.BuildInsertProcedure(TableSelection);
                HelperCU.AddProcedure(InsertProc);
            until TableSelection.Next() = 0;

        // Check if any Table either is referenced via a "Reference Value"-field or has fields with "Reference Value" behavior
        // If so, we'll need to add simple helper function (like "Get<FieldValue>") to resolve those references
        HelperCU.AddReferenceValues(this.GetFieldReferenceValues(ModuleDefinition, GroupName));
        exit(HelperCU);
    end;

    /// <summary>
    /// Collects all reference values across tables in a helper group by iterating
    /// tables with Reference Value fields and delegating to the per-table overload.
    /// </summary>
    local procedure GetFieldReferenceValues(ModuleDefinition: Record "Module Definition"; GroupName: Text): List of [Codeunit "CodeGen Reference Value"]
    var
        TableSelection: Record "Table Selection";
        FieldConfig: Record "Field Configuration";
        ReferenceValues: List of [Codeunit "CodeGen Reference Value"];
    begin
        TableSelection.SetRange("Module Code", ModuleDefinition.Code);
        TableSelection.SetRange("Helper Group", GroupName);
        if not TableSelection.FindSet() then
            exit;
        repeat
            FieldConfig.SetRange("Module Code", ModuleDefinition.Code);
            FieldConfig.SetRange("Table ID", TableSelection."Table ID");
            FieldConfig.SetRange("Behavior", FieldConfig.Behavior::"Reference Value");
            if not FieldConfig.FindSet() then
                continue;
            repeat
                ReferenceValues.AddRange(GetFieldReferenceValues(TableSelection, FieldConfig));
            until FieldConfig.Next() = 0;
        until TableSelection.Next() = 0;
        exit(ReferenceValues);
    end;

    /// <summary>
    /// Reads all live records for a single table and builds a CodeGen Reference Value
    /// for each row, capturing the actual field value so the helper codeunit can
    /// generate a deterministic getter procedure per unique reference.
    /// </summary>
    local procedure GetFieldReferenceValues(TableSelection: Record "Table Selection"; FieldConfig: Record "Field Configuration"): List of [Codeunit "CodeGen Reference Value"]
    var
        VariableHelper: Codeunit "CodeGen Variable Helper";
        RecRef: RecordRef;
        FldRef: FieldRef;
        ReferenceValues: List of [Codeunit "CodeGen Reference Value"];
    begin
        RecRef.Open(TableSelection."Table ID");
        if not RecRef.FindSet() then
            exit;
        repeat
            FldRef := RecRef.Field(FieldConfig."Field No.");
            ReferenceValues.Add(VariableHelper.GetReferenceValue(FieldConfig."Reference Table ID", FieldConfig."Reference Field ID", FldRef.Value()));
        until RecRef.Next() = 0;
        exit(ReferenceValues);
    end;

    local procedure BuildInsertProcedure(TableSelection: Record "Table Selection"): Codeunit "CodeGen Procedure"
    var
        Templates: Codeunit "Code Templates";
    begin
        exit(Templates.GetHelperInsertProcedureTemplate(TableSelection));
    end;

    local procedure BuildPermissions(TableNames: List of [Text]): Text
    var
        Result: TextBuilder;
        TableName: Text;
        IsFirst: Boolean;
        LF: Char;
    begin
        LF := 10;
        IsFirst := true;
        foreach TableName in TableNames do begin
            if not IsFirst then
                Result.Append(',');
            Result.Append(Format(LF));
            Result.Append('            tabledata "' + TableName + '" = rim');
            IsFirst := false;
        end;
        exit(Result.ToText());
    end;
}
