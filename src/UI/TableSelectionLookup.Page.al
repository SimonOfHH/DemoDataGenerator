namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;

page 70106 "Table Selection Lookup"
{
    PageType = List;
    ApplicationArea = All;
    SourceTable = "Table Selection";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(TableSelectionRepeater)
            {
                field("Table ID"; Rec."Table ID")
                {
                    ToolTip = 'Specifies the ID of the selected table.';
                }
                field("Table Name"; Rec."Table Name")
                {
                    ToolTip = 'Name of the table.';
                }
                field("Data Level"; Rec."Data Level")
                {
                    ToolTip = 'Data level of the table.';
                }
                field("Helper Group"; Rec."Helper Group")
                {
                    ToolTip = 'Helper codeunit grouping key.';
                }
                field("AL Namespace"; Rec."AL Namespace")
                {
                    ToolTip = 'AL namespace for the generated code for this table.';
                }
            }
        }
    }
}