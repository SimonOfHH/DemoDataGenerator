namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Core;
using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.Export;
using SimonOfHH.DemoData.Segments;
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
                    ShowMandatory = true;
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
            group(GeneratedCodeStatus)
            {
                Caption = 'Generated Code Status';
                field(ConflictCount; this.ConflictCount)
                {
                    ApplicationArea = All;
                    Caption = 'Conflicted Segments';
                    ToolTip = 'Specifies how many generated code segments have a manual edit AND a newer generated version - exporting will keep the manual edit and skip the newer version for these until you review them. Use the Generated Code action to review.';
                    Editable = false;
                    StyleExpr = this.ConflictCountStyleExpr;
                }
                field(ModifiedCount; this.ModifiedCount)
                {
                    ApplicationArea = All;
                    Caption = 'Manually Modified Segments';
                    ToolTip = 'Specifies how many generated code segments the developer has manually edited (and which still match what the generator would currently produce, i.e. no conflict).';
                    Editable = false;
                }
            }
            part(TableSelections; "Table Selection Subpage")
            {
                ApplicationArea = All;
                Caption = 'Selected Tables';
                SubPageLink = "Module Code" = field(Code);
            }
            part(DocumentGroups; "Document Group Subpage")
            {
                ApplicationArea = All;
                Caption = 'Document Groups';
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
                    TableSelection: Record "Table Selection";
                begin
                    AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
                    if Page.RunModal(Page::"All Objects with Caption", AllObj) = Action::LookupOK then
                        if not TableSelection.Get(Rec.Code, AllObj."Object ID") then begin
                            TableSelection.Init();
                            TableSelection."Module Code" := Rec.Code;
                            TableSelection.Validate("Table ID", AllObj."Object ID");
                            TableSelection.Insert(true);
                        end;
                end;
            }
            action(ImportFromConfigPackage)
            {
                ApplicationArea = All;
                Caption = 'Import from Config. Package';
                Image = ImportCodes;
                ToolTip = 'Adds tables from an existing Configuration Package to this module. Fields with Include Field = true in the package are set to Behavior = Include; all other fields default to Exclude. Row filters defined in the package are imported as Table View.';

                trigger OnAction()
                var
                    ConfigPackageImporter: Codeunit "Config. Package Importer";
                begin
                    ConfigPackageImporter.ImportFromConfigPackage(Rec);
                    CurrPage.Update(false);
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
                    TableSelection: Record "Table Selection";
                begin
                    TableSelection.SetRange("Module Code", Rec.Code);
                    if TableSelection.FindSet() then
                        repeat
                            TableSelection.PopulateFields();
                        until TableSelection.Next() = 0;
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
            action(ForceRegenerate)
            {
                ApplicationArea = All;
                Caption = 'Force Regenerate && Download';
                Image = Refresh;
                ToolTip = 'Generates and downloads the complete AL extension, overwriting every non-Locked code segment with the freshly generated version - including any manual edits you made.';

                trigger OnAction()
                var
                    ExportOrchestrator: Codeunit "Export Orchestrator";
                begin
                    if not Confirm(this.ForceRegenerateQst, false) then
                        exit;
                    ExportOrchestrator.Run(Rec, true, true);
                    CurrPage.Update(false);
                end;
            }
            action(ForceRegenerateNoDownload)
            {
                ApplicationArea = All;
                Caption = 'Force Regenerate (No Download)';
                Image = RefreshLines;
                ToolTip = 'Reconciles code segments against the current configuration/data, overwriting every non-Locked segment with the freshly generated version - including any manual edits - but does NOT download a zip.';

                trigger OnAction()
                var
                    ExportOrchestrator: Codeunit "Export Orchestrator";
                begin
                    if not Confirm(this.ForceRegenerateQst, false) then
                        exit;
                    ExportOrchestrator.Run(Rec, false, true);
                    Message(this.ForceRegenerateCompleteMsg);
                    CurrPage.Update(false);
                end;
            }
            action(RevertModuleToBaseline)
            {
                ApplicationArea = All;
                Caption = 'Revert Module to Baseline';
                Image = Undo;
                ToolTip = 'Discards ALL manual edits and parked conflicts for this module, resetting every segment back to its last-generated version. Locked and manually-added segments are left untouched.';

                trigger OnAction()
                var
                    CodeSegmentStore: Codeunit "Code Segment Store";
                begin
                    if not Confirm(this.RevertModuleQst, false) then
                        exit;
                    CodeSegmentStore.RevertModuleToBaseline(Rec.Code);
                    CurrPage.Update(false);
                end;
            }
            action(GeneratedCode)
            {
                ApplicationArea = All;
                Caption = 'Generated Code';
                Image = ViewDetails;
                ToolTip = 'Opens the list of generated code segments for this module - see what was generated, what you have edited, and what is in conflict.';

                trigger OnAction()
                begin
                    this.OpenGeneratedCode();
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
                action(ImportEditedSource)
                {
                    ApplicationArea = All;
                    Caption = 'Import Edited Source';
                    Image = ImportExport;
                    ToolTip = 'Re-absorbs a hand-edited generated .al file (or the whole exported .zip) back into the generated code segments, using the marker comments in the generated source. Requires a prior Generate/Force Regenerate for this module.';

                    trigger OnAction()
                    var
                        SegmentImporter: Codeunit "Segment Importer";
                    begin
                        SegmentImporter.Import(Rec);
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
                actionref(ImportFromConfigPackage_Promoted; ImportFromConfigPackage) { }
                actionref(AutoPopulate_Promoted; AutoPopulateFields) { }
                actionref(Preview_Promoted; PreviewIdAllocation) { }
                actionref(Generate_Promoted; GenerateAndDownload) { }
                actionref(ForceRegenerate_Promoted; ForceRegenerate) { }
                actionref(ForceRegenerateNoDownload_Promoted; ForceRegenerateNoDownload) { }
                actionref(RevertModuleToBaseline_Promoted; RevertModuleToBaseline) { }
                actionref(GeneratedCode_Promoted; GeneratedCode) { }
            }
            group(Category_ExportImport)
            {
                Caption = 'Export/Import';
                actionref(ExportModule_Promoted; ExportModule) { }
                actionref(ImportModule_Promoted; ImportModule) { }
                actionref(ImportEditedSource_Promoted; ImportEditedSource) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        this.ConflictCount := this.CodeSegmentStore.GetConflictCount(Rec.Code);
        this.ModifiedCount := this.CodeSegmentStore.GetModifiedCount(Rec.Code);
        if this.ConflictCount > 0 then
            this.ConflictCountStyleExpr := 'Unfavorable'
        else
            this.ConflictCountStyleExpr := 'Standard';
    end;

    local procedure OpenGeneratedCode()
    var
        CodeSegment: Record "Code Segment";
    begin
        CodeSegment.SetRange("Module Code", Rec.Code);
        Page.Run(Page::"Code Segment List", CodeSegment);
    end;

    var
        CodeSegmentStore: Codeunit "Code Segment Store";
        ConflictCount, ModifiedCount : Integer;
        ConflictCountStyleExpr: Text;
        FieldsPopulatedMsg: Label 'Field configurations have been populated for all selected tables.';
        ForceRegenerateQst: Label 'This overwrites every non-Locked generated code segment with the freshly generated version, discarding any manual edits you made to previously exported files. Continue?';
        ForceRegenerateCompleteMsg: Label 'Code segments have been force-regenerated.';
        RevertModuleQst: Label 'This discards ALL manual edits and parked conflicts for this module, resetting every segment back to its last-generated version. Locked and manually-added segments are not affected. Continue?';
}
