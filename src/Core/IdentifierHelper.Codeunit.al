namespace SimonOfHH.DemoData.Core;

/// <summary>
/// Naming derivation logic for generated AL objects.
/// Converts table names and module names into standardized identifiers
/// following the Contoso Coffee Demo Dataset naming conventions.
/// </summary>
codeunit 70117 "Identifier Helper"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        ALFormatter: Codeunit "AL Formatter";

    /// <summary>
    /// Derives a clean entity name from a table name.
    /// E.g., "Bank Account" → "BankAccount"
    /// </summary>
    procedure GetEntityName(TableName: Text): Text
    begin
        exit(this.ALFormatter.ToPascalCase(TableName));
    end;

    /// <summary>
    /// Derives the Insert procedure name for a table.
    /// E.g., "Bank Account" → "InsertBankAccount"
    /// </summary>
    procedure GetInsertProcedureName(TableName: Text): Text
    begin
        exit('Insert' + this.ALFormatter.ToPascalCase(TableName));
    end;

    /// <summary>
    /// Derives the data creation codeunit name for a table.
    /// E.g., "Bank Account" → "Create Bank Account"
    /// </summary>
    procedure GetCreateCodeunitName(TableName: Text): Text
    begin
        exit(this.ALFormatter.SanitizeTableName('Create ' + TableName));
    end;

    /// <summary>
    /// Derives the helper codeunit name from a group name.
    /// E.g., "Bank" → "Contoso Bank"
    /// </summary>
    procedure GetHelperCodeunitName(HelperPrefix: Text; GroupName: Text): Text
    begin
        exit(HelperPrefix + ' ' + GroupName);
    end;

    /// <summary>
    /// Derives the module codeunit name from a module name.
    /// E.g., "Bank" → "Bank Module"
    /// </summary>
    procedure GetModuleCodeunitName(ModuleName: Text): Text
    begin
        exit(ModuleName + ' Module');
    end;

    /// <summary>
    /// Derives the enum extension name from a module name.
    /// E.g., "Bank" → "Bank Module Enum"
    /// </summary>
    procedure GetEnumExtensionName(ModuleName: Text): Text
    begin
        exit(ModuleName + ' Module Enum');
    end;

    /// <summary>
    /// Derives a record variable name from a table name.
    /// E.g., "Bank Account" → "BankAccount" (same as entity name, used as local var)
    /// </summary>
    procedure GetRecordVarName(TableName: Text): Text
    begin
        exit(this.ALFormatter.ToPascalCase(TableName));
    end;

    /// <summary>
    /// Derives a clean parameter name from a field name.
    /// E.g., "No." → "No", "Country/Region Code" → "CountryRegionCode"
    /// </summary>
    procedure GetParameterName(FieldName: Text): Text
    begin
        exit(this.ALFormatter.ToPascalCase(FieldName));
    end;

    /// <summary>
    /// Derives a label variable name from a value.
    /// E.g., "CHECKING" → "CheckingTok"
    /// </summary>
    procedure GetLabelVarName(Value: Text): Text
    begin
        // Append "Tok" to indicate this is a label token variable
        exit(this.GetIdentifierName(Value) + 'Tok');
    end;

    /// <summary>
    /// Derives a label accessor procedure name from a value.
    /// E.g., "CHECKING" → "Checking"
    /// </summary>
    procedure GetLabelAccessorName(Value: Text): Text
    begin
        exit(this.GetIdentifierName(Value));
    end;

    /// <summary>
    /// Converts a raw name into a valid AL identifier: sanitizes special characters,
    /// applies PascalCase, and prefixes with an underscore when the name starts with a digit.
    /// </summary>
    procedure GetIdentifierName(BaseName: Text): Text
    var
        CleanValue: Text;
    begin
        CleanValue := this.ALFormatter.SanitizeIdentifier(BaseName);
        CleanValue := this.ALFormatter.ToPascalCase(CleanValue);
        // If the value starts with a number, prefix with an underscore to make it a valid identifier, e.g. "223344" → "_223344"
        if (CleanValue <> '') and (CleanValue[1] >= '0') and (CleanValue[1] <= '9') then
            CleanValue := '_' + CleanValue;
        exit(CleanValue);
    end;
}
