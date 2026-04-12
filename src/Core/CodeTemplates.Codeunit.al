namespace SimonOfHH.DemoData.Core;
using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Model;

/// <summary>
/// Returns reusable AL code blocks as text for use by code generators.
/// These templates match the patterns used in Microsoft's Contoso Coffee Demo Dataset.
/// </summary>
codeunit 70116 "Code Templates"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        ALFormatter: Codeunit "AL Formatter";

    /// <summary>
    /// Builds a complete Insert procedure AST node for a table, following the Contoso
    /// OverwriteData / Get / Validate / Insert|Modify pattern. Primary-key fields appear
    /// first in the parameter list, followed by non-PK included fields.
    /// </summary>
    procedure GetHelperInsertProcedureTemplate(TableSelection: Record SimonOfHH.DemoData.Model."Table Selection"): Codeunit "CodeGen Procedure"
    var
        IdentifierHelper: Codeunit "Identifier Helper";
        VariableHelper: Codeunit "CodeGen Variable Helper";
        InsertProcedure: Codeunit "CodeGen Procedure";
        Param: Codeunit "CodeGen Variable";
        Params: List of [Codeunit "CodeGen Variable"];
        RecordVariableName: Text;
    begin
        RecordVariableName := IdentifierHelper.GetRecordVarName(TableSelection."Table Name");
        InsertProcedure.Init(IdentifierHelper.GetInsertProcedureName(TableSelection."Table Name"));
        InsertProcedure.AddLocalVariable(VariableHelper.GetVariable(IdentifierHelper.GetRecordVarName(TableSelection."Table Name"), 'Record', 0, TableSelection."Table Name", ''));
        InsertProcedure.AddLocalVariable(VariableHelper.GetVariable('Exists', 'Boolean', 0, '', ''));
        Params := this.GetParametersForTable(TableSelection);
        InsertProcedure.AddParameters(Params);
#pragma warning disable AA0217
        InsertProcedure.AddCodeLine(StrSubstNo('if %1.Get(%2) then begin', RecordVariableName, this.GetPrimaryKeyGetArgs(Params)));
        InsertProcedure.IncreaseIndent();
        InsertProcedure.AddCodeLine('Exists := true;');
        InsertProcedure.AddCodeLine('');
        InsertProcedure.AddCodeLine('if not OverwriteData then');
        InsertProcedure.IncreaseIndent();
        InsertProcedure.AddCodeLine('exit;');
        InsertProcedure.DecreaseIndent();
        InsertProcedure.DecreaseIndent();
        InsertProcedure.AddCodeLine('end;');
        InsertProcedure.AddCodeLine('');

        foreach Param in Params do
            InsertProcedure.AddCodeLine(this.ValidateFieldLine(RecordVariableName, Param.GetOriginalFieldname(), Param.GetCleanName()));

        InsertProcedure.AddCodeLine('');
        InsertProcedure.AddCodeLine('if Exists then');
        InsertProcedure.IncreaseIndent();
        InsertProcedure.AddCodeLine(StrSubstNo('%1.Modify(true)', RecordVariableName));
        InsertProcedure.DecreaseIndent();
        InsertProcedure.AddCodeLine('else');
        InsertProcedure.IncreaseIndent();
        InsertProcedure.AddCodeLine(StrSubstNo('%1.Insert(true);', RecordVariableName));
        InsertProcedure.DecreaseIndent();
#pragma warning restore AA0217
        exit(InsertProcedure);
    end;

    /// <summary>
    /// Builds a comma-separated argument string from the primary-key parameters only.
    /// Used as the argument list for Record.Get() in the generated Insert procedure.
    /// </summary>
    procedure GetPrimaryKeyGetArgs(Params: List of [Codeunit "CodeGen Variable"]): Text
    var
        Param: Codeunit "CodeGen Variable";
        Result: TextBuilder;
    begin
        foreach Param in Params do
            if Param.GetIsPrimaryKey() then begin
                if Result.ToText() <> '' then
                    Result.Append(', ');
                Result.Append(Param.GetName());
            end;
        exit(Result.ToText());
    end;

    /// <summary>
    /// Returns the ordered parameter list for a table's Insert procedure.
    /// Primary-key fields come first, then non-PK fields whose Behavior is not Exclude,
    /// both groups sorted by the configured Sort Order.
    /// </summary>
    procedure GetParametersForTable(TableSelection: Record SimonOfHH.DemoData.Model."Table Selection"): List of [Codeunit "CodeGen Variable"]
    var
        FieldConfig: Record SimonOfHH.DemoData.Model."Field Configuration";
        IdentifierHelper: Codeunit "Identifier Helper";
        ParamVar: Codeunit "CodeGen Variable";
        Parameters: List of [Codeunit "CodeGen Variable"];
    begin
        // Parameters: PK fields first
        FieldConfig.SetRange("Module Code", TableSelection."Module Code");
        FieldConfig.SetRange("Table ID", TableSelection."Table ID");
        FieldConfig.SetRange("Is Primary Key", true);
        FieldConfig.SetCurrentKey("Module Code", "Table ID", "Sort Order");
        if FieldConfig.FindSet() then
            repeat
                Clear(ParamVar);
                ParamVar.Init(
                    IdentifierHelper.GetParameterName(FieldConfig."Field Name"),
                    FieldConfig."Data Type", FieldConfig."Data Length", FieldConfig."Data Subtype", '');
                ParamVar.SetPrimaryKey(true);
                ParamVar.SetOriginalFieldname(FieldConfig."Field Name");
                Parameters.Add(ParamVar);
            until FieldConfig.Next() = 0;

        // Parameters: non-PK included fields
        FieldConfig.SetRange("Is Primary Key", false);
        FieldConfig.SetFilter(Behavior, '<>%1', FieldConfig.Behavior::Exclude);
        if FieldConfig.FindSet() then
            repeat
                Clear(ParamVar);
                ParamVar.Init(
                    IdentifierHelper.GetParameterName(FieldConfig."Field Name"),
                    FieldConfig."Data Type", FieldConfig."Data Length", FieldConfig."Data Subtype", '');
                ParamVar.SetOriginalFieldname(FieldConfig."Field Name");
                Parameters.Add(ParamVar);
            until FieldConfig.Next() = 0;
        exit(Parameters);
    end;
    /// <summary>
    /// Generates a Validate line for a field assignment.
    /// </summary>
    procedure ValidateFieldLine(RecVarName: Text; FieldName: Text; ParamName: Text): Text
    begin
