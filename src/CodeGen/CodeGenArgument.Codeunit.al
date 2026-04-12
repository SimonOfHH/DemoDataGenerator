namespace SimonOfHH.DemoData.CodeGen;

/// <summary>
/// In-memory AST node representing a procedure argument, variable, or label that can be converted to a 
/// Codeunit "CodeGen Procedure" or "CodeGen Variable" respectively. 
/// The Kind and SubKind properties determine which one it will be converted to, and what properties are expected to be filled in. 
/// This allows for a more flexible construction of code generation elements, as the same object can represent different 
/// kinds of elements based on its properties.
/// </summary>
codeunit 70118 "CodeGen Argument"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        ArgName, ArgType, ArgSubType, ArgReturnName, ArgReturnType, ArgReturnSubType, ArgAssociatedVariableName, ArgAssociatedVariableType, ArgAssociatedVariableSubType : Text;
        ArgTypeLength: Integer;
        ArgValue: Variant;
        ArgIsLocked: Boolean;
        ArgKind: Option GlobalVariable,"Procedure";
        ArgSubKind: Option DynamicField,LabelField,"Procedure with Token-Label";

    procedure Name(ReturnBaseName: Boolean): Text
    begin
        if (this.ArgKind = this.ArgKind::"Procedure") and (this.ArgAssociatedVariableName <> '') and not ReturnBaseName then
            exit(this.ArgAssociatedVariableName);
        exit(this.ArgName);
    end;

    procedure Type(): Text
    begin
        exit(this.ArgType);
    end;

    procedure SubType(): Text
    begin
        exit(this.ArgSubType);
    end;

    procedure ReturnName(): Text
    begin
        exit(this.ArgReturnName);
    end;

    procedure ReturnType(): Text
    begin
        exit(this.ArgReturnType);
    end;

    procedure ReturnSubType(): Text
    begin
        exit(this.ArgReturnSubType);
    end;

    procedure TypeLength(): Integer
    begin
        exit(this.ArgTypeLength);
    end;

    procedure Value(): Variant
    begin
        exit(this.ArgValue);
    end;

    procedure AssociatedVariableName(): Text
    begin
        exit(this.ArgAssociatedVariableName);
    end;

    procedure IsProcedure(): Boolean
    begin
        exit(this.ArgKind = this.ArgKind::"Procedure");
    end;

    procedure IsGlobalVariable(): Boolean
    begin
        exit(this.ArgKind = this.ArgKind::GlobalVariable);
    end;

    procedure HasAssociatedVariable(): Boolean
    begin
        exit(this.ArgAssociatedVariableName <> '');
    end;

    /// <summary>
    /// Configures this node as a Dynamic Field — a placeholder procedure in the generated codeunit
    /// whose body the developer fills in manually after generation.
    /// </summary>
    /// <param name="NewName">Procedure name (derived from the field name).</param>
    /// <param name="NewType">AL data type of the field (currently unused; retained for future type validation).</param>
    /// <param name="NewTypeLength">Data length for Text/Code types (0 for other types).</param>
    /// <param name="NewValue">Placeholder value (currently unused; kept for consistency with other SetXxx methods).</param>
    /// <param name="NewReturnName">Display name of the return value (currently unused).</param>
    /// <param name="NewReturnType">Return type string for the generated procedure signature, e.g. "Text[100]".</param>
    procedure SetDynamicField(NewName: Text; NewType: Text; NewTypeLength: Integer; NewValue: Variant; NewReturnName: Text; NewReturnType: Text): Codeunit "CodeGen Argument"
    begin
        this.ArgName := NewName;
        this.ArgType := NewType;
        this.ArgTypeLength := NewTypeLength;
        this.ArgValue := NewValue;
        this.ArgReturnName := NewReturnName;
        this.ArgReturnType := NewReturnType;
        this.ArgKind := this.ArgKind::"Procedure";
        this.ArgSubKind := this.ArgSubKind::DynamicField;
        exit(this);
    end;

    /// <summary>
    /// Configures this node as a Label Field — a global Label variable (e.g. XyzTok) whose value
    /// is a text constant baked into the generated codeunit.
    /// </summary>
    /// <param name="NewName">Variable name for the label (typically suffixed with "Tok").</param>
    /// <param name="NewType">Always 'Label' for this kind.</param>
    /// <param name="NewTypeLength">Maximum length constraint (0 = unlimited).</param>
    /// <param name="NewValue">The literal text value assigned to the label.</param>
    /// <param name="NewIsLocked">When true, emits the Locked = true property on the label (suppresses translation).</param>
    procedure SetLabelField(NewName: Text; NewType: Text; NewTypeLength: Integer; NewValue: Variant; NewIsLocked: Boolean): Codeunit "CodeGen Argument"
    begin
        this.ArgName := NewName;
        this.ArgType := NewType;
        this.ArgTypeLength := NewTypeLength;
        this.ArgValue := NewValue;
        this.ArgIsLocked := NewIsLocked;
        this.ArgKind := this.ArgKind::GlobalVariable;
        this.ArgSubKind := this.ArgSubKind::LabelField;
        exit(this);
    end;

    /// <summary>
    /// Configures this node as a Procedure with Token-Label — generates both an accessor procedure
    /// (returning the label value) and an associated global Label variable (the "Tok" constant).
    /// Used when the Contoso pattern requires a procedure that returns a token label.
    /// </summary>
    /// <param name="NewName">Base identifier for the accessor procedure name.</param>
    /// <param name="NewType">Return type of the accessor procedure (e.g. 'Code', 'Text').</param>
    /// <param name="NewTypeLength">Length constraint for the return type.</param>
    /// <param name="NewValue">The literal text value assigned to the associated label variable.</param>
    /// <param name="NewAssociatedVariableName">Name of the global Label variable (typically suffixed with "Tok").</param>
    /// <param name="NewAssociatedVariableType">AL type for the label variable (always 'Label').</param>
    /// <param name="NewIsLocked">When true, emits the Locked = true property on the associated label.</param>
    procedure SetProcedureWithTokenLabelArgument(NewName: Text; NewType: Text; NewTypeLength: Integer; NewValue: Text; NewAssociatedVariableName: Text; NewAssociatedVariableType: Text; NewIsLocked: Boolean): Codeunit "CodeGen Argument"
    begin
        this.ArgName := NewName;
        this.ArgType := NewAssociatedVariableType;
        this.ArgTypeLength := NewTypeLength;
        this.ArgValue := NewValue;
        this.ArgKind := this.ArgKind::"Procedure";
        this.ArgSubKind := this.ArgSubKind::"Procedure with Token-Label";
        this.ArgIsLocked := NewIsLocked;
        this.ArgAssociatedVariableName := NewAssociatedVariableName;
        this.ArgAssociatedVariableType := NewAssociatedVariableType;
        this.ArgReturnType := NewType;
        if this.ArgTypeLength > 0 then
            this.ArgReturnType += StrSubstNo('[%1]', this.ArgTypeLength);
        exit(this);
    end;

    procedure ToProcedure(): Codeunit "CodeGen Procedure"
    var
        Proc: Codeunit "CodeGen Procedure";
    begin
        Proc.Init(this);
        exit(Proc);
    end;

    procedure ToVariable(): Codeunit "CodeGen Variable"
    var
        Variable: Codeunit "CodeGen Variable";
    begin
        Variable.Init(this.Name(false), this.Type(), this.TypeLength(), this.SubType(), this.Value());
        Variable.SetLocked(this.ArgIsLocked);
        exit(Variable);
    end;

    procedure AssociatedVariableToVariable(): Codeunit "CodeGen Variable"
    var
        Variable: Codeunit "CodeGen Variable";
    begin
        if not this.HasAssociatedVariable() then
            exit(Variable);
        Variable.Init(this.AssociatedVariableName(), this.ArgAssociatedVariableType, this.TypeLength(), this.ArgAssociatedVariableSubType, this.Value());
        Variable.SetLocked(this.ArgIsLocked);
        exit(Variable);
    end;
}