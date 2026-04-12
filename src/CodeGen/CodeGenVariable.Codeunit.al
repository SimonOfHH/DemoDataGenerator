namespace SimonOfHH.DemoData.CodeGen;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.Core;

/// <summary>
/// In-memory AST node representing a variable, parameter, or field value.
/// Used by CodeGen Procedure and CodeGen Codeunit to model AL code before serialization.
/// </summary>
codeunit 70110 "CodeGen Variable"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        ALFormatter: Codeunit "AL Formatter";
        VarName, VarCleanName, VarDataType, VarDataSubtype, VarValue, VarOriginalFieldname : Text;
        VarDataLength: Integer;
        VarIsVar, VarIsPrimaryKey, VarIsLocked, IsInitialized : Boolean;
        VarFieldBehavior: Enum "Field Behavior";
        VarSourceAppId: Guid;

    /// <summary>
    /// Initialize the variable with its type information.
    /// </summary>
    procedure Init(Name: Text; DataType: Text; DataLength: Integer; DataSubtype: Text; Value: Text)
    begin
        this.VarName := Name;
        this.VarCleanName := this.ALFormatter.SanitizeIdentifier(this.ALFormatter.ToPascalCase(Name));
        this.VarDataType := DataType;
        this.VarDataLength := DataLength;
        this.VarDataSubtype := DataSubtype;
        this.VarValue := Value;
        this.IsInitialized := true;
    end;

    procedure SetValue(Value: Text)
    begin
        this.VarValue := Value;
    end;

    procedure SetIsVar(NewIsVar: Boolean)
    begin
        this.VarIsVar := NewIsVar;
    end;

    procedure SetPrimaryKey(NewIsPK: Boolean)
    begin
        this.VarIsPrimaryKey := NewIsPK;
    end;

    procedure SetBehavior(NewBehavior: Enum "Field Behavior")
    begin
        this.VarFieldBehavior := NewBehavior;
    end;

    procedure SetLocked(NewIsLocked: Boolean)
    begin
        this.VarIsLocked := NewIsLocked;
    end;

    procedure SetSourceAppId(AppId: Guid)
    begin
        this.VarSourceAppId := AppId;
    end;

    procedure GetName(): Text
    begin
        exit(this.VarName);
    end;

    procedure GetCleanName(): Text
    begin
        exit(this.VarCleanName);
    end;

    procedure GetDataType(): Text
    begin
        exit(this.VarDataType);
    end;

    procedure GetDataLength(): Integer
    begin
        exit(this.VarDataLength);
    end;

    procedure GetDataSubtype(): Text
    begin
        exit(this.VarDataSubtype);
    end;

    procedure GetValue(): Text
    begin
        exit(this.VarValue);
    end;

    procedure GetIsVar(): Boolean
    begin
        exit(this.VarIsVar);
    end;

    procedure GetIsPrimaryKey(): Boolean
    begin
        exit(this.VarIsPrimaryKey);
    end;

    procedure GetBehavior(): Enum "Field Behavior"
    begin
        exit(this.VarFieldBehavior);
    end;

    procedure GetIsLocked(): Boolean
    begin
        exit(this.VarIsLocked);
    end;

    procedure GetSourceAppId(): Guid
    begin
        exit(this.VarSourceAppId);
    end;

    procedure SetOriginalFieldname(FieldName: Text)
    begin
        this.VarOriginalFieldname := FieldName;
    end;

    procedure GetOriginalFieldname(): Text
    begin
        exit(this.VarOriginalFieldname);
    end;

    /// <summary>
    /// Serializes as a parameter/variable declaration.
    /// E.g., "AccountNo: Code[20]" or "BankAccount: Record \"Bank Account\""
    /// </summary>
    procedure ToString(): Text
    var
        Result: TextBuilder;
        SingleQuoteChar: Text;
        MaxLengthPlaceholderLbl: Label 'MaxLength = %1', Comment = '%1 = Data Length', Locked = true;
    begin
        SingleQuoteChar := '''';
        if this.VarIsVar then
            Result.Append('var ');
        Result.Append(this.VarCleanName);
        Result.Append(': ');
        Result.Append(this.VarDataType);

        if this.VarDataSubtype <> '' then
            Result.Append(StrSubstNo(' "%1"', this.VarDataSubtype));

        if this.VarDataType = 'Label' then begin
            Result.Append(StrSubstNo(' %1%2%1', SingleQuoteChar, this.VarValue));
            if this.VarDataLength > 0 then
                Result.Append(', ' + StrSubstNo(MaxLengthPlaceholderLbl, this.VarDataLength));
            if this.VarIsLocked then
                Result.Append(', Locked = true');
        end;

        if this.NeedsLength() and (this.VarDataLength > 0) then
            Result.Append(StrSubstNo('[%1]', this.VarDataLength));

        exit(Result.ToText());
    end;

    /// <summary>
    /// Serializes as a Validate assignment line.
    /// E.g., BankAccount.Validate("Name", AccountName);
    /// </summary>
    procedure ToValidateString(RecordVarName: Text): Text
    var
        ValidatePlaceholderLbl: Label '%1.Validate("%2", %3)', Comment = '%1 = Record variable name, %2 = Field name, %3 = Variable clean name', Locked = true;
    begin
        exit(StrSubstNo(ValidatePlaceholderLbl, RecordVarName, this.VarName, this.VarCleanName));
    end;

    /// <summary>
    /// Returns the literal value formatted for AL source code.
    /// </summary>
    procedure ToValueLiteral(): Text
    begin
        exit(this.VarValue);
    end;

    /// <summary>
    /// Returns a PascalCase procedure name for dynamic field placeholders.
    /// </summary>
    procedure ToDynamicProcedureName(): Text
    begin
        exit(this.VarCleanName);
    end;

    local procedure NeedsLength(): Boolean
    begin
        exit(this.VarDataType in ['Code', 'Text']);
    end;
}
