namespace SimonOfHH.DemoData.Model;

/// <summary>
/// Indicates the role a table plays within a Document Group — the header
/// table (e.g. Sales Header) or one of its line/child tables (e.g. Sales Line).
/// </summary>
enum 70104 "Document Group Role"
{
    Extensible = false;

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; Header)
    {
        Caption = 'Header';
    }
    value(2; Line)
    {
        Caption = 'Line';
    }
}
