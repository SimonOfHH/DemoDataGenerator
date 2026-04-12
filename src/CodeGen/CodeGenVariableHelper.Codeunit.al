namespace SimonOfHH.DemoData.CodeGen;

/// <summary>
/// Factory methods for creating CodeGen Variable and CodeGen Reference Value instances.
/// Provides a convenient one-call construction pattern used by generators.
/// </summary>
codeunit 70125 "CodeGen Variable Helper"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    procedure GetReferenceValue(TableId: Integer; FieldId: Integer; Value: Variant): Codeunit "CodeGen Reference Value"
    var
        RefValue: Codeunit "CodeGen Reference Value";
    begin
        RefValue := RefValue.Init(TableId, FieldId, Value);
        exit(RefValue);
    end;

    procedure GetVariable(NewName: Text; NewDataType: Text; NewDataLength: Integer; NewDataSubtype: Text; NewValue: Text): Codeunit "CodeGen Variable"
    var
        Variable: Codeunit "CodeGen Variable";
    begin
        Variable.Init(NewName, NewDataType, NewDataLength, NewDataSubtype, NewValue);
        exit(Variable);
    end;
}