namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;

/// <summary>
/// Simple list page for Document Group records. Used as LookupPage/DrillDownPage for
/// the "Document Group Code" field on Table Selection.
/// </summary>
page 70110 "Document Group List"
{
    ApplicationArea = All;
    Caption = 'Document Groups';
    PageType = List;
    SourceTable = "Document Group";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Groups)
            {
                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique code for this Document Group.';
                }
                field(Name; Rec."Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a short descriptive name, e.g. "Sales Document".';
                }
                field("Data Level"; Rec."Data Level")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this group captures Transaction Data or Historical Data.';
                }
                field("No. of Tables"; Rec."No. of Tables")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the number of tables (Header + Line) assigned to this group.';
                }
            }
        }
    }
}
