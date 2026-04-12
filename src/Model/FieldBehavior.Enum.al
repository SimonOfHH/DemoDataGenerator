namespace SimonOfHH.DemoData.Model;

/// <summary>
/// Controls how a field is handled during code generation.
/// </summary>
enum 70101 "Field Behavior"
{
    Extensible = false;

    value(0; Include)
    {
        Caption = 'Include';
    }
    value(1; "Dynamic Field")
    {
        Caption = 'Dynamic Field';
    }
    value(2; "Label Field")
    {
        Caption = 'Label Field';
    }
    value(3; "Procedure with Token-Label")
    {
        Caption = 'Procedure with Token-Label';
    }
    value(8; "Reference Value")
    {
        Caption = 'Reference Value';
    }
    value(10; Exclude)
    {
        Caption = 'Exclude';
    }
}
