namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.Export;

/// <summary>
/// List page for Module Definitions — the app's main landing page.
/// </summary>
page 70100 "Module Definition List"
{
    ApplicationArea = All;
    Caption = 'Demo Data Modules';
    PageType = List;
    SourceTable = "Module Definition";
    UsageCategory = Lists;
    CardPageId = "Module Definition Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Modules)
            {
                field("Code"; Rec.Code)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique code for this module.';
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the display name of the module.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current status of the module.';
                }
                field("ID Range Start"; Rec."ID Range Start")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the start of the object ID range for the generated extension.';
                }
                field("ID Range End"; Rec."ID Range End")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the end of the object ID range for the generated extension.';
                }
                field(Publisher; Rec.Publisher)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the publisher name for the generated extension.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ExportModule)
            {
                ApplicationArea = All;
                Caption = 'Export Module';
                Image = ExportFile;
                ToolTip = 'Exports the selected module definition to a JSON file.';

                trigger OnAction()
                var
                    ModuleExportImport: Codeunit "Module Export Import";
                begin
                    ModuleExportImport.ExportModule(Rec);
                end;
            }
            action(ImportModule)
            {
                ApplicationArea = All;
                Caption = 'Import Module';
                Image = ImportCodes;
                ToolTip = 'Imports a module definition from a JSON file.';

                trigger OnAction()
                var
                    ModuleExportImport: Codeunit "Module Export Import";
                begin
                    ModuleExportImport.ImportModule();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_ExportImport)
            {
                Caption = 'Export/Import';
                actionref(ExportModule_Promoted; ExportModule) { }
                actionref(ImportModule_Promoted; ImportModule) { }
            }
        }
    }
}
