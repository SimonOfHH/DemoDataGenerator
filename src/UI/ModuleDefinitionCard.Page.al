namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Core;
using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.Export;
using System.Reflection;

/// <summary>
/// Card page for Module Definition — the main workspace for configuring a module.
/// </summary>
page 70101 "Module Definition Card"
{
    ApplicationArea = All;
    Caption = 'Demo Data Module';
    PageType = Card;
    UsageCategory = None;
    SourceTable = "Module Definition";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("Code"; Rec.Code)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique code for this module.';
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the display name of the module. Used for generated codeunit naming.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a description for the generated extension.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current status of the module.';
                    Editable = false;
                }
            }
            group(AppIdentity)
            {
                Caption = 'Generated App Identity';
                field(Publisher; Rec.Publisher)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the publisher for the generated app.json.';
                }
                field("App Version"; Rec."App Version")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the version for the generated app.json.';
                }
                field("App ID"; Rec."App ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique App ID (GUID) for the generated extension. Auto-generated on insert.';
                    Editable = false;
                }
                field("Base Namespace"; Rec."Base Namespace")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the root namespace for the generated extension (e.g. Contoso.MyModule). Sub-namespaces .Helpers and .DemoData are derived automatically.';
                }
                field("Apps to Exclude"; Rec."Apps to Exclude")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies comma-separated App IDs whose fields to skip during dependency detection.';
                    MultiLine = true;

                    trigger OnAssistEdit()
                    var
                        AppLookup: Page "Installed Apps Lookup";
                    begin
                        AppLookup.LookupMode := true;
                        AppLookup.SetExclusionIds(Rec."Apps to Exclude");
                        if AppLookup.RunModal() = Action::LookupOK then
                            Rec."Apps to Exclude" := CopyStr(AppLookup.GetExclusionIds(), 1, MaxStrLen(Rec."Apps to Exclude"));
                    end;
                }
            }
            group(ObjectRange)
            {
                Caption = 'Object Range';
                field("ID Range Start"; Rec."ID Range Start")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the first object ID for the generated extension.';
                }
                field("ID Range End"; Rec."ID Range End")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the last object ID for the generated extension.';
                }
                field("Enum Ordinal"; Rec."Enum Ordinal")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the ordinal value for the generated Contoso Demo Data Module enum extension.';
                }
                field("Enum Value Name"; Rec."Enum Value Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the enum value name as it appears in the generated enum extension.';
                }
                field("Helper Prefix"; Rec."Helper Prefix")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the prefix for generated helper codeunit names (e.g. "Contoso"). The full helper codeunit name is derived as "<Helper Prefix> <Helper Group>".';
                }
            }
            part(TableSelections; "Table Selection Subpage")
            {
                ApplicationArea = All;
                Caption = 'Selected Tables';
                SubPageLink = "Module Code" = field(Code);
            }
            part(Dependencies; "Module Dependency Subpage")
            {
                ApplicationArea = All;
                Caption = 'Contoso Module Dependencies';
                SubPageLink = "Module Code" = field(Code);
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(AddTables)
            {
                ApplicationArea = All;
                Caption = 'Add Tables';
                Image = Add;
                ToolTip = 'Add tables from the system to this module.';

                trigger OnAction()
                var
                    AllObj: Record AllObjWithCaption;
                    TableSel: Record "Table Selection";
                begin
                    AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
                    if Page.RunModal(Page::"All Objects with Caption", AllObj) = Action::LookupOK then
                        if not TableSel.Get(Rec.Code, AllObj."Object ID") then begin
                            TableSel.Init();
                            TableSel."Module Code" := Rec.Code;
                            TableSel.Validate("Table ID", AllObj."Object ID");
                            TableSel.Insert(true);
                        end;
                end;
            }
            action(AutoPopulateFields)
            {
                ApplicationArea = All;
                Caption = 'Auto-Populate Fields';
                Image = Refresh;
                ToolTip = 'Reads table metadata and populates field configurations for all selected tables.';

                trigger OnAction()
                var
                    TableSel: Record "Table Selection";
                begin
                    TableSel.SetRange("Module Code", Rec.Code);
                    if TableSel.FindSet() then
                        repeat
                            TableSel.PopulateFields();
                        until TableSel.Next() = 0;
                    Message(FieldsPopulatedMsg);
                end;
            }
            action(PreviewIdAllocation)
            {
                ApplicationArea = All;
                Caption = 'Preview ID Allocation';
                Image = PreviewChecks;
                ToolTip = 'Shows how object IDs will be allocated for the generated extension.';

                trigger OnAction()
                var
                    ExportOrchestrator: Codeunit "Export Orchestrator";
                    ModuleContainer: Codeunit "CodeGen Module Container";
                    LoopCodeunit: Codeunit "CodeGen Codeunit";
                    Preview: TextBuilder;
                begin
                    ExportOrchestrator.GenerateModule(Rec, ModuleContainer);
                    Preview.AppendLine('Object ID Allocation Preview');
                    Preview.AppendLine('===========================');
                    Preview.Append('Enum Extension: ');
                    Preview.AppendLine(ModuleContainer.GetEnumExtension().ToIdentifierString());
                    Preview.Append('Module Codeunit: ');
                    Preview.AppendLine(ModuleContainer.GetModuleCodeunit().ToIdentifierString());
                    Preview.AppendLine('Helper Codeunits:');
                    foreach LoopCodeunit in ModuleContainer.GetHelperCodeunits() do begin
                        Preview.Append(' - ');
                        Preview.AppendLine(LoopCodeunit.ToIdentifierString());
                    end;
                    Preview.AppendLine('Data Codeunits:');
                    foreach LoopCodeunit in ModuleContainer.GetDataCodeunits() do begin
                        Preview.Append(' - ');
                        Preview.AppendLine(LoopCodeunit.ToIdentifierString());
                    end;
                    Message(Preview.ToText());
                end;
            }
            action(GenerateAndDownload)
            {
                ApplicationArea = All;
                Caption = 'Generate && Download';
                Image = Export;
                ToolTip = 'Generates the complete AL extension and downloads it as a zip file.';

                trigger OnAction()
                var
                    ExportOrchestrator: Codeunit "Export Orchestrator";
                begin
                    ExportOrchestrator.Run(Rec);
                    CurrPage.Update(false);
                end;
            }
            group(ExportImport)
            {
                Caption = 'Export/Import';
                action(ExportModule)
                {
                    ApplicationArea = All;
                    Caption = 'Export Module';
                    Image = ExportFile;
                    ToolTip = 'Exports this module definition (including tables and field configurations) to a JSON file.';

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
            group(Other)
            {
                Caption = 'Other';
                action(Cleanup)
                {
                    ApplicationArea = All;
                    Caption = 'Clean Up';
                    Image = RemoveLine;
                    ToolTip = 'Cleans up the module by removing field configurations for fields that no longer exist in the environment.';

                    trigger OnAction()
                    var
                        ModuleExportImport: Codeunit "Module Export Import";
                    begin
                        ModuleExportImport.CleanUpModule(Rec);
                        CurrPage.Update(false);
                    end;
                }
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(AddTables_Promoted; AddTables) { }
                actionref(AutoPopulate_Promoted; AutoPopulateFields) { }
                actionref(Preview_Promoted; PreviewIdAllocation) { }
                actionref(Generate_Promoted; GenerateAndDownload) { }
            }
            group(Category_ExportImport)
            {
                Caption = 'Export/Import';
                actionref(ExportModule_Promoted; ExportModule) { }
                actionref(ImportModule_Promoted; ImportModule) { }
            }
        }
    }
    var
        FieldsPopulatedMsg: Label 'Field configurations have been populated for all selected tables.';
}