#pragma warning disable AA0217
        exit(StrSubstNo('%1.Validate("%2", %3);', RecVarName, FieldName, ParamName));
#pragma warning restore AA0217
    end;

    procedure GetEvaluateDateFormulaProcedureName(): Text
    begin
        exit('EvaluateDateFormula');
    end;

    procedure GetDateFormulaValueCall(NewDateFormulaValueAsText: Text): Text
    var
        ProcedureCallPlaceholderLbl: Label '%1(%2)', Comment = '%1=Procedure name, %2=Date formula';
    begin
        exit(StrSubstNo(ProcedureCallPlaceholderLbl, this.GetEvaluateDateFormulaProcedureName(), NewDateFormulaValueAsText));
    end;

    /// <summary>
    /// Generates an AL date expression relative to WorkDate() or with a substituted year,
    /// depending on the chosen RelativeDateOption.
    /// Returns expressions like "WorkDate()", "CalcDate('&lt;-30D&gt;', WorkDate())", or
    /// "DMY2Date(15, 3, Date2DMY(WorkDate(), 3))" that the generated codeunit can compile directly.
    /// </summary>
    procedure GetRelativeDateValueCall(DateValue: Date; RelativeDateOption: Enum "Relative Date Option"): Text
    var
        DaysDifference: Integer;
        DateFormula, ReturnValue : Text;
        CalcDatePlaceholderLbl: Label 'CalcDate(%1, %2)', Comment = '%1=Date formula, %2=Base date (e.g., WorkDate())';
        Date2DMYPlaceholderLbl: Label 'Date2DMY(%1, %2)', Comment = '%1=Date value, %2=Part to extract (1=Day, 2=Month, 3=Year)';
        DMY2DatePlaceholderLbl: Label 'DMY2Date(%1, %2, %3)', Comment = '%1=Day value, %2=Month value, %3=Year value';
    begin
        if RelativeDateOption = Enum::"Relative Date Option"::"Replace with WorkDate" then
            exit('WorkDate()');
        if DateValue = 0D then
            exit('0D');
        if RelativeDateOption = Enum::"Relative Date Option"::"Relative to WorkDate" then begin
            DaysDifference := DateValue - WorkDate();
            if DaysDifference = 0 then
                exit('WorkDate()');
#pragma warning disable AA0217
            if DaysDifference > 0 then
                DateFormula := StrSubstNo('<+%1D>', Abs(DaysDifference));
            if DaysDifference < 0 then
                DateFormula := StrSubstNo('<-%1D>', Abs(DaysDifference));
#pragma warning restore AA0217
            exit(StrSubstNo(CalcDatePlaceholderLbl, this.ALFormatter.AddSingleQuotes(DateFormula), 'WorkDate()'));
        end;
        if RelativeDateOption = Enum::"Relative Date Option"::"Replace Year with WorkDate-Year" then
            ReturnValue := StrSubstNo(DMY2DatePlaceholderLbl,
                Date2DMY(DateValue, 1),
                Date2DMY(DateValue, 2),
                StrSubstNo(Date2DMYPlaceholderLbl, 'WorkDate()', 3));
        if RelativeDateOption = Enum::"Relative Date Option"::"Replace Month and Year with WorkDate-Month and Year" then
            ReturnValue := StrSubstNo(DMY2DatePlaceholderLbl,
                Date2DMY(DateValue, 1),
                StrSubstNo(Date2DMYPlaceholderLbl, 'WorkDate()', 2),
                StrSubstNo(Date2DMYPlaceholderLbl, 'WorkDate()', 3));
        exit(ReturnValue);
    end;

    procedure GetEvaluateDateFormulaProcedure() Proc: Codeunit "CodeGen Procedure"
    var
        Parameter: Codeunit "CodeGen Variable";
        Variable: Codeunit "CodeGen Variable";
    begin
        Parameter.Init('DateFormulaAsText', 'Text', 0, '', '');
        Variable.Init('Result', 'DateFormula', 0, '', '');
        Proc.Init(this.GetEvaluateDateFormulaProcedureName());
        Proc.AddParameter(Parameter);
        Proc.AddLocalVariable(Variable);
        Proc.SetReturn('DateFormula', '');
        Proc.AddCodeLine('if Evaluate(Result, DateFormulaAsText) then');
        Proc.AddCodeLine('    exit(Result);');
    end;
}
