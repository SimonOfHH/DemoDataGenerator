namespace SimonOfHH.DemoData.Model;

/// <summary>
/// Reconciliation state of a "Code Segment" as of the most recent sync/export.
/// </summary>
enum 70107 "Code Segment Status"
{
    Extensible = false;

    value(0; "Generated")
    {
        Caption = 'Generated';
    }
    value(1; "Modified")
    {
        Caption = 'Modified';
    }
    value(2; "Conflict")
    {
        Caption = 'Conflict';
    }
    value(3; "Orphaned")
    {
        Caption = 'Orphaned';
    }
    value(4; "Manual")
    {
        Caption = 'Manual';
    }
}
