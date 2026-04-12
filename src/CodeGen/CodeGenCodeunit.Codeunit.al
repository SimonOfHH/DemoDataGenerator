namespace SimonOfHH.DemoData.CodeGen;

/// <summary>
/// In-memory AST node representing a complete AL codeunit file.
/// Holds properties, global variables, and procedures. Serializes to a complete .al file.
/// </summary>
codeunit 70112 "CodeGen Codeunit"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        BaseObject: Codeunit "CodeGen Base Object";
        TableDataLevel: Enum SimonOfHH.DemoData.Model."Data Level";
        Procedures: List of [Codeunit "CodeGen Procedure"];
        GlobalVariables: List of [Codeunit "CodeGen Variable"];
        ReferenceValues: List of [Codeunit "CodeGen Reference Value"];
        LabelDeclarations: List of [Text];

    procedure Initialize(NewId: Integer; NewName: Text)
    begin
        this.Initialize(NewId, NewName, '');
    end;

    procedure Initialize(NewId: Integer; NewName: Text; NewImplements: Text)
    begin
        this.BaseObject.InitializeCodeunit(NewId, NewName, NewImplements);
    end;

    procedure DataLevel(NewDataLevel: Enum SimonOfHH.DemoData.Model."Data Level")
    begin
        this.TableDataLevel := NewDataLevel;
    end;

    procedure DataLevel(): Enum SimonOfHH.DemoData.Model."Data Level"
    begin
        exit(this.TableDataLevel);
    end;

    procedure Implements(InterfaceName: Text)
    begin
        this.BaseObject.Implements(InterfaceName);
    end;

    procedure Namespace(NewNamespace: Text)
    begin
        this.BaseObject.Namespace(NewNamespace);
    end;

    procedure AddUsing(Using: Text)
    begin
        this.BaseObject.AddUsing(Using);
    end;

    procedure Id(): Integer
    begin
        exit(this.BaseObject.Id());
    end;

    procedure Name(): Text
    begin
        exit(this.BaseObject.Name());
    end;

    procedure AddProperty("Key": Text; Value: Text)
    begin
        this.BaseObject.AddProperty("Key", Value);
    end;

    procedure AddGlobalVariable(Variable: Codeunit "CodeGen Variable")
    begin
        if not this.GlobalVariableAlreadyExists(Variable) then // TODO: check if we need to check values as well
            this.GlobalVariables.Add(Variable);
    end;

    /// <summary>
    /// Checks whether a global variable with the same name already exists in this codeunit.
    /// Comparison is name-only; value differences are ignored (duplicate names are suppressed).
    /// </summary>
    procedure GlobalVariableAlreadyExists(NewVariable: Codeunit "CodeGen Variable"): Boolean
    var
        Variable: Codeunit "CodeGen Variable";
    begin
        foreach Variable in this.GlobalVariables do
            if Variable.GetName() = NewVariable.GetName() then
                exit(true);
        exit(false);
    end;

    procedure AddProcedure(Proc: Codeunit "CodeGen Procedure")
    begin
        this.Procedures.Add(Proc);
    end;

    /// <summary>
    /// Adds a raw label declaration line to the var section.
    /// </summary>
    procedure AddLabelDeclaration(LabelLine: Text)
    begin
        this.LabelDeclarations.Add(LabelLine);
    end;

    procedure AddReferenceValues(RefValues: List of [Codeunit "CodeGen Reference Value"])
    var
        RefValue: Codeunit "CodeGen Reference Value";
    begin
        foreach RefValue in RefValues do
            this.AddReferenceValue(RefValue);
    end;

    procedure AddReferenceValue(NewRefTableId: Integer; NewRefFieldId: Integer; NewRefValue: Variant)
    var
        RefValue: Codeunit "CodeGen Reference Value";
    begin
        RefValue.Init(NewRefTableId, NewRefFieldId, NewRefValue);
        this.AddReferenceValue(RefValue);
    end;

    procedure AddReferenceValue(RefValue: Codeunit "CodeGen Reference Value")
    begin
        this.ReferenceValues.Add(RefValue);
    end;

    procedure ToIdentifierString(): Text
    begin
        exit(this.BaseObject.ToIdentifierString());
    end;

    /// <summary>
    /// Serializes the codeunit to a complete AL source file.
    /// </summary>
    procedure ToString(): Text
    var
        Writer: Codeunit "CodeGen Writer";
        ProcedureObject: Codeunit "CodeGen Procedure";
        ReferenceValue: Codeunit "CodeGen Reference Value";
        TriggerProcedures: List of [Codeunit "CodeGen Procedure"];
        RegularProcedures: List of [Codeunit "CodeGen Procedure"];
        HasVarSection: Boolean;
    begin
        Writer.WriteBaseObject(this.BaseObject);

        // Separate triggers from regular procedures
        foreach ProcedureObject in this.Procedures do
            // Triggers come first (OnRun, etc.)
            if ProcedureObject.GetTrigger() then
                TriggerProcedures.Add(ProcedureObject)
            else
                RegularProcedures.Add(ProcedureObject);

        // Triggers
        foreach ProcedureObject in TriggerProcedures do
            Writer.AppendLine(ProcedureObject.ToString(1));
        // Regular procedures
        foreach ProcedureObject in RegularProcedures do
            Writer.AppendLine(ProcedureObject.ToString(1));
        // Reference values (as helper procedures)
        foreach ReferenceValue in this.ReferenceValues do
            Writer.AppendLine(ReferenceValue.ToString(1));

        // Global variables section
        HasVarSection := (this.GlobalVariables.Count > 0) or (this.LabelDeclarations.Count > 0);
        if HasVarSection then begin
            Writer.IncreaseIndent();
            Writer.WriteGlobalVariables(this.GlobalVariables, this.LabelDeclarations);
            Writer.DecreaseIndent();
        end;

        Writer.AppendLine('}');
        exit(Writer.ToText());
    end;
}
