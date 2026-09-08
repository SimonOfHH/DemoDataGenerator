namespace SimonOfHH.DemoData.Segments;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Export;
using SimonOfHH.DemoData.Core;

/// <summary>
/// Runs the same generators the export path uses, decomposes their output into segments, and
/// reconciles each one against the "Code Segment Store" so hand-edited segments are preserved.
/// Must run before "Segment File Assembler" builds file text, since the assembler only reads
/// what is already stored - it never generates anything itself.
/// </summary>
codeunit 70141 "Segment Sync Manager"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        CodeSegmentStore: Codeunit "Code Segment Store";
        ALFormatter: Codeunit "AL Formatter";

    /// <summary>
    /// Regenerates every AST node for the module (via a freshly-built "CodeGen Module
    /// Container") and reconciles each of their segments. Equivalent to calling
    /// SyncFromContainer with a container built by "Export Orchestrator".GenerateModule.
    /// </summary>
    procedure Sync(ModuleDef: Record "Module Definition")
    var
        ExportOrchestrator: Codeunit "Export Orchestrator";
        ModuleContainer: Codeunit "CodeGen Module Container";
    begin
        ExportOrchestrator.GenerateModule(ModuleDef, ModuleContainer);
        this.SyncFromContainer(ModuleDef, ModuleContainer);
    end;

    /// <summary>
    /// Reconciles every AST node already present in the given (caller-built) ModuleContainer.
    /// Use this overload when the caller already needs the container for another purpose (e.g.
    /// "Export Orchestrator".Run also uses it for ID-range validation) to avoid generating the
    /// module twice. Segments belonging to artifacts no longer produced this run (e.g. a removed
    /// table's data codeunit) are marked Orphaned, not deleted.
    /// </summary>
    procedure SyncFromContainer(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container")
    var
        HelperCU: Codeunit "CodeGen Codeunit";
        DataCU: Codeunit "CodeGen Codeunit";
        SeenSegmentIds: List of [Text];
    begin
        this.SyncEnumExtension(ModuleDef, ModuleContainer.GetEnumExtension(), SeenSegmentIds);
        this.SyncCodeunit(ModuleDef, ModuleContainer.GetModuleCodeunit(), "Code Artifact Kind"::"Module Codeunit", 0, SeenSegmentIds);

        foreach HelperCU in ModuleContainer.GetHelperCodeunits() do
            this.SyncCodeunit(ModuleDef, HelperCU, "Code Artifact Kind"::"Helper Codeunit", 0, SeenSegmentIds);

        foreach DataCU in ModuleContainer.GetDataCodeunits() do
            this.SyncCodeunit(
                ModuleDef, DataCU, "Code Artifact Kind"::"Data Codeunit",
                this.FindTableIdForDataCodeunit(ModuleDef.Code, DataCU.Name()), SeenSegmentIds);

        // Note: the App Manifest is deliberately NOT synced - it is JSON, cannot carry comment
        // markers, and stays whole-file/always-regenerated (see Phase 0 hard constraints).
        this.CodeSegmentStore.MarkOrphanedExcept(ModuleDef.Code, SeenSegmentIds);
    end;

    local procedure SyncEnumExtension(ModuleDef: Record "Module Definition"; EnumExt: Codeunit "CodeGen Enum Extension"; var SeenSegmentIds: List of [Text])
    var
        NoDataLevel: Enum "Data Level";
        ArtifactKey: Text[100];
        FilePath: Text[250];
    begin
        if EnumExt.Name() = '' then
            exit;
        ArtifactKey := CopyStr(EnumExt.Name(), 1, MaxStrLen(ArtifactKey));
        FilePath := CopyStr('src/' + this.ALFormatter.SanitizeIdentifier(ModuleDef.Name) + 'ModuleEnum.EnumExt.al', 1, MaxStrLen(FilePath));

        this.UpsertAndTrack(
            ModuleDef.Code, this.BuildSegmentId(ArtifactKey, 'HEADER', ''), "Code Artifact Kind"::"Enum Extension", ArtifactKey,
            0, NoDataLevel, FilePath, "Code Segment Kind"::"File Header", 'Header', 0, EnumExt.GetHeaderText(), SeenSegmentIds);
        this.UpsertAndTrack(
            ModuleDef.Code, this.BuildSegmentId(ArtifactKey, 'BODY', ''), "Code Artifact Kind"::"Enum Extension", ArtifactKey,
            0, NoDataLevel, FilePath, "Code Segment Kind"::"Property", 'Enum Value', 10, EnumExt.GetBodyText(), SeenSegmentIds);
        this.UpsertAndTrack(
            ModuleDef.Code, this.BuildSegmentId(ArtifactKey, 'FOOTER', ''), "Code Artifact Kind"::"Enum Extension", ArtifactKey,
            0, NoDataLevel, FilePath, "Code Segment Kind"::"File Footer", 'Footer', 20, EnumExt.GetFooterText(), SeenSegmentIds);
    end;

    local procedure SyncCodeunit(
        ModuleDef: Record "Module Definition";
        CU: Codeunit "CodeGen Codeunit";
        ArtifactKind: Enum "Code Artifact Kind";
        TableId: Integer;
        var SeenSegmentIds: List of [Text])
    var
        TriggerProc: Codeunit "CodeGen Procedure";
        RegularProc: Codeunit "CodeGen Procedure";
        RefValue: Codeunit "CodeGen Reference Value";
        ArtifactKey: Text[100];
        FilePath: Text[250];
        DataLevel: Enum "Data Level";
        VarSectionText: Text;
        SortOrder: Integer;
    begin
        if CU.Name() = '' then
            exit; // Not generated this run (e.g. no Document Group/table produced it)

        ArtifactKey := CopyStr(CU.Name(), 1, MaxStrLen(ArtifactKey));
        DataLevel := CU.DataLevel();
        FilePath := this.GetFilePath(ArtifactKind, CU, ModuleDef);
        SortOrder := 0;

        this.UpsertAndTrack(
            ModuleDef.Code, this.BuildSegmentId(ArtifactKey, 'HEADER', ''), ArtifactKind, ArtifactKey, TableId,
            DataLevel, FilePath, "Code Segment Kind"::"File Header", 'Header', SortOrder, CU.GetHeaderText(), SeenSegmentIds);
        SortOrder += 10;

        foreach TriggerProc in CU.GetTriggerProcedures() do begin
            this.UpsertAndTrack(
                ModuleDef.Code, this.BuildSegmentId(ArtifactKey, 'TRIGGER', this.ALFormatter.SanitizeIdentifier(TriggerProc.GetName())),
                ArtifactKind, ArtifactKey, TableId, DataLevel, FilePath, "Code Segment Kind"::"Trigger",
                CopyStr(TriggerProc.GetName(), 1, 100), SortOrder, TriggerProc.ToString(1), SeenSegmentIds);
            SortOrder += 10;
        end;

        foreach RegularProc in CU.GetRegularProcedures() do begin
            this.UpsertAndTrack(
                ModuleDef.Code, this.BuildSegmentId(ArtifactKey, 'PROC', this.ALFormatter.SanitizeIdentifier(RegularProc.GetName())),
                ArtifactKind, ArtifactKey, TableId, DataLevel, FilePath, "Code Segment Kind"::"Procedure",
                CopyStr(RegularProc.GetName(), 1, 100), SortOrder, RegularProc.ToString(1), SeenSegmentIds);
            SortOrder += 10;
        end;

        foreach RefValue in CU.GetReferenceValues() do begin
            this.UpsertAndTrack(
                ModuleDef.Code, this.BuildSegmentId(ArtifactKey, 'REF', RefValue.ProcedureName()),
                ArtifactKind, ArtifactKey, TableId, DataLevel, FilePath, "Code Segment Kind"::"Reference Value",
                CopyStr(RefValue.ProcedureName(), 1, 100), SortOrder, RefValue.ToString(1), SeenSegmentIds);
            SortOrder += 10;
        end;

        VarSectionText := CU.GetVarSectionText();
        if VarSectionText <> '' then begin
            this.UpsertAndTrack(
                ModuleDef.Code, this.BuildSegmentId(ArtifactKey, 'VAR', ''), ArtifactKind, ArtifactKey, TableId,
                DataLevel, FilePath, "Code Segment Kind"::"Global Variable", 'Global Variables', SortOrder, VarSectionText, SeenSegmentIds);
            SortOrder += 10;
        end;

        this.UpsertAndTrack(
            ModuleDef.Code, this.BuildSegmentId(ArtifactKey, 'FOOTER', ''), ArtifactKind, ArtifactKey, TableId,
            DataLevel, FilePath, "Code Segment Kind"::"File Footer", 'Footer', SortOrder, CU.GetFooterText(), SeenSegmentIds);
    end;

    /// <summary>
    /// Reproduces the relative output path used by "Export Orchestrator".AssembleZip for the
    /// given codeunit artifact, so a segment's stored File Path always matches where it will
    /// actually be written in the exported zip.
    /// </summary>
    local procedure GetFilePath(ArtifactKind: Enum "Code Artifact Kind"; CU: Codeunit "CodeGen Codeunit"; ModuleDef: Record "Module Definition"): Text[250]
    var
        ExportOrchestrator: Codeunit "Export Orchestrator";
        ModuleSafe: Text;
        Result: Text;
    begin
        ModuleSafe := this.ALFormatter.SanitizeIdentifier(ModuleDef.Name);
        case ArtifactKind of
            "Code Artifact Kind"::"Module Codeunit":
                Result := 'src/' + ModuleSafe + 'Module.Codeunit.al';
            "Code Artifact Kind"::"Helper Codeunit":
                Result := 'src/Helpers/' + this.ALFormatter.SanitizeIdentifier(CU.Name()) + '.Codeunit.al';
            "Code Artifact Kind"::"Data Codeunit":
                Result := 'src/' + ExportOrchestrator.GetDataLevelFolder(CU.DataLevel()) + this.ALFormatter.SanitizeIdentifier(CU.Name()) + '.Codeunit.al';
        end;
        exit(CopyStr(Result, 1, 250));
    end;

    /// <summary>
    /// Finds the Table ID whose "Table Selection"."Data Codeunit Name" matches the given data
    /// codeunit, so its segments can be scoped to that table (0 if none matches, e.g. a
    /// Document Group stub codeunit that is not owned by a single table).
    /// </summary>
    local procedure FindTableIdForDataCodeunit(ModuleCode: Code[20]; DataCodeunitName: Text): Integer
    var
        TableSelection: Record "Table Selection";
    begin
        TableSelection.SetRange("Module Code", ModuleCode);
        TableSelection.SetRange("Data Codeunit Name", CopyStr(DataCodeunitName, 1, MaxStrLen(TableSelection."Data Codeunit Name")));
        if TableSelection.FindFirst() then
            exit(TableSelection."Table ID");
        exit(0);
    end;

    /// <summary>
    /// Builds a stable, deterministic Segment ID (also used verbatim as the marker token) from
    /// the owning artifact's name, a segment-kind tag, and an optional detail name. MUST remain
    /// independent of processing order - callers must NOT include any position/index in it.
    /// </summary>
    local procedure BuildSegmentId(ArtifactKey: Text; SegmentTag: Text; DetailName: Text): Text[100]
    var
        CodeSegment: Record "Code Segment";
        Result: Text;
    begin
        Result := this.ALFormatter.SanitizeIdentifier(ArtifactKey) + '.' + SegmentTag;
        if DetailName <> '' then
            Result += '.' + DetailName;
        exit(CopyStr(Result, 1, MaxStrLen(CodeSegment."Segment ID")));
    end;

    local procedure UpsertAndTrack(
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
        GeneratedText: Text;
        var SeenSegmentIds: List of [Text])
    begin
        this.CodeSegmentStore.Upsert(
            ModuleCode, SegmentId, ArtifactKind, ArtifactKey, TableId, DataLevel, FilePath, SegmentKind, SegmentName, SortOrder, GeneratedText);
        if not SeenSegmentIds.Contains(SegmentId) then
            SeenSegmentIds.Add(SegmentId);
    end;
}
