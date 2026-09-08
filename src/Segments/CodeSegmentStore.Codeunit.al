namespace SimonOfHH.DemoData.Segments;

using SimonOfHH.DemoData.Model;
using System.Utilities;

/// <summary>
/// Owns all reads/writes of "Code Segment" records: Blob&lt;-&gt;Text conversion, content hashing,
/// and the reconciliation algorithm that decides what happens to a segment when the generator
/// produces a new version of it (silent overwrite / keep manual edit / flag conflict / orphan).
/// This codeunit is the only place that should ever assign "Code Segment".Status.
/// </summary>
codeunit 70139 "Code Segment Store"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    /// <summary>
    /// Counts segments currently in Conflict for the module - used to warn the developer before
    /// export, since exporting ships the MANUAL version of each conflicted segment as-is.
    /// </summary>
    procedure GetConflictCount(ModuleCode: Code[20]): Integer
    var
        CodeSegment: Record "Code Segment";
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        CodeSegment.SetRange(Status, CodeSegment.Status::Conflict);
        exit(CodeSegment.Count());
    end;

    /// <summary>
    /// Counts segments the developer has manually edited (Status = Modified) for the module.
    /// </summary>
    procedure GetModifiedCount(ModuleCode: Code[20]): Integer
    var
        CodeSegment: Record "Code Segment";
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        CodeSegment.SetRange(Status, CodeSegment.Status::Modified);
        exit(CodeSegment.Count());
    end;

    /// <summary>
    /// Prepares every non-Locked segment for a full overwrite on the next sync/Upsert pass, by
    /// making the store forget that the developer edited anything (Current Hash is reset to
    /// match Baseline Hash, so the reconciliation algorithm's "developer has NOT changed it"
    /// branch is taken and the fresh generated text silently overwrites it). Locked segments are
    /// left untouched - Locked is a stronger, explicit signal than "regenerate everything".
    /// </summary>
    procedure ForceRegenerateAll(ModuleCode: Code[20])
    var
        CodeSegment: Record "Code Segment";
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        CodeSegment.SetRange(Locked, false);
        if not CodeSegment.FindSet() then
            exit;
        repeat
            CodeSegment."Current Hash" := CodeSegment."Baseline Hash";
            CodeSegment.Modify(true);
        until CodeSegment.Next() = 0;
    end;

    /// <summary>
    /// Reconciles one generated segment against whatever is already stored for it, applying the
    /// rules below. Inserts the "Code Segment" record if it does not exist yet. Returns the
    /// (possibly unchanged) record so the caller can inspect the resulting Status.
    ///
    /// - Not stored yet -&gt; insert; Status = Generated; Baseline = Current = the generated text.
    /// - Stored and Locked -&gt; left untouched entirely (no hash comparison, no status change).
    /// - Stored, developer has NOT changed it (Current Hash = Baseline Hash):
    ///   - generated text changed -&gt; silently overwrite Code and Baseline Code; Status = Generated.
    ///   - generated text unchanged -&gt; no-op.
    /// - Stored, developer HAS changed it (Current Hash &lt;&gt; Baseline Hash):
    ///   - generated text unchanged from baseline -&gt; keep the manual edit; Status = Modified.
    ///   - generated text changed -&gt; Status = Conflict; new text parked in Pending Code; Code
    ///     (the manual edit) is left untouched.
    /// </summary>
    /// <param name="ModuleCode">Owning module.</param>
    /// <param name="SegmentId">Stable, deterministic identifier for the segment (also the marker token).</param>
    /// <param name="ArtifactKind">Which generated file kind this segment belongs to.</param>
    /// <param name="ArtifactKey">Identifies WHICH file of that kind, e.g. the Helper Group name.</param>
    /// <param name="TableId">The BC table this segment was generated for, or 0 if not table-specific.</param>
    /// <param name="DataLevel">The Data Level of the owning table, if applicable.</param>
    /// <param name="FilePath">Relative path of the generated .al file.</param>
    /// <param name="SegmentKind">What kind of code fragment this is (procedure, global variable, ...).</param>
    /// <param name="SegmentName">Human-readable name, e.g. the procedure name.</param>
    /// <param name="SortOrder">Position within the file.</param>
    /// <param name="GeneratedText">The freshly generated text for this segment.</param>
    /// <returns>The reconciled "Code Segment" record.</returns>
    procedure Upsert(
        ModuleCode: Code[20];
        SegmentId: Text[100];
        ArtifactKind: Enum "Code Artifact Kind";
        ArtifactKey: Text[100];
        TableId: Integer;
        DataLevel: Enum "Data Level";
        FilePath: Text[250];
        SegmentKind: Enum "Code Segment Kind";
        SegmentName: Text[100];
        SortOrder: Integer;
        GeneratedText: Text): Record "Code Segment"
    var
        CodeSegment: Record "Code Segment";
        GeneratedHash: Text;
        DeveloperModified: Boolean;
        GeneratorChanged: Boolean;
    begin
        // Every CodeGen* ToString() bakes in a trailing separator terminator (TextBuilder.
        // AppendLine('')) that is not real segment content - strip it so stored/hashed text
        // matches the same convention "Segment Importer" normalizes re-imported text to.
        GeneratedText := this.StripTrailingNewline(GeneratedText);
        GeneratedHash := this.ComputeHash(GeneratedText);

        if not CodeSegment.Get(ModuleCode, SegmentId) then begin
            CodeSegment.Init();
            CodeSegment."Module Code" := ModuleCode;
            CodeSegment."Segment ID" := SegmentId;
            CodeSegment."Artifact Kind" := ArtifactKind;
            CodeSegment."Artifact Key" := ArtifactKey;
            CodeSegment."Table ID" := TableId;
            CodeSegment."Data Level" := DataLevel;
            CodeSegment."File Path" := FilePath;
            CodeSegment."Segment Kind" := SegmentKind;
            CodeSegment."Segment Name" := SegmentName;
            CodeSegment."Sort Order" := SortOrder;
            this.SetCode(CodeSegment, GeneratedText);
            this.SetBaselineCode(CodeSegment, GeneratedText);
            CodeSegment."Current Hash" := CopyStr(GeneratedHash, 1, MaxStrLen(CodeSegment."Current Hash"));
            CodeSegment."Baseline Hash" := CopyStr(GeneratedHash, 1, MaxStrLen(CodeSegment."Baseline Hash"));
            CodeSegment.Status := CodeSegment.Status::Generated;
            CodeSegment."Last Generated At" := CurrentDateTime();
            this.UpdateDerivedFields(CodeSegment, GeneratedText);
            CodeSegment.Insert(true);
            exit(CodeSegment);
        end;

        if CodeSegment.Locked then
            exit(CodeSegment);

        // Metadata (artifact/table/sort-order/etc.) can legitimately shift between runs
        // (e.g. a table moves to a different helper group) - always keep it current.
        CodeSegment."Artifact Kind" := ArtifactKind;
        CodeSegment."Artifact Key" := ArtifactKey;
        CodeSegment."Table ID" := TableId;
        CodeSegment."Data Level" := DataLevel;
        CodeSegment."File Path" := FilePath;
        CodeSegment."Segment Kind" := SegmentKind;
        CodeSegment."Segment Name" := SegmentName;
        CodeSegment."Sort Order" := SortOrder;

        DeveloperModified := CodeSegment."Current Hash" <> CodeSegment."Baseline Hash";
        GeneratorChanged := GeneratedHash <> CodeSegment."Baseline Hash";

        if not DeveloperModified then begin
            if GeneratorChanged then begin
                this.SetCode(CodeSegment, GeneratedText);
                this.SetBaselineCode(CodeSegment, GeneratedText);
                CodeSegment."Current Hash" := CopyStr(GeneratedHash, 1, MaxStrLen(CodeSegment."Current Hash"));
                CodeSegment."Baseline Hash" := CopyStr(GeneratedHash, 1, MaxStrLen(CodeSegment."Baseline Hash"));
                CodeSegment.Status := CodeSegment.Status::Generated;
                CodeSegment."Last Generated At" := CurrentDateTime();
                this.UpdateDerivedFields(CodeSegment, GeneratedText);
            end;
            // else: nothing changed anywhere - no-op.
        end else
            if not GeneratorChanged then
                CodeSegment.Status := CodeSegment.Status::Modified
            else begin
                this.SetPendingCode(CodeSegment, GeneratedText);
                CodeSegment."Pending Hash" := CopyStr(GeneratedHash, 1, MaxStrLen(CodeSegment."Pending Hash"));
                CodeSegment.Status := CodeSegment.Status::Conflict;
            end;

        CodeSegment.Modify(true);
        exit(CodeSegment);
    end;

    /// <summary>
    /// Marks every "Code Segment" for the module that was NOT part of the given set of segment
    /// IDs as Orphaned. Called once per sync, after every currently-generated segment has been
    /// passed through <see cref="Upsert"/>, so anything left over no longer has a generator
    /// producing it (e.g. its table was removed from the module).
    /// </summary>
    procedure MarkOrphanedExcept(ModuleCode: Code[20]; SeenSegmentIds: List of [Text])
    var
        CodeSegment: Record "Code Segment";
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        CodeSegment.SetFilter(Status, '<>%1', CodeSegment.Status::Orphaned);
        if not CodeSegment.FindSet() then
            exit;
        repeat
            if not SeenSegmentIds.Contains(CodeSegment."Segment ID") then begin
                CodeSegment.Status := CodeSegment.Status::Orphaned;
                CodeSegment.Modify(true);
            end;
        until CodeSegment.Next() = 0;
    end;

    /// <summary>
    /// Marks every "Code Segment" belonging to the given table as Orphaned (does NOT delete
    /// them - the developer's edits are preserved in case the table is re-added later).
    /// </summary>
    procedure MarkOrphanedForTable(ModuleCode: Code[20]; TableId: Integer)
    var
        CodeSegment: Record "Code Segment";
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        CodeSegment.SetRange("Table ID", TableId);
        if not CodeSegment.FindSet() then
            exit;
        repeat
            CodeSegment.Status := CodeSegment.Status::Orphaned;
            CodeSegment.Modify(true);
        until CodeSegment.Next() = 0;
    end;

    /// <summary>
    /// Promotes the parked "Pending Code" into "Code" for a Conflict segment, accepting the
    /// regenerated version and discarding the developer's manual edit.
    /// </summary>
    procedure AcceptPending(var CodeSegment: Record "Code Segment")
    var
        PendingText: Text;
    begin
        PendingText := this.GetPendingCode(CodeSegment);
        this.SetCode(CodeSegment, PendingText);
        this.SetBaselineCode(CodeSegment, PendingText);
        CodeSegment."Current Hash" := CodeSegment."Pending Hash";
        CodeSegment."Baseline Hash" := CodeSegment."Pending Hash";
        this.ClearPendingCode(CodeSegment);
        CodeSegment."Pending Hash" := '';
        CodeSegment.Status := CodeSegment.Status::Generated;
        CodeSegment."Last Generated At" := CurrentDateTime();
        this.UpdateDerivedFields(CodeSegment, PendingText);
        CodeSegment.Modify(true);
    end;

    /// <summary>
    /// Dismisses a Conflict in favor of the developer's manual edit: the parked "Pending Code"
    /// (the newer generated version) becomes the new "Baseline Code" WITHOUT changing "Code", so
    /// the conflict does not simply reappear on the next sync (the generator's next output will
    /// again match this new baseline, unless it changes further). Status becomes Modified, since
    /// "Code" still intentionally differs from the (now updated) baseline.
    /// </summary>
    procedure KeepMine(var CodeSegment: Record "Code Segment")
    var
        PendingText: Text;
    begin
        PendingText := this.GetPendingCode(CodeSegment);
        this.SetBaselineCode(CodeSegment, PendingText);
        CodeSegment."Baseline Hash" := CodeSegment."Pending Hash";
        this.ClearPendingCode(CodeSegment);
        CodeSegment."Pending Hash" := '';
        CodeSegment.Status := CodeSegment.Status::Modified;
        CodeSegment.Modify(true);
    end;

    /// <summary>
    /// Discards the developer's manual edit, resetting "Code" back to the last-generated
    /// ("Baseline Code") text. Also clears any parked "Pending Code" left over from a Conflict,
    /// since it no longer applies once "Code" matches the baseline again.
    /// </summary>
    procedure RevertToBaseline(var CodeSegment: Record "Code Segment")
    var
        BaselineText: Text;
    begin
        BaselineText := this.GetBaselineCode(CodeSegment);
        this.SetCode(CodeSegment, BaselineText);
        CodeSegment."Current Hash" := CodeSegment."Baseline Hash";
        this.ClearPendingCode(CodeSegment);
        CodeSegment."Pending Hash" := '';
        CodeSegment.Status := CodeSegment.Status::Generated;
        this.UpdateDerivedFields(CodeSegment, BaselineText);
        CodeSegment.Modify(true);
    end;

    /// <summary>
    /// Reverts every segment in the module back to its last-generated ("Baseline Code") text,
    /// discarding all manual edits and any parked Pending Code - a full "start fresh" reset.
    /// Skips Locked segments (Locked is a stronger, explicit signal than a bulk revert) and
    /// Manual segments (they have no generator-produced baseline to revert TO - reverting one
    /// would incorrectly relabel it as Generated even though nothing was ever generated for it;
    /// delete a Manual segment directly instead if you want it gone).
    /// </summary>
    procedure RevertModuleToBaseline(ModuleCode: Code[20])
    var
        CodeSegment: Record "Code Segment";
    begin
        CodeSegment.SetRange("Module Code", ModuleCode);
        CodeSegment.SetRange(Locked, false);
        CodeSegment.SetFilter(Status, '<>%1', CodeSegment.Status::Manual);
        if not CodeSegment.FindSet() then
            exit;
        repeat
            this.RevertToBaseline(CodeSegment);
        until CodeSegment.Next() = 0;
    end;

    /// <summary>
    /// Overwrites "Code" with developer-supplied text (e.g. from the marker-based .al importer),
    /// updates "Current Hash", and sets Status to Modified/Conflict/Generated depending on how
    /// the new text compares to the baseline.
    /// </summary>
    procedure ApplyImportedText(var CodeSegment: Record "Code Segment"; ImportedText: Text)
    var
        ImportedHash: Text;
    begin
        ImportedHash := this.ComputeHash(ImportedText);
        this.SetCode(CodeSegment, ImportedText);
        CodeSegment."Current Hash" := CopyStr(ImportedHash, 1, MaxStrLen(CodeSegment."Current Hash"));
        CodeSegment."Last Import At" := CurrentDateTime();
        if ImportedHash = CodeSegment."Baseline Hash" then
            CodeSegment.Status := CodeSegment.Status::Generated
        else
            CodeSegment.Status := CodeSegment.Status::Modified;
        this.UpdateDerivedFields(CodeSegment, ImportedText);
        CodeSegment.Modify(true);
    end;

    procedure GetCode(var CodeSegment: Record "Code Segment"): Text
    begin
        exit(this.GetBlobAsText(CodeSegment, CodeSegment.FieldNo("Code")));
    end;

    procedure SetCode(var CodeSegment: Record "Code Segment"; NewText: Text)
    begin
        this.SetBlobFromText(CodeSegment, CodeSegment.FieldNo("Code"), NewText);
    end;

    procedure GetBaselineCode(var CodeSegment: Record "Code Segment"): Text
    begin
        exit(this.GetBlobAsText(CodeSegment, CodeSegment.FieldNo("Baseline Code")));
    end;

    procedure SetBaselineCode(var CodeSegment: Record "Code Segment"; NewText: Text)
    begin
        this.SetBlobFromText(CodeSegment, CodeSegment.FieldNo("Baseline Code"), NewText);
    end;

    procedure GetPendingCode(var CodeSegment: Record "Code Segment"): Text
    begin
        exit(this.GetBlobAsText(CodeSegment, CodeSegment.FieldNo("Pending Code")));
    end;

    procedure SetPendingCode(var CodeSegment: Record "Code Segment"; NewText: Text)
    begin
        this.SetBlobFromText(CodeSegment, CodeSegment.FieldNo("Pending Code"), NewText);
    end;

    procedure ClearPendingCode(var CodeSegment: Record "Code Segment")
    begin
        this.SetBlobFromText(CodeSegment, CodeSegment.FieldNo("Pending Code"), '');
    end;

    local procedure GetBlobAsText(var CodeSegment: Record "Code Segment"; BlobFieldNo: Integer): Text
    var
        TempBlob: Codeunit "Temp Blob";
        RecRef: RecordRef;
        InStr: InStream;
        Result: Text;
        Line: Text;
        IsFirstLine: Boolean;
    begin
        RecRef.GetTable(CodeSegment);
        RecRef.Field(BlobFieldNo).CalcField(); // Blob fields are lazily loaded - force-load before copying
        TempBlob.FromRecordRef(RecRef, BlobFieldNo);
        if not TempBlob.HasValue() then
            exit('');
        TempBlob.CreateInStream(InStr, TextEncoding::UTF8);
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

    local procedure SetBlobFromText(var CodeSegment: Record "Code Segment"; BlobFieldNo: Integer; NewText: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        RecRef: RecordRef;
        OutStr: OutStream;
    begin
        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(NewText);
        RecRef.GetTable(CodeSegment);
        TempBlob.ToRecordRef(RecRef, BlobFieldNo);
        RecRef.SetTable(CodeSegment);
    end;

    /// <summary>
    /// Computes a deterministic, order-independent content fingerprint of arbitrary-length text
    /// using four independent Adler-32-style rolling checksums (each kept modulo a distinct
    /// prime below 2^16 at every step, so plain 32-bit Integer arithmetic never overflows).
    /// Self-contained on purpose - see "CodeGen Reference Value" for the same rationale applied
    /// to a shorter, identifier-safe variant of this idea.
    /// </summary>
    procedure ComputeHash(Input: Text): Text
    var
        Modulo1, Modulo2, Modulo3, Modulo4 : Integer;
        ChecksumA1, ChecksumB1 : Integer;
        ChecksumA2, ChecksumB2 : Integer;
        CharCode: Integer;
        i: Integer;
    begin
        Modulo1 := 65521; // largest prime below 2^16
        Modulo2 := 65519;
        Modulo3 := 65497;
        Modulo4 := 65479;
        ChecksumA1 := 1;
        ChecksumB1 := 0;
        ChecksumA2 := 1;
        ChecksumB2 := 0;
        for i := 1 to StrLen(Input) do begin
            CharCode := Input[i];
            ChecksumA1 := (ChecksumA1 + CharCode) mod Modulo1;
            ChecksumB1 := (ChecksumB1 + ChecksumA1) mod Modulo2;
            ChecksumA2 := (ChecksumA2 + CharCode) mod Modulo3;
            ChecksumB2 := (ChecksumB2 + ChecksumA2) mod Modulo4;
        end;
        exit(this.ToHex4(ChecksumA1) + this.ToHex4(ChecksumB1) + this.ToHex4(ChecksumA2) + this.ToHex4(ChecksumB2));
    end;

    local procedure ToHex4(Value: Integer): Text
    var
        HexDigits: Text;
        Result: Text;
        Nibble: Integer;
        i: Integer;
    begin
        HexDigits := '0123456789ABCDEF';
        for i := 1 to 4 do begin
            Nibble := Value mod 16;
            Result := CopyStr(HexDigits, Nibble + 1, 1) + Result;
            Value := Value div 16;
        end;
        exit(Result);
    end;

    /// <summary>
    /// Recomputes "Line Count" and "Preview" from the given text. Public so "Segment Importer"
    /// can keep these derived fields consistent when inserting a new Manual Block segment.
    /// </summary>
    procedure UpdateDerivedFields(var CodeSegment: Record "Code Segment"; SegmentText: Text)
    begin
        CodeSegment."Line Count" := this.CountLines(SegmentText);
        CodeSegment.Preview := this.GetPreview(SegmentText);
    end;

    local procedure CountLines(SegmentText: Text): Integer
    var
        Lines: List of [Text];
    begin
        if SegmentText = '' then
            exit(0);
        Lines := SegmentText.Split(NewLine());
        exit(Lines.Count());
    end;

    /// <summary>
    /// Returns the first non-blank line of the given text, trimmed and truncated to fit
    /// "Code Segment".Preview, so the segment list can be scanned without opening every record.
    /// </summary>
    local procedure GetPreview(SegmentText: Text): Text[250]
    var
        CodeSegment: Record "Code Segment";
        Lines: List of [Text];
        Line: Text;
        TrimmedLine: Text;
    begin
        if SegmentText = '' then
            exit('');
        Lines := SegmentText.Split(NewLine());
        foreach Line in Lines do begin
            TrimmedLine := Line.Trim();
            if TrimmedLine <> '' then
                exit(CopyStr(TrimmedLine, 1, MaxStrLen(CodeSegment.Preview)));
        end;
        exit('');
    end;

    /// <summary>
    /// Returns a Text containing a carriage-return + line-feed (CRLF) - the default line
    /// terminator TextBuilder.AppendLine uses (confirmed via MS Learn), which is what every
    /// CodeGen* ToString() method (built on TextBuilder) actually emits. Must match exactly, or
    /// GetBlobAsText's line-by-line blob read-back silently downgrades CRLF to LF when rejoining,
    /// making stored text never equal freshly-imported/normalized text (see "Segment Importer"
    /// NewLine, which already used CRLF). AL string literals do not support escape sequences such
    /// as "\n" - this is the correct way to obtain actual newline characters to join/split on.
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

    /// <summary>
    /// Strips a single trailing CRLF, if present. Every CodeGen* ToString() method ends its own
    /// text with a trailing TextBuilder.AppendLine('') (e.g. "CodeGen Procedure".ToString), so
    /// GeneratedText passed into Upsert always carries one extra trailing terminator that is NOT
    /// really part of the segment's content - it's file-assembly separator formatting. Without
    /// stripping it here, the stored "Code"/"Baseline Code" would keep that trailing terminator
    /// forever, while re-importing the very same generated text always strips it (see "Segment
    /// Importer".StripTrailingNewline), so the two could never compare equal - every multi-line
    /// segment would spuriously look "Modified" on first re-import even with zero real edits.
    /// </summary>
    local procedure StripTrailingNewline(Input: Text): Text
    begin
        if Input = '' then
            exit('');
        if Input.EndsWith(this.NewLine()) then
            exit(CopyStr(Input, 1, StrLen(Input) - StrLen(this.NewLine())));
        exit(Input);
    end;
}
