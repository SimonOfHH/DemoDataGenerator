namespace SimonOfHH.DemoData.Segments;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.Core;

/// <summary>
/// Rebuilds the full text of a generated .al file from its stored "Code Segment" records,
/// wrapping each segment in marker comments (see "Segment Marker Helper") so a developer's
/// hand-edited copy of the file can later be split back into segments by the marker-based
/// importer. Reads only - never generates or reconciles anything (that is "Segment Sync
/// Manager"'s job, which must run first).
/// </summary>
codeunit 70142 "Segment File Assembler"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        MarkerHelper: Codeunit "Segment Marker Helper";
        CodeSegmentStore: Codeunit "Code Segment Store";

    /// <summary>
    /// Returns the distinct Artifact Keys (i.e. one per generated file) that currently have at
    /// least one non-Orphaned segment for the given module and Artifact Kind.
    /// </summary>
    procedure GetArtifactKeys(ModuleCode: Code[20]; ArtifactKind: Enum "Code Artifact Kind"): List of [Text]
    var
        CodeSegment: Record "Code Segment";
        Keys: List of [Text];
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        CodeSegment.SetRange("Artifact Kind", ArtifactKind);
        CodeSegment.SetFilter(Status, '<>%1', CodeSegment.Status::Orphaned);
        CodeSegment.SetCurrentKey("Module Code", "Artifact Kind", "Artifact Key", "Sort Order");
        if CodeSegment.FindSet() then
            repeat
                if not Keys.Contains(CodeSegment."Artifact Key") then
                    Keys.Add(CodeSegment."Artifact Key");
            until CodeSegment.Next() = 0;
        exit(Keys);
    end;

    /// <summary>
    /// Returns the relative output path (e.g. "src/Helpers/ContosoBank.Codeunit.al") stored
    /// against this artifact's segments by "Segment Sync Manager".
    /// </summary>
    procedure GetFilePath(ModuleCode: Code[20]; ArtifactKind: Enum "Code Artifact Kind"; ArtifactKey: Text[100]): Text
    var
        CodeSegment: Record "Code Segment";
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        CodeSegment.SetRange("Artifact Kind", ArtifactKind);
        CodeSegment.SetRange("Artifact Key", ArtifactKey);
        if CodeSegment.FindFirst() then
            exit(CodeSegment."File Path");
        exit('');
    end;

    /// <summary>
    /// Rebuilds the complete text of one generated .al file from its stored, non-Orphaned
    /// segments, in Sort Order, each wrapped in start/end marker comments.
    /// </summary>
    procedure AssembleFile(ModuleCode: Code[20]; ArtifactKind: Enum "Code Artifact Kind"; ArtifactKey: Text[100]): Text
    var
        CodeSegment: Record "Code Segment";
        Result: TextBuilder;
        SegmentText: Text;
        IndentLevel: Integer;
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        CodeSegment.SetRange("Artifact Kind", ArtifactKind);
        CodeSegment.SetRange("Artifact Key", ArtifactKey);
        CodeSegment.SetFilter(Status, '<>%1', CodeSegment.Status::Orphaned);
        CodeSegment.SetCurrentKey("Module Code", "Artifact Kind", "Artifact Key", "Sort Order");
        if not CodeSegment.FindSet() then
            exit('');
        repeat
            SegmentText := this.CodeSegmentStore.GetCode(CodeSegment);
            IndentLevel := this.GetIndentLevelForKind(CodeSegment."Segment Kind");
            Result.AppendLine(this.MarkerHelper.BuildStartMarker(CodeSegment."Segment ID", IndentLevel));
            Result.AppendLine(SegmentText);
            Result.AppendLine(this.MarkerHelper.BuildEndMarker(CodeSegment."Segment ID", IndentLevel));
            Result.AppendLine('');
        until CodeSegment.Next() = 0;
        exit(Result.ToText());
    end;

    local procedure GetIndentLevelForKind(SegmentKind: Enum "Code Segment Kind"): Integer
    begin
        case SegmentKind of
            SegmentKind::"File Header", SegmentKind::"File Footer":
                exit(0);
            else
                exit(1);
        end;
    end;
}
