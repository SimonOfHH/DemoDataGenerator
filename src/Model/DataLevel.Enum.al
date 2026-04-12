namespace SimonOfHH.DemoData.Model;

/// <summary>
/// Maps to the Contoso Coffee Demo Dataset data levels.
/// Determines at which stage of demo data generation a table's data is created.
/// </summary>
enum 70100 "Data Level"
{
    Extensible = false;

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; "Setup Data")
    {
        Caption = 'Setup Data';
    }
    value(2; "Master Data")
    {
        Caption = 'Master Data';
    }
    value(3; "Transaction Data")
    {
        Caption = 'Transaction Data';
    }
    value(4; "Historical Data")
    {
        Caption = 'Historical Data';
    }
}
