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
            if not this.ContainsReferenceValue(RefValue.TableId(), RefValue.FieldId(), RefValue.Value()) then
                this.AddReferenceValue(RefValue);
    end;

    procedure AddReferenceValue(NewRefTableId: Integer; NewRefFieldId: Integer; NewRefValue: Variant)
    var
        RefValue: Codeunit "CodeGen Reference Value";
    begin
        RefValue.Init(NewRefTableId, NewRefFieldId, NewRefValue);
        if not this.ContainsReferenceValue(NewRefTableId, NewRefFieldId, NewRefValue) then
            this.AddReferenceValue(RefValue);
    end;

    procedure AddReferenceValue(RefValue: Codeunit "CodeGen Reference Value")
    begin
        if not this.ContainsReferenceValue(RefValue.TableId(), RefValue.FieldId(), RefValue.Value()) then
            this.ReferenceValues.Add(RefValue);
    end;

    /// <summary>
    /// Checks whether a reference value with the same derived getter procedure name already exists.
    /// Comparing the derived NAME (table ID + field ID + sanitized value + content hash) rather than
    /// the raw value is what actually guarantees no duplicate procedure is ever emitted — see
    /// "CodeGen Reference Value".ProcedureName for why a raw-value comparison is not sufficient.
    /// </summary>
    procedure ContainsReferenceValue(TableId: Integer; FieldId: Integer; FldValue: Variant): Boolean
    var
        RefValue: Codeunit "CodeGen Reference Value";
        CandidateRefValue: Codeunit "CodeGen Reference Value";
        CandidateName: Text;
    begin
        CandidateRefValue.Init(TableId, FieldId, FldValue);
        CandidateName := CandidateRefValue.ProcedureName();
        foreach RefValue in this.ReferenceValues do
            if RefValue.ProcedureName() = CandidateName then
                exit(true);
        exit(false);
    end;

    procedure ToIdentifierString(): Text
    begin
        exit(this.BaseObject.ToIdentifierString());
    end;

    // ═══════════════════════ Segment-aware accessors (Code Segment Store) ═══════════════════════
    // These do NOT change ToString()'s output - they are an independent, additional read API used
    // by "Segment Sync Manager" to snapshot this codeunit's content per-segment. ToString() keeps
    // building its output the original way so its (already working, already relied upon) exact
    // whitespace/blank-line behavior cannot regress.

    /// <summary>
    /// Returns the file header text: namespace, usings, object declaration, opening brace, and
    /// properties. Corresponds to the "File Header" Code Segment.
    /// </summary>
    procedure GetHeaderText(): Text
    var
        Writer: Codeunit "CodeGen Writer";
    begin
        Writer.WriteBaseObject(this.BaseObject);
        exit(Writer.ToText());
    end;

    /// <summary>
    /// Returns the closing brace text. Corresponds to the "File Footer" Code Segment.
    /// </summary>
    procedure GetFooterText(): Text
    begin
        exit('}');
    end;

    /// <summary>
    /// Returns the `var` section text (global variables and label declarations), or '' if there
    /// is none. Corresponds to the "Global Variable" Code Segment - kept as ONE segment rather
    /// than one per variable, since generators accumulate globals incrementally while building
    /// procedures and do not track which variable belongs to which logical unit.
    /// </summary>
    procedure GetVarSectionText(): Text
    var
        Writer: Codeunit "CodeGen Writer";
    begin
        if (this.GlobalVariables.Count = 0) and (this.LabelDeclarations.Count = 0) then
            exit('');
        Writer.IncreaseIndent();
        Writer.WriteGlobalVariables(this.GlobalVariables, this.LabelDeclarations);
        Writer.DecreaseIndent();
        exit(Writer.ToText());
    end;

    /// <summary>
    /// Returns the trigger procedures (e.g. OnRun) in declared order. Each corresponds to one
    /// "Trigger" Code Segment.
    /// </summary>
    procedure GetTriggerProcedures(): List of [Codeunit "CodeGen Procedure"]
    var
        ProcedureObject: Codeunit "CodeGen Procedure";
        Result: List of [Codeunit "CodeGen Procedure"];
    begin
        foreach ProcedureObject in this.Procedures do
            if ProcedureObject.GetTrigger() then
                Result.Add(ProcedureObject);
        exit(Result);
    end;

    /// <summary>
    /// Returns the non-trigger procedures in declared order. Each corresponds to one
    /// "Procedure" Code Segment.
    /// </summary>
    procedure GetRegularProcedures(): List of [Codeunit "CodeGen Procedure"]
    var
        ProcedureObject: Codeunit "CodeGen Procedure";
        Result: List of [Codeunit "CodeGen Procedure"];
    begin
        foreach ProcedureObject in this.Procedures do
            if not ProcedureObject.GetTrigger() then
                Result.Add(ProcedureObject);
        exit(Result);
    end;

    /// <summary>
    /// Returns the reference-value getter procedures. Each corresponds to one
    /// "Reference Value" Code Segment, keyed by "CodeGen Reference Value".ProcedureName()
    /// (already collision-safe - see that procedure's remarks).
    /// </summary>
    procedure GetReferenceValues(): List of [Codeunit "CodeGen Reference Value"]
    begin
        exit(this.ReferenceValues);
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
