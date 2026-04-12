namespace SimonOfHH.DemoData.Generator;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Core;

/// <summary>
/// Generates "Create ..." data codeunits — one per selected table.
/// Each codeunit reads live data via RecordRef and generates Insert calls
/// with literal values from AL Formatter. Handles Label Field (accessor
/// procedures + Label constants) and Dynamic Field (placeholder procedures).
/// </summary>
codeunit 70121 "Data Generator"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        IdentifierHelper: Codeunit "Identifier Helper";
        ALFormatter: Codeunit "AL Formatter";
        Templates: Codeunit "Code Templates";

    /// <summary>
    /// Generates all data codeunits for the given module.
    /// Increments NextObjectId for each generated codeunit.
    /// </summary>
    procedure Generate(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container"): List of [Codeunit "CodeGen Codeunit"]
    var
        TableSel: Record "Table Selection";
        DataCU: Codeunit "CodeGen Codeunit";
        Results: List of [Codeunit "CodeGen Codeunit"];
    begin
        TableSel.SetRange("Module Code", ModuleDef.Code);
        TableSel.SetCurrentKey("Module Code", "Data Level", "Sort Order");
        if TableSel.FindSet() then
            repeat
                Clear(DataCU);
                DataCU := this.GenerateForTable(TableSel, ModuleContainer.GetNextCodeunitId(true), ModuleDef."Base Namespace");
                Results.Add(DataCU);
                ModuleContainer.AddDataCodeunit(DataCU);
            until TableSel.Next() = 0;
        exit(Results);
    end;

    /// <summary>
    /// Generates a single data codeunit for one table. Reads all live records via RecordRef,
    /// builds an Insert call per row, and collects any complex arguments (labels, dynamic fields,
    /// token-label procedures) that need additional global variables or procedures in the codeunit.
    /// </summary>
    local procedure GenerateForTable(TableSel: Record "Table Selection"; ObjectId: Integer; BaseNamespace: Text): Codeunit "CodeGen Codeunit"
    var
        ModuleDefinition: Record "Module Definition";
        DataCU: Codeunit "CodeGen Codeunit";
        OnRunProc: Codeunit "CodeGen Procedure";
        HelperLocalVar: Codeunit "CodeGen Variable";
        ComplexArgument: Codeunit "CodeGen Argument";
        RecRef: RecordRef;
        HelperVarName: Text;
        InsertProcName: Text;
        // Dynamic field tracking: ProcName is the unique key
        ComplexArguments: List of [Codeunit "CodeGen Argument"];
    begin
        ModuleDefinition.Get(TableSel."Module Code");
        HelperVarName := this.ALFormatter.ToPascalCase(TableSel."Helper Codeunit Name");
        InsertProcName := this.IdentifierHelper.GetInsertProcedureName(TableSel."Table Name");

        DataCU.Initialize(ObjectId, TableSel."Data Codeunit Name");
        DataCU.DataLevel(TableSel."Data Level");

        if BaseNamespace <> '' then begin
            DataCU.Namespace(BaseNamespace + '.DemoData');
            DataCU.AddUsing(BaseNamespace + '.Helpers');
        end;

        DataCU.AddProperty('InherentEntitlements', 'X');
        DataCU.AddProperty('InherentPermissions', 'X');

        // OnRun trigger
        OnRunProc.Init('OnRun');
        OnRunProc.SetTrigger(true);

        Clear(HelperLocalVar);
        HelperLocalVar.Init(HelperVarName, 'Codeunit', 0, TableSel."Helper Codeunit Name", '');
        OnRunProc.AddLocalVariable(HelperLocalVar);

        // Read live data and generate Insert calls
        RecRef.Open(TableSel."Table ID");
        if RecRef.FindSet() then
            repeat
                OnRunProc.AddCodeLine(
                    this.BuildInsertCall(TableSel, RecRef, HelperVarName, InsertProcName, ComplexArguments));
            until RecRef.Next() = 0;
        RecRef.Close();

        DataCU.AddProcedure(OnRunProc);
        if this.ContainsDateFormula(ModuleDefinition, TableSel) then
            DataCU.AddProcedure(this.Templates.GetEvaluateDateFormulaProcedure());

        foreach ComplexArgument in ComplexArguments do begin
            if not ComplexArgument.IsProcedure() then
                continue;
            DataCU.AddProcedure(ComplexArgument.ToProcedure());
            if ComplexArgument.HasAssociatedVariable() then
                DataCU.AddGlobalVariable(ComplexArgument.AssociatedVariableToVariable());
        end;

        foreach ComplexArgument in ComplexArguments do begin
            if not ComplexArgument.IsGlobalVariable() then
                continue;
            DataCU.AddGlobalVariable(ComplexArgument.ToVariable());
        end;

        exit(DataCU);
    end;

    local procedure BuildInsertCall(
        TableSel: Record "Table Selection";
        RecRef: RecordRef;
        HelperVarName: Text;
        InsertProcName: Text;
        var ComplexArguments: List of [Codeunit "CodeGen Argument"]): Text
    var
        FieldConfig: Record "Field Configuration";
        FldRef: FieldRef;
        ArgList: TextBuilder;
        ArgValue: Text;
        IsFirst: Boolean;
    begin
        IsFirst := true;

        // PK fields first (same order as helper Insert procedure params)
        FieldConfig.SetRange("Module Code", TableSel."Module Code");
        FieldConfig.SetRange("Table ID", TableSel."Table ID");
        FieldConfig.SetRange("Is Primary Key", true);
        FieldConfig.SetCurrentKey("Module Code", "Table ID", "Sort Order");
        if FieldConfig.FindSet() then
            repeat
                FldRef := RecRef.Field(FieldConfig."Field No.");
                ArgValue := this.GetArgumentValue(FieldConfig, FldRef, ComplexArguments, HelperVarName);
                if not IsFirst then
                    ArgList.Append(', ');
                ArgList.Append(ArgValue);
                IsFirst := false;
            until FieldConfig.Next() = 0;

        // Non-PK included fields (same order as helper Insert procedure params)
        FieldConfig.SetRange("Is Primary Key", false);
        FieldConfig.SetFilter(Behavior, '<>%1', FieldConfig.Behavior::Exclude);
        if FieldConfig.FindSet() then
            repeat
                FldRef := RecRef.Field(FieldConfig."Field No.");
                ArgValue := this.GetArgumentValue(FieldConfig, FldRef, ComplexArguments, HelperVarName);
                if not IsFirst then
                    ArgList.Append(', ');
                ArgList.Append(ArgValue);
                IsFirst := false;
            until FieldConfig.Next() = 0;

        exit(StrSubstNo('%1.%2(%3);', HelperVarName, InsertProcName, ArgList.ToText()));
    end;

    /// <summary>
    /// Returns the AL expression to use as an argument in the generated Insert call,
    /// based on the field's configured Behavior:
    /// Include → formatted literal (with special handling for DateFormula and relative dates),
    /// Label Field → label variable name (registers a global Label var),
    /// Dynamic Field → placeholder procedure call (registers a stub procedure),
    /// Procedure with Token-Label → accessor procedure + associated label variable,
    /// Reference Value → helper codeunit getter call.
    /// </summary>
    local procedure GetArgumentValue(
        FieldConfig: Record "Field Configuration";
        FldRef: FieldRef;
        var ComplexArguments: List of [Codeunit "CodeGen Argument"]; HelperCUName: Text): Text
    var
        Argument: Codeunit "CodeGen Argument";
        ReferenceValue: Codeunit "CodeGen Reference Value";
        RawValue: Text;
        ProcName: Text;
        VarName: Text;
        RetType: Text;
    begin
        FieldConfig.CalcFields("Is Referenced Field");
        if FieldConfig."Is Referenced Field" then begin
            FieldConfig.Behavior := FieldConfig.Behavior::"Reference Value";
            FieldConfig."Reference Table ID" := FieldConfig."Table ID";
            FieldConfig."Reference Field ID" := FieldConfig."Field No.";
        end;
        case FieldConfig.Behavior of
            FieldConfig.Behavior::Include:
                begin
                    if FldRef.Type = FieldType::DateFormula then
                        exit(this.Templates.GetDateFormulaValueCall(this.ALFormatter.FormatValue(FldRef)));
                    if (FldRef.Type = FieldType::Date) and (FieldConfig."Relative Date" <> Enum::"Relative Date Option"::None) then
                        exit(this.Templates.GetRelativeDateValueCall(FldRef.Value, FieldConfig."Relative Date"));
                    exit(this.ALFormatter.FormatValue(FldRef));
                end;
            FieldConfig.Behavior::"Label Field":
                begin
                    RawValue := Format(FldRef.Value);
                    if RawValue = '' then
                        exit('''''');
                    VarName := this.IdentifierHelper.GetLabelVarName(RawValue);
                    ComplexArguments.Add(Argument.SetLabelField(VarName, 'Label', FieldConfig."Data Length", RawValue, FieldConfig."Locked Label"));
                    exit(VarName);
                end;
            FieldConfig.Behavior::"Dynamic Field":
                begin
                    ProcName := this.IdentifierHelper.GetIdentifierName(FieldConfig."Field Name");
                    RetType := this.BuildReturnType(FieldConfig."Data Type", FieldConfig."Data Length");
                    ComplexArguments.Add(Argument.SetDynamicField(ProcName + '()', '', 0, '', '', RetType));
                    exit(ProcName + '()');
                end;
            FieldConfig.Behavior::"Procedure with Token-Label":
                begin
                    RawValue := Format(FldRef.Value);
                    if RawValue = '' then
                        exit('''''');

                    ProcName := this.IdentifierHelper.GetIdentifierName(RawValue);
                    VarName := ProcName + 'Tok';
                    ComplexArguments.Add(Argument.SetProcedureWithTokenLabelArgument(ProcName + '()', 'Text', FieldConfig."Data Length", RawValue, VarName, 'Label', FieldConfig."Locked Label"));
                    exit(ProcName + '()');
                end;
            FieldConfig.Behavior::"Reference Value":
                begin
                    RawValue := ReferenceValue.GetAsArgParameter(HelperCUName, FieldConfig."Reference Table ID", FieldConfig."Reference Field ID", FldRef.Value);
                    exit(RawValue);
                end;
            else
                // Exclude — should not reach here since filtered out
                exit('''''');
        end;
    end;

    local procedure BuildReturnType(DataType: Text; DataLength: Integer): Text
    begin
        if DataType in ['Code', 'Text'] then
            exit(StrSubstNo('%1[%2]', DataType, DataLength));
        exit(DataType);
    end;

    local procedure ContainsDateFormula(ModuleDefinition: Record "Module Definition"; TableSel: Record "Table Selection"): Boolean
    var
        FieldConfig: Record "Field Configuration";
    begin
        FieldConfig.SetRange("Module Code", ModuleDefinition.Code);
        FieldConfig.SetRange("Table ID", TableSel."Table ID");
        FieldConfig.SetFilter(Behavior, '<>%1', FieldConfig.Behavior::Exclude);
        FieldConfig.SetRange("Data Type", 'DateFormula');
        exit(not FieldConfig.IsEmpty());
    end;
}
