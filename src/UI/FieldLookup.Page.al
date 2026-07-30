namespace SimonOfHH.DemoData.UI;

using System.Reflection;

/// <summary>
/// Generic lookup page over table fields. The system does not expose a reusable default
/// page for the "Field" table (Page.RunModal(0, FieldRecord) fails), and the base
/// application's own "Fields Lookup" page (9806) cannot be used because its selection
/// helper procedure is Scope('OnPrem'). This page is a small Cloud-safe replacement,
/// intended to be invoked via "Field Lookup Helper".
/// </summary>
page 70111 "Field Lookup"
{
    ApplicationArea = All;
    Caption = 'Fields';
    PageType = List;
    SourceTable = Field;
    Editable = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Fields)
            {
                field("No."; Rec."No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of the field.';
                }
                field(FieldName; Rec.FieldName)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the field.';
                }
                field("Field Caption"; Rec."Field Caption")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the caption of the field as shown in the user interface.';
                }
                field(Type; Rec.Type)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the data type of the field.';
                }
            }
        }
    }
}
