namespace SimonOfHH.DemoData.Model;

/// <summary>
/// Identifies which part of a generated AL file a "Code Segment" represents.
/// </summary>
enum 70106 "Code Segment Kind"
{
    Extensible = false;

    value(0; "File Header")
    {
        Caption = 'File Header';
    }
    value(1; "Property")
    {
        Caption = 'Property';
    }
    value(2; "Global Variable")
    {
        Caption = 'Global Variable';
    }
    value(3; "Label")
    {
        Caption = 'Label';
    }
    value(4; "Trigger")
    {
        Caption = 'Trigger';
    }
    value(5; "Procedure")
    {
        Caption = 'Procedure';
    }
    value(6; "Reference Value")
    {
        Caption = 'Reference Value';
    }
    value(7; "File Footer")
    {
        Caption = 'File Footer';
    }
    value(8; "Manual Block")
    {
        Caption = 'Manual Block';
    }
}
