namespace SimonOfHH.DemoData.CodeGen;

using SimonOfHH.DemoData.Core;

/// <summary>
/// In-memory AST node representing a cross-table reference value.
/// Generates helper procedures in the helper codeunit that return
/// a referenced field value by table ID, field ID, and value.
/// </summary>
codeunit 70119 "CodeGen Reference Value"
{

    InherentEntitlements = X;
    InherentPermissions = X;

    var
        ALFormatter: Codeunit "AL Formatter";
        RefTableId: Integer;
        RefFieldId: Integer;
        RefValue: Variant;

    procedure Init(NewTableId: Integer; NewFieldId: Integer; NewValue: Variant): Codeunit "CodeGen Reference Value"
    begin
        this.RefTableId := NewTableId;
        this.RefFieldId := NewFieldId;
        this.RefValue := NewValue;
        exit(this);
    end;

    procedure TableId(): Integer
    begin
        exit(this.RefTableId);
    end;

    procedure FieldId(): Integer
    begin
        exit(this.RefFieldId);
    end;

    procedure Value(): Variant
    begin
        exit(this.RefValue);
    end;

    /// <summary>
    /// Returns a procedure call expression (e.g. "HelperCU.Get18_1_CUST001()") that resolves this
    /// reference value at runtime via the helper codeunit. The procedure name is deterministic,
    /// built from the referenced table ID, field ID, and sanitized value.
    /// </summary>
    /// <param name="HelperCUName">Name of the helper codeunit variable that hosts the reference getter.</param>
    procedure GetAsArgParameter(HelperCUName: Text): Text
    var
        FormattedValue: Text;
        PlaceholderLbl: Label '%1.Get%2_%3_%4()', Comment = '%1 = Helper Codeunit Name, %2 = Ref Table ID, %3 = Ref Field ID, %4 = Ref Value';
    begin
        // All reference values are basically "saved" into the Helper codeunit as procedures that return the value, so the argument passed to the generated code is a call to that helper procedure
        // We need a unified way to generate the name of that helper procedure, which is what this function does
        // TODO: Think about using the actual values instead of table and field IDs in the helper procedure names for better readability. Would require some extra work to ensure uniqueness and handle special characters, but could be worth it.
        FormattedValue := StrSubstNo(PlaceholderLbl, HelperCUName, this.RefTableId, this.RefFieldId, this.GetFormattedAndSanitizedValue(this.RefTableId, this.RefFieldId, this.RefValue));
        exit(FormattedValue);
    end;

    /// <summary>
    /// Convenience overload: initializes this node with the given reference coordinates and
    /// immediately returns the procedure call expression.
    /// </summary>
    /// <param name="HelperCUName">Name of the helper codeunit variable that hosts the reference getter.</param>
    /// <param name="NewRefTableId">Table ID of the referenced record.</param>
    /// <param name="NewRefFieldId">Field ID of the referenced field.</param>
    /// <param name="NewRefValue">The concrete field value to look up at runtime.</param>
    procedure GetAsArgParameter(HelperCUName: Text; NewRefTableId: Integer; NewRefFieldId: Integer; NewRefValue: Variant): Text
    begin
        this.Init(NewRefTableId, NewRefFieldId, NewRefValue);
        exit(this.GetAsArgParameter(HelperCUName));
    end;

    local procedure GetFormattedAndSanitizedValue(NewRefTableId: Integer; NewRefFieldId: Integer; NewRefValue: Variant): Text
    var
        FormattedValue: Text;
    begin
        // Format the value as it would appear in AL code, then sanitize it to ensure it's a valid identifier if we want to use it in a procedure name
        FormattedValue := this.ALFormatter.FormatValue(this.GetAsFldRef(NewRefTableId, NewRefFieldId, NewRefValue));
        FormattedValue := this.ALFormatter.SanitizeIdentifier(FormattedValue);
        exit(FormattedValue);
    end;

    local procedure GetAsFldRef(): FieldRef
    begin
        exit(this.GetAsFldRef(this.RefTableId, this.RefFieldId, this.RefValue));
    end;

    local procedure GetAsFldRef(NewRefTableId: Integer; NewRefFieldId: Integer; NewRefValue: Variant): FieldRef
    var
        RecRef: RecordRef;
        FldRef: FieldRef;
    begin
        RecRef.Open(NewRefTableId);
        FldRef := RecRef.Field(NewRefFieldId);
        FldRef.Value := NewRefValue;
        exit(FldRef);
    end;

    procedure ToString(IndentLevel: Integer): Text
    var
        ProcedurePlaceholderLbl: Label 'procedure Get%1_%2_%3(): %4', Comment = '%1 = Helper Codeunit Name, %2 = Ref Table ID, %3 = Ref Field ID, %4 = Ref Value Data Type';
        ReturnValuePlaceholderLbl: Label 'exit(%1);', Comment = '%1 = Ref Value as AL literal';
        Result: TextBuilder;
        Indent: Text;
    begin
        Indent := Indent.PadLeft(IndentLevel * 4); // 4 spaces per indent level
        Result.AppendLine(Indent + StrSubstNo(ProcedurePlaceholderLbl, this.RefTableId, this.RefFieldId, this.GetFormattedAndSanitizedValue(this.RefTableId, this.RefFieldId, this.RefValue), this.ALFormatter.GetTypeString(this.GetAsFldRef())));
        Result.AppendLine(Indent + 'begin');
        Result.AppendLine(Indent + Indent + StrSubstNo(ReturnValuePlaceholderLbl, this.ALFormatter.FormatValue(this.GetAsFldRef(this.RefTableId, this.RefFieldId, this.RefValue))));
        Result.AppendLine(Indent + 'end;');
        Result.AppendLine('');
        exit(Result.ToText());
    end;
}