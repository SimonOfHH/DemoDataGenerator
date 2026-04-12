namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;

/// <summary>
/// Subpage for declaring Contoso module dependencies.
/// </summary>
page 70104 "Module Dependency Subpage"
{
    ApplicationArea = All;
    Caption = 'Module Dependencies';
    PageType = ListPart;
    SourceTable = "Module Dependency";

    layout
    {
        area(Content)
        {
            repeater(Dependencies)
            {
                field("Dependency Module Name"; Rec."Dependency Module Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the Contoso module this module depends on (e.g., Foundation, Finance, CRM).';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        TempModuleDep: Record "Module Dependency" temporary;
                    begin
                        TempModuleDep.InitTemporaryContosoModules(); // Helper function to get a list of Contoso modules as a temp record for the lookup

                        if Page.RunModal(0, TempModuleDep) = Action::LookupOK then begin
                            Text := TempModuleDep."Dependency Module Name";
                            exit(true);
                        end;
                        exit(false);
                    end;
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
