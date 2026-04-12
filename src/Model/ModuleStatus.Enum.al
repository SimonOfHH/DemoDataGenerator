namespace SimonOfHH.DemoData.Model;

/// <summary>
/// Tracks the progress of a module definition.
/// </summary>
enum 70102 "Module Status"
{
    Extensible = false;

    value(0; Draft)
    {
        Caption = 'Draft';
    }
    value(1; Ready)
    {
        Caption = 'Ready';
    }
    value(2; Generated)
    {
        Caption = 'Generated';
    }
}
