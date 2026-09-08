namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.Segments;

/// <summary>
/// Read-only view of a single "Code Segment"'s current code. Editing directly in Business
/// Central is a deliberate TODO for later (see the app's roadmap notes) - for now, developers
/// edit the exported .al file in VS Code and re-import it (see "Segment Importer").
/// </summary>
page 70113 "Code Segment Card"
{
    ApplicationArea = All;
    Caption = 'Code Segment';
    PageType = Card;
    SourceTable = "Code Segment";
    UsageCategory = None;
    Editable = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                field("Segment ID"; Rec."Segment ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the stable identifier for this segment (also the marker token used in the generated .al file).';
                }
                field("Artifact Kind"; Rec."Artifact Kind")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies which generated file this segment belongs to.';
                }
                field("Artifact Key"; Rec."Artifact Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the generated file.';
                }
                field("File Path"; Rec."File Path")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the relative path of the generated file.';
                }
                field("Segment Kind"; Rec."Segment Kind")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies what kind of code fragment this segment is.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the reconciliation state of this segment as of the last sync/export.';
                }
                field(Locked; Rec.Locked)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this segment is skipped entirely during sync/regeneration.';
                    Editable = true;
                }
                field("Last Generated At"; Rec."Last Generated At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this segment was last (re)generated.';
                }
                field("Last Modified At"; Rec."Last Modified At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this segment was last changed (generated or imported).';
                }
                field("Last Import At"; Rec."Last Import At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this segment was last updated via source import.';
                }
            }
            group(CodeGroup)
            {
                Caption = 'Code';
                field(CodeText; this.CodeText)
                {
                    ApplicationArea = All;
                    Caption = 'Code';
                    ShowCaption = false;
                    MultiLine = true;
                    Editable = false;
                    ToolTip = 'Specifies this segment''s current code. Read-only - edit the exported .al file in VS Code and re-import it to change this.';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        this.CodeText := this.CodeSegmentStore.GetCode(Rec);
    end;

    var
        CodeSegmentStore: Codeunit "Code Segment Store";
        CodeText: Text;
}
