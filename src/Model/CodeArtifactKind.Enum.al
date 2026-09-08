namespace SimonOfHH.DemoData.Model;

/// <summary>
/// Identifies which generated output file a "Code Segment" belongs to.
/// </summary>
enum 70105 "Code Artifact Kind"
{
    Extensible = false;

    value(0; "App Manifest")
    {
        Caption = 'App Manifest';
    }
    value(1; "Enum Extension")
    {
        Caption = 'Enum Extension';
    }
    value(2; "Module Codeunit")
    {
        Caption = 'Module Codeunit';
    }
    value(3; "Helper Codeunit")
    {
        Caption = 'Helper Codeunit';
    }
    value(4; "Data Codeunit")
    {
        Caption = 'Data Codeunit';
    }
    value(5; "Document Stub Codeunit")
    {
        Caption = 'Document Stub Codeunit';
    }
}
