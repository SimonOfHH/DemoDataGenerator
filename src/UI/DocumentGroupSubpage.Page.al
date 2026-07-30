namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;

/// <summary>
/// Subpage for declaring Document Groups (Header + Line table groupings used to capture
/// correlated Transaction/Historical data snapshots).
/// </summary>
page 70108 "Document Group Subpage"
{
    ApplicationArea = All;
    Caption = 'Document Groups';
    PageType = ListPart;
    SourceTable = "Document Group";

    layout
    {
        area(Content)
        {
            repeater(Groups)
            {
                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique code for this Document Group, e.g. "SALESDOC".';
                }
                field(Name; Rec."Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a short descriptive name, e.g. "Sales Document". Used to derive the generated stub codeunit name and JSON sidecar file name.';
                }
                field("Data Level"; Rec."Data Level")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this group captures Transaction Data or Historical Data. Every member table must share this exact Data Level.';
                }
                field("No. of Tables"; Rec."No. of Tables")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the number of tables (Header + Line) currently assigned to this group.';
                }
                field("Data Codeunit Name"; Rec."Data Codeunit Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the generated stub data codeunit. If not specified, a default name will be derived from Name.';
                    Visible = false; // This is an advanced option that is not commonly used, so we hide it by default to reduce clutter.
                }
            }
        }
    }
}
