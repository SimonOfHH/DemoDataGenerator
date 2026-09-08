namespace SimonOfHH.DemoData.Segments;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.Core;
using System.IO;
using System.Utilities;

/// <summary>
/// Re-absorbs a developer's hand-edited .al file (or the whole exported .zip) back into the
/// "Code Segment" store, using the marker comments each generated file was exported with (see
/// "Segment Marker Helper") - no AL parser required, just a text split on marker lines.
///
/// Requires that a sync/export has already run for this module at least once: without existing
/// "Code Segment" rows there is nothing to match a marker's Segment ID against, and no baseline
/// to compare imported text to, so every segment would be indistinguishable from a hand-written
/// Manual Block.
/// </summary>
codeunit 70143 "Segment Importer"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        CodeSegmentStore: Codeunit "Code Segment Store";
        MarkerHelper: Codeunit "Segment Marker Helper";
        UpdatedCount: Integer;
        UnchangedCount: Integer;
        ManualBlockCount: Integer;
        SkippedNotes: List of [Text];
        ImportDialogTitleLbl: Label 'Import Edited Source';
        ImportFilterLbl: Label 'AL or Zip Files (*.al;*.zip)|*.al;*.zip', Locked = true;
        NoSegmentsErr: Label 'This module has no generated code segments yet. Run "Generate & Download" (or "Force Regenerate & Download") at least once before importing edited source.';
        ImportCompleteLbl: Label 'Import complete.';
        UpdatedCountLbl: Label 'Segments updated: %1', Comment = '%1 = Count';
        UnchangedCountLbl: Label 'Segments unchanged: %1', Comment = '%1 = Count';
        ManualBlockCountLbl: Label 'Manual blocks captured: %1', Comment = '%1 = Count';
        NotesHeaderLbl: Label 'Notes:';
        UnrecognizedFileNoteLbl: Label '%1 - unrecognized file (run a sync/export first)', Comment = '%1 = File Path';
        NoMarkersNoteLbl: Label '%1 - no marker comments found, skipped entirely', Comment = '%1 = File Path';
        UnknownSegmentIdNoteLbl: Label '%1 - unknown Segment ID (marker may have been edited or moved)', Comment = '%1 = Segment ID';
        ManualBlockSegmentIdLbl: Label 'MANUAL.%1.%2', Comment = '%1 = Artifact Key, %2 = Content Hash', Locked = true;

    /// <summary>
    /// Prompts for a .al file or a .zip archive and imports it for the given module, then shows
    /// a one-line-per-file/segment summary of what changed.
    /// </summary>
    procedure Import(ModuleDef: Record "Module Definition")
    var
        FileName: Text;
        InStr: InStream;
    begin
        this.ResetCounters();

        if this.HasNoExistingSegments(ModuleDef.Code) then
            Error(this.NoSegmentsErr);

        if not UploadIntoStream(this.ImportDialogTitleLbl, '', this.ImportFilterLbl, FileName, InStr) then
            exit;

        if this.EndsWithIgnoreCase(FileName, '.zip') then
            this.ImportZip(ModuleDef.Code, InStr)
        else
            this.ImportSingleFile(ModuleDef.Code, FileName, InStr);

        Message(this.BuildSummary());
    end;

    local procedure HasNoExistingSegments(ModuleCode: Code[20]): Boolean
    var
        CodeSegment: Record "Code Segment";
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        exit(CodeSegment.IsEmpty());
    end;

    local procedure ImportZip(ModuleCode: Code[20]; InStr: InStream)
    var
        DataCompression: Codeunit "Data Compression";
        EntryTempBlob: Codeunit "Temp Blob";
        EntryOutStream: OutStream;
        EntryInStream: InStream;
        EntryNames: List of [Text];
        EntryName: Text;
        EntryContent: Text;
    begin
        DataCompression.OpenZipArchive(InStr, false);
        DataCompression.GetEntryList(EntryNames);
        foreach EntryName in EntryNames do begin
            if not this.EndsWithIgnoreCase(EntryName, '.al') then
                continue; // app.json / *.data.json / prompts are never segmented - skip silently
            Clear(EntryTempBlob);
            EntryTempBlob.CreateOutStream(EntryOutStream);
            DataCompression.ExtractEntry(EntryName, EntryOutStream);
            EntryTempBlob.CreateInStream(EntryInStream, TextEncoding::UTF8);
            EntryContent := this.ReadAllText(EntryInStream);
            this.ImportFileContent(ModuleCode, EntryName, EntryContent);
        end;
        DataCompression.CloseZipArchive();
    end;

    local procedure ImportSingleFile(ModuleCode: Code[20]; FileName: Text; InStr: InStream)
    var
        Content: Text;
    begin
        Content := this.ReadAllText(InStr);
        this.ImportFileContent(ModuleCode, FileName, Content);
    end;

    /// <summary>
    /// Splits one file's text on marker comments and applies each recognized segment's text to
    /// the matching "Code Segment" record. Text found outside any marker pair is captured as a
    /// Manual Block segment so hand-added code is not silently lost.
    /// </summary>
    local procedure ImportFileContent(ModuleCode: Code[20]; FileNameOrPath: Text; Content: Text)
    var
        ArtifactKind: Enum "Code Artifact Kind";
        ArtifactKey: Text[100];
        Lines: List of [Text];
        Line: Text;
        IsStartMarker: Boolean;
        MarkerSegmentId: Text;
        CurrentSegmentId: Text;
        SegmentBuilder: TextBuilder;
        ManualBuilder: TextBuilder;
        FoundAnyMarker: Boolean;
        RelativeFilePath: Text;
    begin
        RelativeFilePath := this.NormalizeFilePath(FileNameOrPath);
        if not this.FindArtifactForFilePath(ModuleCode, RelativeFilePath, ArtifactKind, ArtifactKey) then begin
            this.SkippedNotes.Add(StrSubstNo(this.UnrecognizedFileNoteLbl, RelativeFilePath));
            exit;
        end;

        Lines := Content.Split(this.NewLine());
        foreach Line in Lines do
            if this.MarkerHelper.TryParseMarker(Line, IsStartMarker, MarkerSegmentId) then begin
                FoundAnyMarker := true;
                if IsStartMarker then begin
                    this.FlushManualBlock(ModuleCode, ArtifactKind, ArtifactKey, ManualBuilder);
                    CurrentSegmentId := MarkerSegmentId;
                    Clear(SegmentBuilder);
                end else begin
                    this.ApplySegmentText(ModuleCode, CurrentSegmentId, SegmentBuilder.ToText());
                    CurrentSegmentId := '';
                end;
            end else
                if CurrentSegmentId <> '' then
                    SegmentBuilder.AppendLine(Line)
                else
                    ManualBuilder.AppendLine(Line);

        this.FlushManualBlock(ModuleCode, ArtifactKind, ArtifactKey, ManualBuilder);

        if not FoundAnyMarker then
            this.SkippedNotes.Add(StrSubstNo(this.NoMarkersNoteLbl, RelativeFilePath));
    end;

    local procedure ApplySegmentText(ModuleCode: Code[20]; SegmentId: Text; RawText: Text)
    var
        CodeSegment: Record "Code Segment";
        NormalizedText, StoredText : Text;
    begin
        if SegmentId = '' then
            exit; // stray end-marker with no matching start - ignore
        NormalizedText := this.StripTrailingNewline(RawText);
        if not CodeSegment.Get(ModuleCode, CopyStr(SegmentId, 1, MaxStrLen(CodeSegment."Segment ID"))) then begin
            this.SkippedNotes.Add(StrSubstNo(this.UnknownSegmentIdNoteLbl, SegmentId));
            exit;
        end;
        if CodeSegment.Locked then begin
            this.UnchangedCount += 1; // Locked is a stronger signal than an import - respected here too
            exit;
        end;
        StoredText := this.CodeSegmentStore.GetCode(CodeSegment);
        if StoredText = NormalizedText then begin
            this.UnchangedCount += 1;
            exit;
        end;
        this.CodeSegmentStore.ApplyImportedText(CodeSegment, NormalizedText);
        this.UpdatedCount += 1;
    end;

    /// <summary>
    /// Captures text sitting outside any marker pair as a new "Manual Block" segment, keyed by a
    /// content hash (not position) so hand-adding the SAME block again is idempotent. Whitespace-
    /// only gaps between segments are ignored.
    /// </summary>
    local procedure FlushManualBlock(ModuleCode: Code[20]; ArtifactKind: Enum "Code Artifact Kind"; ArtifactKey: Text[100]; var ManualBuilder: TextBuilder)
    var
        CodeSegment: Record "Code Segment";
        NormalizedText: Text;
        SegmentId: Text[100];
        ContentHash: Text[64];
    begin
        NormalizedText := this.StripTrailingNewline(ManualBuilder.ToText());
        Clear(ManualBuilder);
        if NormalizedText.Trim() = '' then
            exit;

        ContentHash := CopyStr(this.CodeSegmentStore.ComputeHash(NormalizedText), 1, MaxStrLen(ContentHash));
        SegmentId := CopyStr(StrSubstNo(this.ManualBlockSegmentIdLbl, ArtifactKey, ContentHash), 1, MaxStrLen(CodeSegment."Segment ID"));

        if CodeSegment.Get(ModuleCode, SegmentId) then begin
            this.UnchangedCount += 1; // identical manual content already captured
            exit;
        end;

        CodeSegment.Init();
        CodeSegment."Module Code" := ModuleCode;
        CodeSegment."Segment ID" := SegmentId;
        CodeSegment."Artifact Kind" := ArtifactKind;
        CodeSegment."Artifact Key" := ArtifactKey;
        CodeSegment."Segment Kind" := CodeSegment."Segment Kind"::"Manual Block";
        CodeSegment."Segment Name" := 'Manually Added Block';
        CodeSegment."Sort Order" := 999999; // appended at the end of the file
        CodeSegment.Status := CodeSegment.Status::Manual;
        CodeSegment."Last Import At" := CurrentDateTime();
        this.CodeSegmentStore.SetCode(CodeSegment, NormalizedText);
        this.CodeSegmentStore.SetBaselineCode(CodeSegment, NormalizedText);
        CodeSegment."Current Hash" := ContentHash;
        CodeSegment."Baseline Hash" := ContentHash;
        this.CodeSegmentStore.UpdateDerivedFields(CodeSegment, NormalizedText);
        CodeSegment.Insert(true);
        this.ManualBlockCount += 1;
    end;

    /// <summary>
    /// Finds which (Artifact Kind, Artifact Key) a file path belongs to by matching it against
    /// already-stored segments' File Path - first exactly, then (for a single-file upload, which
    /// has no folder path at all) by bare file name.
    /// </summary>
    local procedure FindArtifactForFilePath(ModuleCode: Code[20]; FilePath: Text; var ArtifactKind: Enum "Code Artifact Kind"; var ArtifactKey: Text[100]): Boolean
    var
        CodeSegment: Record "Code Segment";
        BareFileName: Text;
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        CodeSegment.SetRange("File Path", CopyStr(FilePath, 1, MaxStrLen(CodeSegment."File Path")));
        if not CodeSegment.FindFirst() then begin
            CodeSegment.SetRange("File Path");
            BareFileName := this.GetBareFileName(FilePath);
            CodeSegment.SetFilter("File Path", '*' + BareFileName);
            if not CodeSegment.FindFirst() then
                exit(false);
        end;
        ArtifactKind := CodeSegment."Artifact Kind";
        ArtifactKey := CodeSegment."Artifact Key";
        exit(true);
    end;

    local procedure GetBareFileName(FilePath: Text): Text
    var
        Parts: List of [Text];
    begin
        Parts := FilePath.Replace('\', '/').Split('/');
        exit(Parts.Get(Parts.Count()));
    end;

    local procedure NormalizeFilePath(RawPath: Text): Text
    var
        Result: Text;
    begin
        Result := RawPath.Replace('\', '/');
        if Result.StartsWith('./') then
            Result := Result.Substring(3);
        exit(Result);
    end;

    local procedure EndsWithIgnoreCase(Value: Text; Suffix: Text): Boolean
    begin
        exit(Value.ToLower().EndsWith(Suffix.ToLower()));
    end;

    local procedure ReadAllText(InStr: InStream): Text
    var
        Result: Text;
        Line: Text;
        IsFirstLine: Boolean;
    begin
        IsFirstLine := true;
        while not InStr.EOS do begin
            InStr.ReadText(Line);
            if IsFirstLine then begin
                Result := Line;
                IsFirstLine := false;
            end else
                Result := Result + this.NewLine() + Line;
        end;
        exit(Result);
    end;

    /// <summary>
    /// Strips a single trailing line-feed, if present, so text rebuilt line-by-line via
    /// TextBuilder.AppendLine (which always terminates its last line too) matches the
    /// no-trailing-terminator convention "Code Segment Store" uses when it reads a Blob back
    /// into Text. Without this, every re-imported segment would spuriously look "changed" by
    /// exactly one trailing newline even when nothing was actually edited.
    /// </summary>
    local procedure StripTrailingNewline(Input: Text): Text
    var
    // LineFeed: Char;
    begin
        // LineFeed := 10;
        if Input = '' then
            exit('');
        if Input.EndsWith(this.NewLine()) then
            exit(CopyStr(Input, 1, StrLen(Input) - StrLen(this.NewLine())));
        exit(Input);
    end;

    /// <summary>
    /// Returns a single-character Text containing a line-feed - see "Code Segment Store".NewLine
    /// for why this cannot be the literal string '\n'.
    /// </summary>
    local procedure NewLine(): Text
    var
        CR: Char;
        LineFeed: Char;
    begin
        CR := 13;
        LineFeed := 10;
        exit(Format(CR) + Format(LineFeed));
    end;

    local procedure ResetCounters()
    begin
        this.UpdatedCount := 0;
        this.UnchangedCount := 0;
        this.ManualBlockCount := 0;
        Clear(this.SkippedNotes);
    end;

    local procedure BuildSummary(): Text
    var
        Result: TextBuilder;
        Note: Text;
    begin
        Result.AppendLine(this.ImportCompleteLbl);
        Result.AppendLine(StrSubstNo(this.UpdatedCountLbl, this.UpdatedCount));
        Result.AppendLine(StrSubstNo(this.UnchangedCountLbl, this.UnchangedCount));
        Result.AppendLine(StrSubstNo(this.ManualBlockCountLbl, this.ManualBlockCount));
        if this.SkippedNotes.Count() > 0 then begin
            Result.AppendLine(this.NotesHeaderLbl);
            foreach Note in this.SkippedNotes do
                Result.AppendLine('- ' + Note);
        end;
        exit(Result.ToText());
    end;
}
