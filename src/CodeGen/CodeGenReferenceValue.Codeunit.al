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
    /// Returns a procedure call expression (e.g. "HelperCU.Get18_1_CUST001_A1B2C3D4()") that resolves
    /// this reference value at runtime via the helper codeunit. The procedure name is deterministic,
    /// built from the referenced table ID, field ID, sanitized value, and a content hash of the raw
    /// value (see <see cref="ProcedureName"/> for why the hash is required).
    /// </summary>
    /// <param name="HelperCUName">Name of the helper codeunit variable that hosts the reference getter.</param>
    procedure GetAsArgParameter(HelperCUName: Text): Text
    var
        PlaceholderLbl: Label '%1.%2()', Comment = '%1 = Helper Codeunit Name, %2 = Procedure Name';
    begin
        // All reference values are basically "saved" into the Helper codeunit as procedures that return the value, so the argument passed to the generated code is a call to that helper procedure
        exit(StrSubstNo(PlaceholderLbl, HelperCUName, this.ProcedureName()));
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

    /// <summary>
    /// Returns the deterministic getter procedure name for this reference value, e.g.
    /// "Get18_1_CUST001_A1B2C3D4". The sanitized value alone is NOT sufficient to guarantee
    /// uniqueness: SanitizeIdentifier drops every non-alphanumeric character, so distinct raw
    /// values such as "1200.5"/"120.05" or "A-1"/"A1" collapse to the same sanitized text. An
    /// 8-character content hash of the raw formatted value is therefore appended to keep names
    /// unique. A hash (not a sequence counter) is used deliberately: it is order-independent, so
    /// the name for a given value never changes when other reference values are added or removed.
    /// </summary>
    procedure ProcedureName(): Text
    begin
        exit(this.GetProcedureName(this.RefTableId, this.RefFieldId, this.RefValue));
    end;

    local procedure GetProcedureName(NewRefTableId: Integer; NewRefFieldId: Integer; NewRefValue: Variant): Text
    var
        NameLbl: Label 'Get%1_%2_%3_%4', Comment = '%1 = Ref Table ID, %2 = Ref Field ID, %3 = Sanitized Value, %4 = Content Hash', Locked = true;
    begin
        exit(
            StrSubstNo(
                NameLbl,
                NewRefTableId,
                NewRefFieldId,
                this.GetFormattedAndSanitizedValue(NewRefTableId, NewRefFieldId, NewRefValue),
                this.GetValueHash(NewRefTableId, NewRefFieldId, NewRefValue)));
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

    /// <summary>
    /// Returns an 8-character hexadecimal hash of the raw (unsanitized) formatted value, used to
    /// disambiguate reference-getter procedure names whose sanitized value text would otherwise
    /// collide.
    /// </summary>
    local procedure GetValueHash(NewRefTableId: Integer; NewRefFieldId: Integer; NewRefValue: Variant): Text
    var
        RawFormattedValue: Text;
    begin
        RawFormattedValue := this.ALFormatter.FormatValue(this.GetAsFldRef(NewRefTableId, NewRefFieldId, NewRefValue));
        exit(this.ComputeShortHash(RawFormattedValue));
    end;

    /// <summary>
    /// Computes a short, deterministic, order-independent 8-character hexadecimal fingerprint of
    /// the given text using two Adler-32-style rolling checksums, each kept modulo 65521 at every
    /// step so plain 32-bit Integer arithmetic never overflows. Self-contained on purpose: it
    /// avoids any dependency on the "Cryptography Management" codeunit's inline Option parameter
    /// (whose ordinal values are not part of its public contract).
    /// </summary>
    local procedure ComputeShortHash(Input: Text): Text
    var
        ModuloValue: Integer;
        ChecksumA: Integer;
        ChecksumB: Integer;
        CharCode: Integer;
        i: Integer;
    begin
        ModuloValue := 65521; // largest prime below 2^16 - standard Adler-32 modulus
        ChecksumA := 1;
        ChecksumB := 0;
        for i := 1 to StrLen(Input) do begin
            CharCode := Input[i];
            ChecksumA := (ChecksumA + CharCode) mod ModuloValue;
            ChecksumB := (ChecksumB + ChecksumA) mod ModuloValue;
        end;
        exit(this.ToHex4(ChecksumA) + this.ToHex4(ChecksumB));
    end;

    local procedure ToHex4(Value: Integer): Text
    var
        HexDigits: Text;
        Result: Text;
        Nibble: Integer;
        i: Integer;
    begin
        HexDigits := '0123456789ABCDEF';
        for i := 1 to 4 do begin
            Nibble := Value mod 16;
            Result := CopyStr(HexDigits, Nibble + 1, 1) + Result;
            Value := Value div 16;
        end;
        exit(Result);
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
        ProcedurePlaceholderLbl: Label 'procedure %1(): %2', Comment = '%1 = Procedure Name, %2 = Ref Value Data Type';
        ReturnValuePlaceholderLbl: Label 'exit(%1);', Comment = '%1 = Ref Value as AL literal';
        Result: TextBuilder;
        Indent: Text;
    begin
        Indent := Indent.PadLeft(IndentLevel * 4); // 4 spaces per indent level
        Result.AppendLine(Indent + StrSubstNo(ProcedurePlaceholderLbl, this.ProcedureName(), this.ALFormatter.GetTypeString(this.GetAsFldRef())));
        Result.AppendLine(Indent + 'begin');
        Result.AppendLine(Indent + Indent + StrSubstNo(ReturnValuePlaceholderLbl, this.ALFormatter.FormatValue(this.GetAsFldRef(this.RefTableId, this.RefFieldId, this.RefValue))));
        Result.AppendLine(Indent + 'end;');
        exit(Result.ToText());
    end;
}