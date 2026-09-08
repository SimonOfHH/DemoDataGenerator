namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.Segments;
using SimonOfHH.DemoData.Export;

/// <summary>
/// Lists every generated "Code Segment" for a module (filtered via SetTableView/SetRecord by
/// the caller), so a developer can see which segments the generator produced, which they have
/// edited, and which are in conflict, before or after exporting.
/// </summary>
page 70112 "Code Segment List"
{
    ApplicationArea = All;
    Caption = 'Code Segments';
    PageType = List;
    SourceTable = "Code Segment";
    UsageCategory = None;
    Editable = false;
    SourceTableView = sorting("Module Code", "Artifact Kind", "Artifact Key", "Sort Order");

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field("Artifact Kind"; Rec."Artifact Kind")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies which generated file this segment belongs to.';
                }
                field("Artifact Key"; Rec."Artifact Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the generated file (e.g. the helper codeunit or data codeunit name).';
                }
                field("Segment Kind"; Rec."Segment Kind")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies what kind of code fragment this segment is.';
                }
                field("Segment Name"; Rec."Segment Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the human-readable name of this segment, e.g. the procedure name.';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the reconciliation state of this segment as of the last sync/export.';
                    StyleExpr = this.StatusStyleExpr;
                }
                field(Locked; Rec.Locked)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this segment is skipped entirely during sync/regeneration.';
                    Editable = true;
                }
                field("Line Count"; Rec."Line Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of lines in this segment''s code.';
                }
                field(Preview; Rec.Preview)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the first meaningful line of this segment''s code.';
                }
                field("Last Modified At"; Rec."Last Modified At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this segment was last changed (generated or imported).';
                }
                field("Last Generated At"; Rec."Last Generated At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this segment was last (re)generated.';
                    Visible = false;
                }
                field("Last Import At"; Rec."Last Import At")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when this segment was last updated via source import.';
                    Visible = false;
                }
                field("Table ID"; Rec."Table ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the BC table this segment was generated for, if applicable.';
                    Visible = false;
                }
                field("File Path"; Rec."File Path")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the relative path of the generated file this segment belongs to.';
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ViewCode)
            {
                ApplicationArea = All;
                Caption = 'View Code';
                Image = ViewDetails;
                ToolTip = 'Opens this segment''s current code for viewing.';

                trigger OnAction()
                begin
                    Page.RunModal(Page::"Code Segment Card", Rec);
                end;
            }
            action(AcceptRegenerated)
            {
                ApplicationArea = All;
                Caption = 'Accept Regenerated';
                Image = Approve;
                ToolTip = 'Replaces this segment''s code with the freshly generated version, discarding your manual edit. Only available for segments in Conflict.';
                Enabled = Rec.Status = Rec.Status::Conflict;

                trigger OnAction()
                begin
                    this.CodeSegmentStore.AcceptPending(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(KeepMine)
            {
                ApplicationArea = All;
                Caption = 'Keep Mine';
                Image = Cancel;
                ToolTip = 'Dismisses the newly generated version in favor of your manual edit. Only available for segments in Conflict.';
                Enabled = Rec.Status = Rec.Status::Conflict;

                trigger OnAction()
                begin
                    this.CodeSegmentStore.KeepMine(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(RevertToBaseline)
            {
                ApplicationArea = All;
                Caption = 'Revert to Baseline';
                Image = Undo;
                ToolTip = 'Discards your manual edit, resetting this segment back to the last generated version. Only available for segments that are Modified or in Conflict.';
                Enabled = (Rec.Status = Rec.Status::Modified) or (Rec.Status = Rec.Status::Conflict);

                trigger OnAction()
                begin
                    if not Confirm(this.RevertConfirmQst, false) then
                        exit;
                    this.CodeSegmentStore.RevertToBaseline(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(DownloadSegment)
            {
                ApplicationArea = All;
                Caption = 'Download Segment';
                Image = ExportFile;
                ToolTip = 'Downloads this segment''s current code as a text file.';

                trigger OnAction()
                var
                    FileHelper: Codeunit "File Helper";
                begin
                    FileHelper.DownloadText(Rec."Segment ID" + '.txt', this.CodeSegmentStore.GetCode(Rec));
                end;
            }
            action(DeleteOrphaned)
            {
                ApplicationArea = All;
                Caption = 'Delete Orphaned Segments';
                Image = RemoveLine;
                ToolTip = 'Permanently deletes every Orphaned segment currently shown (e.g. left over from tables removed from the module).';

                trigger OnAction()
                var
                    CodeSegment: Record "Code Segment";
                begin
                    CodeSegment.CopyFilters(Rec);
                    CodeSegment.SetRange(Status, CodeSegment.Status::Orphaned);
                    if CodeSegment.IsEmpty() then begin
                        Message(this.NoOrphansMsg);
                        exit;
                    end;
                    if not Confirm(this.DeleteOrphanedQst, false, CodeSegment.Count()) then
                        exit;
                    CodeSegment.DeleteAll(true);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(ViewCode_Promoted; ViewCode) { }
                actionref(AcceptRegenerated_Promoted; AcceptRegenerated) { }
                actionref(KeepMine_Promoted; KeepMine) { }
                actionref(RevertToBaseline_Promoted; RevertToBaseline) { }
                actionref(DownloadSegment_Promoted; DownloadSegment) { }
                actionref(DeleteOrphaned_Promoted; DeleteOrphaned) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        this.SetStatusStyle();
    end;

    var
        CodeSegmentStore: Codeunit "Code Segment Store";
        StatusStyleExpr: Text;
        RevertConfirmQst: Label 'This discards your manual edit for this segment. Continue?';
        DeleteOrphanedQst: Label 'Delete %1 Orphaned segment(s)? This cannot be undone.', Comment = '%1 = Count';
        NoOrphansMsg: Label 'There are no Orphaned segments to delete.';

    local procedure SetStatusStyle()
    begin
        case Rec.Status of
            Rec.Status::Conflict:
                this.StatusStyleExpr := 'Unfavorable';
            Rec.Status::Modified:
                this.StatusStyleExpr := 'Attention';
            Rec.Status::Orphaned:
                this.StatusStyleExpr := 'Subordinate';
            else
                this.StatusStyleExpr := 'Standard';
        end;
    end;
}
