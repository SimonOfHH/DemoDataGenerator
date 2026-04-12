namespace SimonOfHH.DemoData.Model;

enum 70103 "Relative Date Option"
{
    Extensible = false;

    value(0; "None")
    {
        Caption = ' ';
    }
    value(1; "Relative to WorkDate")
    {
        Caption = 'Relative to WorkDate';
    }
    value(2; "Replace Year with WorkDate-Year")
    {
        Caption = 'Replace Year with WorkDate-Year';
    }
    value(3; "Replace Month and Year with WorkDate-Month and Year")
    {
        Caption = 'Replace Month and Year with WorkDate-Month and Year';
    }
    value(4; "Replace with WorkDate")
    {
        Caption = 'Replace with WorkDate';
    }
}