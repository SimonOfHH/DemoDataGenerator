namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;

/// <summary>
/// List page for mapping a Line-role table's key fields to its Document Group's Header
/// table fields. Invoked modally from the Table Selection Subpage's "Configure Group Links" action.
/// </summary>
page 70109 "Document Group Link Subpage"
{
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Document Group Links';
    PageType = List;
    SourceTable = "Document Group Link";

    layout
    {
        area(Content)
        {
            repeater(Links)
            {
                field("Child Field No."; Rec."Child Field No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the key field on this (Line) table, e.g. "Document No." on Sales Line.';
                }
                field("Child Field Name"; Rec."Child Field Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the selected child field.';
                    Editable = false;
                }
                field("Header Field No."; Rec."Header Field No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the corresponding key field on the Document Group''s Header table, e.g. "No." on Sales Header.';
                }
                field("Header Field Name"; Rec."Header Field Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the selected header field.';
                    Editable = false;
                }
            }
        }
    }
}
