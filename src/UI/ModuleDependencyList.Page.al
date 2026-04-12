namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;

/// <summary>
/// Simple list page for Module Dependency records.
/// Used as LookupPage for the temporary record lookup in the dependency subpage.
/// </summary>
page 70107 "Module Dependency List"
{
    ApplicationArea = All;
    Caption = 'Module Dependencies';
    PageType = List;
    SourceTable = "Module Dependency";
    UsageCategory = None;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Dependencies)
            {
                field("Dependency Module Name"; Rec."Dependency Module Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the Contoso module.';
                }
                field("Dependency Enum Ordinal"; Rec."Dependency Enum Ordinal")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the ordinal value of the dependency in the Contoso Demo Data Module enum.';
                }
            }
        }
    }
}
