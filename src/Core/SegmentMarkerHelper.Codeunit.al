namespace SimonOfHH.DemoData.Core;

/// <summary>
/// Builds and parses the marker comments that wrap each generated "Code Segment" inside a
/// generated .al file, e.g. `    // &gt;&gt;&gt; DDG HELPER.BANK.INSERT.36`. These markers are what let
/// the (future) marker-based .al importer split an edited file back into segments without an
/// AL parser - it just looks for these comment lines.
/// </summary>
codeunit 70140 "Segment Marker Helper"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        StartTokenTok: Label '// >>> DDG %1', Comment = '%1 = Segment ID', Locked = true;
        EndTokenTok: Label '// <<< DDG %1', Comment = '%1 = Segment ID', Locked = true;
        StartPrefixTok: Label '// >>> DDG ', Locked = true;
        EndPrefixTok: Label '// <<< DDG ', Locked = true;

    /// <summary>
    /// Returns the start marker comment line for the given segment, indented by the given
    /// number of 4-space levels (0 for file-level segments such as the header/footer, 1 for
    /// segments that live inside the object body such as procedures).
    /// </summary>
    procedure BuildStartMarker(SegmentId: Text; IndentLevel: Integer): Text
    begin
        exit(this.GetIndent(IndentLevel) + StrSubstNo(this.StartTokenTok, SegmentId));
    end;

    /// <summary>
    /// Returns the end marker comment line for the given segment - see <see cref="BuildStartMarker"/>.
    /// </summary>
    procedure BuildEndMarker(SegmentId: Text; IndentLevel: Integer): Text
    begin
        exit(this.GetIndent(IndentLevel) + StrSubstNo(this.EndTokenTok, SegmentId));
    end;

    /// <summary>
    /// Checks whether the given source line is a start or end marker and, if so, returns the
    /// Segment ID it carries.
    /// </summary>
    /// <param name="SourceLine">One line of a generated/edited .al file.</param>
    /// <param name="IsStartMarker">Set to true if this is a start marker, false if it is an end marker.</param>
    /// <param name="SegmentId">The Segment ID extracted from the marker, or '' if the line is not a marker.</param>
    /// <returns>True if the line is a marker line.</returns>
    procedure TryParseMarker(SourceLine: Text; var IsStartMarker: Boolean; var SegmentId: Text): Boolean
    var
        TrimmedLine: Text;
    begin
        TrimmedLine := SourceLine.Trim();
        if TrimmedLine.StartsWith(this.StartPrefixTok) then begin
            IsStartMarker := true;
            SegmentId := TrimmedLine.Substring(StrLen(this.StartPrefixTok) + 1).Trim();
            exit(true);
        end;
        if TrimmedLine.StartsWith(this.EndPrefixTok) then begin
            IsStartMarker := false;
            SegmentId := TrimmedLine.Substring(StrLen(this.EndPrefixTok) + 1).Trim();
            exit(true);
        end;
        exit(false);
    end;

    local procedure GetIndent(IndentLevel: Integer): Text
    var
        Result: TextBuilder;
        i: Integer;
    begin
        for i := 1 to IndentLevel * 4 do
            Result.Append(' ');
        exit(Result.ToText());
    end;
}
