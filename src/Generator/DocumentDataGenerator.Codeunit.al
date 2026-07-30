namespace SimonOfHH.DemoData.Generator;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Core;

/// <summary>
/// Captures Transaction/Historical data as JSON snapshots instead of literal AL Insert calls.
/// Document Groups are captured as one nested JSON file per group (Header rows with correlated
/// Line rows nested underneath); standalone Transaction/Historical tables (no Document Group)
/// fall back to a flat, per-table JSON array. Each captured snapshot is paired with a stub data
/// codeunit whose OnRun trigger points at the JSON file and the bundled Copilot prompt, instead
/// of generating (unreliable) literal Insert calls for documents/postings.
/// </summary>
codeunit 70137 "Document Data Generator"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        ALFormatter: Codeunit "AL Formatter";
        StubTodoLbl: Label '// TODO: Implement using the data captured in "%1". See .github/prompts/generate-transaction-data.prompt.md for guidance - attach the relevant BC symbols (standard or bespoke) and ask Copilot to generate this codeunit.', Comment = '%1 = JSON sidecar file name', Locked = true;

    /// <summary>
    /// Generates one JSON snapshot + stub data codeunit per Document Group, and per standalone
    /// (ungrouped) Transaction/Historical table, for the given module.
    /// </summary>
    procedure Generate(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container")
    var
        DocumentGroup: Record "Document Group";
        TableSelection: Record "Table Selection";
    begin
        DocumentGroup.SetRange("Module Code", ModuleDef.Code);
        if DocumentGroup.FindSet() then
            repeat
                this.GenerateForGroup(ModuleDef, DocumentGroup, ModuleContainer);
            until DocumentGroup.Next() = 0;

        TableSelection.SetRange("Module Code", ModuleDef.Code);
        TableSelection.SetFilter("Data Level", '%1|%2', TableSelection."Data Level"::"Transaction Data", TableSelection."Data Level"::"Historical Data");
        TableSelection.SetRange("Document Group Code", '');
        TableSelection.SetCurrentKey("Module Code", "Data Level", "Sort Order");
        if TableSelection.FindSet() then
            repeat
                this.GenerateForStandaloneTable(ModuleDef, TableSelection, ModuleContainer);
            until TableSelection.Next() = 0;
    end;

    local procedure GenerateForGroup(ModuleDef: Record "Module Definition"; DocumentGroup: Record "Document Group"; var ModuleContainer: Codeunit "CodeGen Module Container")
    var
        HeaderTableSelection: Record "Table Selection";
        StubCU: Codeunit "CodeGen Codeunit";
        DataFile: Codeunit "CodeGen Data File";
        HeaderRecRef: RecordRef;
        HeaderTableId: Integer;
        JsonText, FileName, CodeunitName : Text;
        DocumentObject: JsonObject;
        DocumentsArray: JsonArray;
    begin
        HeaderTableId := DocumentGroup.GetHeaderTableID();
        if HeaderTableId = 0 then
            exit; // Group has no Header table configured yet; validation should prevent generation reaching this point.
        if not HeaderTableSelection.Get(ModuleDef.Code, HeaderTableId) then
            exit;

        HeaderRecRef.Open(HeaderTableId);
        if HeaderTableSelection."Table View" <> '' then
            HeaderRecRef.SetView(HeaderTableSelection."Table View");
        if HeaderRecRef.FindSet() then
            repeat
                Clear(DocumentObject);
                DocumentObject := this.BuildRowObject(ModuleDef.Code, HeaderTableId, HeaderRecRef);
                this.AddLinesToDocument(ModuleDef, DocumentGroup, HeaderRecRef, DocumentObject);
                DocumentsArray.Add(DocumentObject);
            until HeaderRecRef.Next() = 0;
        HeaderRecRef.Close();

        DocumentsArray.WriteTo(JsonText);
        FileName := this.ALFormatter.SanitizeIdentifier(DocumentGroup."Name") + '.data.json';

        CodeunitName := DocumentGroup.GetEffectiveDataCodeunitName();

        StubCU := this.BuildStubCodeunit(ModuleContainer.GetNextCodeunitId(true), CodeunitName, DocumentGroup."Data Level", FileName);
        ModuleContainer.AddDataCodeunit(StubCU);

        DataFile.Initialize(FileName, JsonText, DocumentGroup."Data Level");
        ModuleContainer.AddDataFile(DataFile);
    end;

    local procedure GenerateForStandaloneTable(ModuleDef: Record "Module Definition"; TableSelection: Record "Table Selection"; var ModuleContainer: Codeunit "CodeGen Module Container")
    var
        StubCU: Codeunit "CodeGen Codeunit";
        DataFile: Codeunit "CodeGen Data File";
        RecRef: RecordRef;
        JsonText, FileName : Text;
        RowsArray: JsonArray;
    begin
        RecRef.Open(TableSelection."Table ID");
        if TableSelection."Table View" <> '' then
            RecRef.SetView(TableSelection."Table View");
        if RecRef.FindSet() then
            repeat
                RowsArray.Add(this.BuildRowObject(ModuleDef.Code, TableSelection."Table ID", RecRef));
            until RecRef.Next() = 0;
        RecRef.Close();

        RowsArray.WriteTo(JsonText);
        FileName := this.ALFormatter.SanitizeIdentifier(TableSelection."Table Name") + '.data.json';

        StubCU := this.BuildStubCodeunit(ModuleContainer.GetNextCodeunitId(true), TableSelection."Data Codeunit Name", TableSelection."Data Level", FileName);
        ModuleContainer.AddDataCodeunit(StubCU);

        DataFile.Initialize(FileName, JsonText, TableSelection."Data Level");
        ModuleContainer.AddDataFile(DataFile);
    end;

    /// <summary>
    /// Adds one nested JSON array per Line-role member table of the group, filtered to only
    /// the rows correlated to the current Header row via that member's Document Group Link
    /// field mappings.
    /// </summary>
    local procedure AddLinesToDocument(ModuleDef: Record "Module Definition"; DocumentGroup: Record "Document Group"; var HeaderRecRef: RecordRef; var DocumentObject: JsonObject)
    var
        LineTableSelection: Record "Table Selection";
        LineRecRef: RecordRef;
        LineArray: JsonArray;
    begin
        LineTableSelection.SetRange("Module Code", ModuleDef.Code);
        LineTableSelection.SetRange("Document Group Code", DocumentGroup.Code);
        LineTableSelection.SetRange("Group Role", LineTableSelection."Group Role"::Line);
        if LineTableSelection.FindSet() then
            repeat
                Clear(LineArray);
                LineRecRef.Open(LineTableSelection."Table ID");
                if LineTableSelection."Table View" <> '' then
                    LineRecRef.SetView(LineTableSelection."Table View");
                this.ApplyGroupLinkFilters(ModuleDef.Code, LineTableSelection."Table ID", HeaderRecRef, LineRecRef);
                if LineRecRef.FindSet() then
                    repeat
                        LineArray.Add(this.BuildRowObject(ModuleDef.Code, LineTableSelection."Table ID", LineRecRef));
                    until LineRecRef.Next() = 0;
                LineRecRef.Close();
                DocumentObject.Add(LineTableSelection."Table Name", LineArray);
            until LineTableSelection.Next() = 0;
    end;

    /// <summary>
    /// Applies one equality filter per configured Document Group Link field pair, correlating
    /// the Line table's rows to the current Header row.
    /// </summary>
    local procedure ApplyGroupLinkFilters(ModuleCode: Code[20]; LineTableId: Integer; var HeaderRecRef: RecordRef; var LineRecRef: RecordRef)
    var
        DocumentGroupLink: Record "Document Group Link";
        HeaderFldRef: FieldRef;
        LineFldRef: FieldRef;
    begin
        DocumentGroupLink.SetRange("Module Code", ModuleCode);
        DocumentGroupLink.SetRange("Table ID", LineTableId);
        if DocumentGroupLink.FindSet() then
            repeat
                HeaderFldRef := HeaderRecRef.Field(DocumentGroupLink."Header Field No.");
                LineFldRef := LineRecRef.Field(DocumentGroupLink."Child Field No.");
                LineFldRef.SetRange(HeaderFldRef.Value);
            until DocumentGroupLink.Next() = 0;
    end;

    /// <summary>
    /// Builds a flat JSON object for one record: one property per non-excluded Field
    /// Configuration entry, keyed by Field Name.
    /// </summary>
    local procedure BuildRowObject(ModuleCode: Code[20]; TableId: Integer; var RecRef: RecordRef): JsonObject
    var
        FieldConfig: Record "Field Configuration";
        FldRef: FieldRef;
        RowObject: JsonObject;
    begin
        FieldConfig.SetRange("Module Code", ModuleCode);
        FieldConfig.SetRange("Table ID", TableId);
        FieldConfig.SetFilter(Behavior, '<>%1', FieldConfig.Behavior::Exclude);
        FieldConfig.SetCurrentKey("Module Code", "Table ID", "Sort Order");
        if FieldConfig.FindSet() then
            repeat
                FldRef := RecRef.Field(FieldConfig."Field No.");
                this.AddFieldToRowObject(RowObject, FieldConfig."Field Name", FldRef);
            until FieldConfig.Next() = 0;
        exit(RowObject);
    end;

    /// <summary>
    /// Adds one field's live value to the row's JSON object. Numeric/Boolean types keep their
    /// native JSON representation; everything else (Date, Code, Enum/Option, Guid, etc.) is
    /// captured as its formatted display text so the raw snapshot stays human/Copilot-readable.
    /// </summary>
    local procedure AddFieldToRowObject(var RowObject: JsonObject; FieldName: Text[100]; FldRef: FieldRef)
    var
        DecimalValue: Decimal;
        BooleanValue: Boolean;
    begin
        case FldRef.Type of
            FieldType::Integer, FieldType::BigInteger, FieldType::Decimal:
                begin
                    DecimalValue := FldRef.Value;
                    RowObject.Add(FieldName, DecimalValue);
                end;
            FieldType::Boolean:
                begin
                    BooleanValue := FldRef.Value;
                    RowObject.Add(FieldName, BooleanValue);
                end;
            else
                RowObject.Add(FieldName, Format(FldRef.Value));
        end;
    end;

    local procedure BuildStubCodeunit(ObjectId: Integer; CodeunitName: Text; DataLevel: Enum "Data Level"; JsonFileName: Text): Codeunit "CodeGen Codeunit"
    var
        StubCU: Codeunit "CodeGen Codeunit";
        OnRunProc: Codeunit "CodeGen Procedure";
    begin
        StubCU.Initialize(ObjectId, CodeunitName);
        StubCU.DataLevel(DataLevel);
        StubCU.AddProperty('InherentEntitlements', 'X');
        StubCU.AddProperty('InherentPermissions', 'X');

        OnRunProc.Init('OnRun');
        OnRunProc.SetTrigger(true);
        OnRunProc.AddCodeLine(StrSubstNo(this.StubTodoLbl, JsonFileName));
        StubCU.AddProcedure(OnRunProc);

        exit(StubCU);
    end;
}
