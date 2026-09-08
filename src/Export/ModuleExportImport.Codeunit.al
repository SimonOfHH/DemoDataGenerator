namespace SimonOfHH.DemoData.Export;

using SimonOfHH.DemoData.Model;
using System.Reflection;

/// <summary>
/// Provides JSON-based export and import of Module Definitions
/// including Table Selections, Field Configurations, and Module Dependencies.
/// </summary>
codeunit 70135 "Module Export Import"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    /// <summary>
    /// Exports the given Module Definition (with all child records) to JSON and triggers a file download.
    /// </summary>
    procedure ExportModule(ModuleDef: Record "Module Definition")
    var
        TempBlob: Codeunit System.Utilities."Temp Blob";
        Json: JsonObject;
        Content: Text;
        FileName: Text;
        InStr: InStream;
        OutStr: OutStream;
    begin
        Json := BuildModuleJson(ModuleDef);
        Json.WriteTo(Content);

        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Content);
        TempBlob.CreateInStream(InStr, TextEncoding::UTF8);

        FileName := ModuleDef.Code + '.json';
        DownloadFromStream(InStr, ExportDialogTitleLbl, '', JsonFilterLbl, FileName);
    end;

    /// <summary>
    /// Prompts the user to upload a JSON file and imports the Module Definition with all child records.
    /// Optionally merges with an existing module or creates a new one.
    /// </summary>
    procedure ImportModule()
    var
        ModuleDef: Record "Module Definition";
        Json: JsonObject;
        FileName: Text;
        InStr: InStream;
        Content: Text;
    begin
        if not UploadIntoStream(ImportDialogTitleLbl, '', JsonFilterLbl, FileName, InStr) then
            exit;

        InStr.Read(Content);
        if not Json.ReadFrom(Content) then
            Error(InvalidJsonErr);

        ReadModuleJson(Json, ModuleDef);

        Message(ImportCompleteMsg, ModuleDef.Code);
    end;

    // ═══════════════════════════════════ Export ═══════════════════════════════════

    local procedure BuildModuleJson(ModuleDef: Record "Module Definition"): JsonObject
    var
        Json: JsonObject;
        TablesArray: JsonArray;
        DepsArray: JsonArray;
    begin
        Json.Add('code', ModuleDef.Code);
        Json.Add('name', ModuleDef.Name);
        Json.Add('description', ModuleDef.Description);
        Json.Add('publisher', ModuleDef.Publisher);
        Json.Add('appVersion', ModuleDef."App Version");
        Json.Add('appId', Format(ModuleDef."App ID"));
        Json.Add('idRangeStart', ModuleDef."ID Range Start");
        Json.Add('idRangeEnd', ModuleDef."ID Range End");
        Json.Add('enumOrdinal', ModuleDef."Enum Ordinal");
        Json.Add('enumValueName', ModuleDef."Enum Value Name");
        Json.Add('helperPrefix', ModuleDef."Helper Prefix");
        Json.Add('status', ModuleDef.Status.AsInteger());
        Json.Add('appsToExclude', ModuleDef."Apps to Exclude");
        Json.Add('baseNamespace', ModuleDef."Base Namespace");

        TablesArray := BuildTableSelectionsJson(ModuleDef.Code);
        Json.Add('tableSelections', TablesArray);

        Json.Add('documentGroups', BuildDocumentGroupsJson(ModuleDef.Code));
        Json.Add('documentGroupLinks', BuildDocumentGroupLinksJson(ModuleDef.Code));

        DepsArray := BuildDependenciesJson(ModuleDef.Code);
        Json.Add('dependencies', DepsArray);

        exit(Json);
    end;

    local procedure BuildTableSelectionsJson(ModuleCode: Code[20]): JsonArray
    var
        TableSelection: Record "Table Selection";
        Arr: JsonArray;
        TableJson: JsonObject;
    begin
        TableSelection.SetRange("Module Code", ModuleCode);
        if TableSelection.FindSet() then
            repeat
                Clear(TableJson);
                TableJson.Add('tableId', TableSelection."Table ID");
                TableJson.Add('tableName', TableSelection."Table Name");
                TableJson.Add('dataLevel', TableSelection."Data Level".AsInteger());
                TableJson.Add('helperGroup', TableSelection."Helper Group");
                TableJson.Add('sortOrder', TableSelection."Sort Order");
                TableJson.Add('alNamespace', TableSelection."AL Namespace");
                TableJson.Add('helperCodeunitName', TableSelection."Helper Codeunit Name");
                TableJson.Add('dataCodeunitName', TableSelection."Data Codeunit Name");
                TableJson.Add('tableView', TableSelection."Table View");
                TableJson.Add('documentGroupCode', TableSelection."Document Group Code");
                TableJson.Add('groupRole', TableSelection."Group Role".AsInteger());
                TableJson.Add('fields', BuildFieldConfigsJson(ModuleCode, TableSelection."Table ID"));
                Arr.Add(TableJson);
            until TableSelection.Next() = 0;
        exit(Arr);
    end;

    /// <summary>
    /// Builds the JSON array for all Document Groups belonging to this module (H2 fix - previously
    /// omitted entirely, so exported modules with Document Groups could never be restored).
    /// </summary>
    local procedure BuildDocumentGroupsJson(ModuleCode: Code[20]): JsonArray
    var
        DocumentGroup: Record "Document Group";
        Arr: JsonArray;
        GroupJson: JsonObject;
    begin
        DocumentGroup.SetRange("Module Code", ModuleCode);
        if DocumentGroup.FindSet() then
            repeat
                Clear(GroupJson);
                GroupJson.Add('code', DocumentGroup.Code);
                GroupJson.Add('name', DocumentGroup."Name");
                GroupJson.Add('dataLevel', DocumentGroup."Data Level".AsInteger());
                GroupJson.Add('dataCodeunitName', DocumentGroup."Data Codeunit Name");
                Arr.Add(GroupJson);
            until DocumentGroup.Next() = 0;
        exit(Arr);
    end;

    /// <summary>
    /// Builds the JSON array for all Document Group Links belonging to this module (H2 fix - see
    /// <see cref="BuildDocumentGroupsJson"/>).
    /// </summary>
    local procedure BuildDocumentGroupLinksJson(ModuleCode: Code[20]): JsonArray
    var
        DocumentGroupLink: Record "Document Group Link";
        Arr: JsonArray;
        LinkJson: JsonObject;
    begin
        DocumentGroupLink.SetRange("Module Code", ModuleCode);
        if DocumentGroupLink.FindSet() then
            repeat
                Clear(LinkJson);
                LinkJson.Add('tableId', DocumentGroupLink."Table ID");
                LinkJson.Add('lineNo', DocumentGroupLink."Line No.");
                LinkJson.Add('childFieldNo', DocumentGroupLink."Child Field No.");
                LinkJson.Add('childFieldName', DocumentGroupLink."Child Field Name");
                LinkJson.Add('headerFieldNo', DocumentGroupLink."Header Field No.");
                LinkJson.Add('headerFieldName', DocumentGroupLink."Header Field Name");
                Arr.Add(LinkJson);
            until DocumentGroupLink.Next() = 0;
        exit(Arr);
    end;

    local procedure BuildFieldConfigsJson(ModuleCode: Code[20]; TableId: Integer): JsonArray
    var
        FieldConfig: Record "Field Configuration";
        Arr: JsonArray;
        FieldJson: JsonObject;
    begin
        FieldConfig.SetRange("Module Code", ModuleCode);
        FieldConfig.SetRange("Table ID", TableId);
        FieldConfig.SetCurrentKey("Module Code", "Table ID", "Sort Order");
        if FieldConfig.FindSet() then
            repeat
                Clear(FieldJson);
                FieldJson.Add('fieldNo', FieldConfig."Field No.");
                FieldJson.Add('fieldName', FieldConfig."Field Name");
                FieldJson.Add('dataType', FieldConfig."Data Type");
                FieldJson.Add('dataLength', FieldConfig."Data Length");
                FieldJson.Add('dataSubtype', FieldConfig."Data Subtype");
                FieldJson.Add('isPrimaryKey', FieldConfig."Is Primary Key");
                FieldJson.Add('behavior', FieldConfig.Behavior.AsInteger());
                FieldJson.Add('sourceAppId', Format(FieldConfig."Source App ID"));
                FieldJson.Add('sortOrder', FieldConfig."Sort Order");
                FieldJson.Add('referenceTableId', FieldConfig."Reference Table ID");
                FieldJson.Add('referenceFieldId', FieldConfig."Reference Field ID");
                FieldJson.Add('lockedLabel', FieldConfig."Locked Label");
                FieldJson.Add('relativeDate', FieldConfig."Relative Date".AsInteger());
                Arr.Add(FieldJson);
            until FieldConfig.Next() = 0;
        exit(Arr);
    end;

    local procedure BuildDependenciesJson(ModuleCode: Code[20]): JsonArray
    var
        ModuleDep: Record "Module Dependency";
        Arr: JsonArray;
        DepJson: JsonObject;
    begin
        ModuleDep.SetRange("Module Code", ModuleCode);
        if ModuleDep.FindSet() then
            repeat
                Clear(DepJson);
                DepJson.Add('dependencyModuleName', ModuleDep."Dependency Module Name");
                DepJson.Add('dependencyEnumOrdinal', ModuleDep."Dependency Enum Ordinal");
                Arr.Add(DepJson);
            until ModuleDep.Next() = 0;
        exit(Arr);
    end;

    // ═══════════════════════════════════ Import ═══════════════════════════════════

    local procedure ReadModuleJson(Json: JsonObject; var ModuleDef: Record "Module Definition")
    var
        ModuleCode: Code[20];
        AppIdText: Text;
        AppIdGuid: Guid;
        IsNew: Boolean;
    begin
        ModuleCode := CopyStr(GetJsonText(Json, 'code'), 1, MaxStrLen(ModuleDef.Code));
        if ModuleCode = '' then
            Error(MissingCodeErr);

        IsNew := not ModuleDef.Get(ModuleCode);
        if not IsNew then
            if not Confirm(ModuleExistsQst, false, ModuleCode) then
                Error('');

        if IsNew then begin
            ModuleDef.Init();
            ModuleDef.Code := ModuleCode;
        end;

        ModuleDef.Name := CopyStr(GetJsonText(Json, 'name'), 1, MaxStrLen(ModuleDef.Name));
        ModuleDef.Description := CopyStr(GetJsonText(Json, 'description'), 1, MaxStrLen(ModuleDef.Description));
        ModuleDef.Publisher := CopyStr(GetJsonText(Json, 'publisher'), 1, MaxStrLen(ModuleDef.Publisher));
        ModuleDef."App Version" := CopyStr(GetJsonText(Json, 'appVersion'), 1, MaxStrLen(ModuleDef."App Version"));

        AppIdText := GetJsonText(Json, 'appId');
        if Evaluate(AppIdGuid, AppIdText) then
            ModuleDef."App ID" := AppIdGuid;

        ModuleDef."ID Range Start" := GetJsonInt(Json, 'idRangeStart');
        ModuleDef."ID Range End" := GetJsonInt(Json, 'idRangeEnd');
        ModuleDef."Enum Ordinal" := GetJsonInt(Json, 'enumOrdinal');
        ModuleDef."Enum Value Name" := CopyStr(GetJsonText(Json, 'enumValueName'), 1, MaxStrLen(ModuleDef."Enum Value Name"));
        ModuleDef."Helper Prefix" := CopyStr(GetJsonText(Json, 'helperPrefix'), 1, MaxStrLen(ModuleDef."Helper Prefix"));
        ModuleDef."Apps to Exclude" := CopyStr(GetJsonText(Json, 'appsToExclude'), 1, MaxStrLen(ModuleDef."Apps to Exclude"));
        ModuleDef."Base Namespace" := CopyStr(GetJsonText(Json, 'baseNamespace'), 1, MaxStrLen(ModuleDef."Base Namespace"));

        if IsNew then
            ModuleDef.Insert(false)
        else
            ModuleDef.Modify(false);

        ReadTableSelectionsJson(Json, ModuleCode);
        ReadDocumentGroupLinksJson(Json, ModuleCode);
        ReadDependenciesJson(Json, ModuleCode);

        // Now do a "clean up" pass to e.g. remove fields that don't exist in this environment
        CleanUpModule(ModuleDef);
    end;

    local procedure ReadTableSelectionsJson(Json: JsonObject; ModuleCode: Code[20])
    var
        TableSelection: Record "Table Selection";
        Token: JsonToken;
        Arr: JsonArray;
        TableToken: JsonToken;
        TableJson: JsonObject;
        i: Integer;
    begin
        if not Json.Get('tableSelections', Token) then
            exit;
        Arr := Token.AsArray();

        // Delete existing table selections (cascades to field configs AND document group links
        // via OnDelete). Document Groups themselves are handled separately by
        // ReadDocumentGroupsJson, since "Table Selection".OnDelete does not touch that table.
        TableSelection.SetRange("Module Code", ModuleCode);
        TableSelection.DeleteAll(true);

        // Document Groups must exist before Table Selections reference them via "Document Group Code"
        ReadDocumentGroupsJson(Json, ModuleCode);

        for i := 0 to Arr.Count - 1 do begin
            Arr.Get(i, TableToken);
            TableJson := TableToken.AsObject();

            TableSelection.Init();
            TableSelection."Module Code" := ModuleCode;
            TableSelection."Table ID" := GetJsonInt(TableJson, 'tableId');
            TableSelection."Table Name" := CopyStr(GetJsonText(TableJson, 'tableName'), 1, MaxStrLen(TableSelection."Table Name"));
            TableSelection."Data Level" := "Data Level".FromInteger(GetJsonInt(TableJson, 'dataLevel'));
            TableSelection."Helper Group" := CopyStr(GetJsonText(TableJson, 'helperGroup'), 1, MaxStrLen(TableSelection."Helper Group"));
            TableSelection."Sort Order" := GetJsonInt(TableJson, 'sortOrder');
            TableSelection."AL Namespace" := CopyStr(GetJsonText(TableJson, 'alNamespace'), 1, MaxStrLen(TableSelection."AL Namespace"));
            TableSelection."Helper Codeunit Name" := CopyStr(GetJsonText(TableJson, 'helperCodeunitName'), 1, MaxStrLen(TableSelection."Helper Codeunit Name"));
            TableSelection."Data Codeunit Name" := CopyStr(GetJsonText(TableJson, 'dataCodeunitName'), 1, MaxStrLen(TableSelection."Data Codeunit Name"));
            TableSelection."Table View" := CopyStr(GetJsonText(TableJson, 'tableView'), 1, MaxStrLen(TableSelection."Table View"));
            TableSelection."Document Group Code" := CopyStr(GetJsonText(TableJson, 'documentGroupCode'), 1, MaxStrLen(TableSelection."Document Group Code"));
            TableSelection."Group Role" := "Document Group Role".FromInteger(GetJsonInt(TableJson, 'groupRole'));
            TableSelection.Insert(false);

            ReadFieldConfigsJson(TableJson, ModuleCode, TableSelection."Table ID");
        end;
    end;

    /// <summary>
    /// Reads the "documentGroups" array (H2 fix). Deletes any existing Document Groups for this
    /// module first so a re-import never leaves stale groups behind (Document Group is not
    /// cascaded from "Table Selection".OnDelete, unlike Field Configuration/Document Group Link).
    /// </summary>
    local procedure ReadDocumentGroupsJson(Json: JsonObject; ModuleCode: Code[20])
    var
        DocumentGroup: Record "Document Group";
        Token: JsonToken;
        Arr: JsonArray;
        GroupToken: JsonToken;
        GroupJson: JsonObject;
        i: Integer;
    begin
        DocumentGroup.SetRange("Module Code", ModuleCode);
        DocumentGroup.DeleteAll(false);

        if not Json.Get('documentGroups', Token) then
            exit;
        Arr := Token.AsArray();

        for i := 0 to Arr.Count - 1 do begin
            Arr.Get(i, GroupToken);
            GroupJson := GroupToken.AsObject();

            DocumentGroup.Init();
            DocumentGroup."Module Code" := ModuleCode;
            DocumentGroup.Code := CopyStr(GetJsonText(GroupJson, 'code'), 1, MaxStrLen(DocumentGroup.Code));
            DocumentGroup."Name" := CopyStr(GetJsonText(GroupJson, 'name'), 1, MaxStrLen(DocumentGroup."Name"));
            DocumentGroup."Data Level" := "Data Level".FromInteger(GetJsonInt(GroupJson, 'dataLevel'));
            DocumentGroup."Data Codeunit Name" := CopyStr(GetJsonText(GroupJson, 'dataCodeunitName'), 1, MaxStrLen(DocumentGroup."Data Codeunit Name"));
            DocumentGroup.Insert(false);
        end;
    end;

    /// <summary>
    /// Reads the "documentGroupLinks" array (H2 fix). Must run AFTER Table Selections have been
    /// re-created, since each link belongs to a Line-role Table Selection. Deletes any existing
    /// links for this module first (they are self-contained; not relied on to already be gone
    /// from the Table Selection cascade).
    /// </summary>
    local procedure ReadDocumentGroupLinksJson(Json: JsonObject; ModuleCode: Code[20])
    var
        DocumentGroupLink: Record "Document Group Link";
        Token: JsonToken;
        Arr: JsonArray;
        LinkToken: JsonToken;
        LinkJson: JsonObject;
        i: Integer;
    begin
        DocumentGroupLink.SetRange("Module Code", ModuleCode);
        DocumentGroupLink.DeleteAll(false);

        if not Json.Get('documentGroupLinks', Token) then
            exit;
        Arr := Token.AsArray();

        for i := 0 to Arr.Count - 1 do begin
            Arr.Get(i, LinkToken);
            LinkJson := LinkToken.AsObject();

            DocumentGroupLink.Init();
            DocumentGroupLink."Module Code" := ModuleCode;
            DocumentGroupLink."Table ID" := GetJsonInt(LinkJson, 'tableId');
            DocumentGroupLink."Line No." := GetJsonInt(LinkJson, 'lineNo');
            DocumentGroupLink."Child Field No." := GetJsonInt(LinkJson, 'childFieldNo');
            DocumentGroupLink."Child Field Name" := CopyStr(GetJsonText(LinkJson, 'childFieldName'), 1, MaxStrLen(DocumentGroupLink."Child Field Name"));
            DocumentGroupLink."Header Field No." := GetJsonInt(LinkJson, 'headerFieldNo');
            DocumentGroupLink."Header Field Name" := CopyStr(GetJsonText(LinkJson, 'headerFieldName'), 1, MaxStrLen(DocumentGroupLink."Header Field Name"));
            DocumentGroupLink.Insert(false);
        end;
    end;

    local procedure ReadFieldConfigsJson(TableJson: JsonObject; ModuleCode: Code[20]; TableId: Integer)
    var
        FieldConfig: Record "Field Configuration";
        Token: JsonToken;
        Arr: JsonArray;
        FieldToken: JsonToken;
        FieldJson: JsonObject;
        AppIdText: Text;
        AppIdGuid: Guid;
        i: Integer;
    begin
        if not TableJson.Get('fields', Token) then
            exit;
        Arr := Token.AsArray();

        for i := 0 to Arr.Count - 1 do begin
            Arr.Get(i, FieldToken);
            FieldJson := FieldToken.AsObject();

            FieldConfig.Init();
            FieldConfig."Module Code" := ModuleCode;
            FieldConfig."Table ID" := TableId;
            FieldConfig."Field No." := GetJsonInt(FieldJson, 'fieldNo');
            FieldConfig."Field Name" := CopyStr(GetJsonText(FieldJson, 'fieldName'), 1, MaxStrLen(FieldConfig."Field Name"));
            FieldConfig."Data Type" := CopyStr(GetJsonText(FieldJson, 'dataType'), 1, MaxStrLen(FieldConfig."Data Type"));
            FieldConfig."Data Length" := GetJsonInt(FieldJson, 'dataLength');
            FieldConfig."Data Subtype" := CopyStr(GetJsonText(FieldJson, 'dataSubtype'), 1, MaxStrLen(FieldConfig."Data Subtype"));
            FieldConfig."Is Primary Key" := GetJsonBool(FieldJson, 'isPrimaryKey');
            FieldConfig.Behavior := "Field Behavior".FromInteger(GetJsonInt(FieldJson, 'behavior'));
            FieldConfig."Sort Order" := GetJsonInt(FieldJson, 'sortOrder');
            FieldConfig."Reference Table ID" := GetJsonInt(FieldJson, 'referenceTableId');
            FieldConfig."Reference Field ID" := GetJsonInt(FieldJson, 'referenceFieldId');
            FieldConfig."Locked Label" := GetJsonBool(FieldJson, 'lockedLabel');
            FieldConfig."Relative Date" := "Relative Date Option".FromInteger(GetJsonInt(FieldJson, 'relativeDate'));

            AppIdText := GetJsonText(FieldJson, 'sourceAppId');
            if Evaluate(AppIdGuid, AppIdText) then
                FieldConfig."Source App ID" := AppIdGuid;
            FieldConfig.Insert(false);
        end;
    end;

    local procedure ReadDependenciesJson(Json: JsonObject; ModuleCode: Code[20])
    var
        ModuleDep: Record "Module Dependency";
        Token: JsonToken;
        Arr: JsonArray;
        DepToken: JsonToken;
        DepJson: JsonObject;
        i: Integer;
    begin
        if not Json.Get('dependencies', Token) then
            exit;
        Arr := Token.AsArray();

        // Delete existing dependencies
        ModuleDep.SetRange("Module Code", ModuleCode);
        ModuleDep.DeleteAll(false);

        for i := 0 to Arr.Count - 1 do begin
            Arr.Get(i, DepToken);
            DepJson := DepToken.AsObject();

            ModuleDep.Init();
            ModuleDep."Module Code" := ModuleCode;
            ModuleDep."Dependency Module Name" := CopyStr(GetJsonText(DepJson, 'dependencyModuleName'), 1, MaxStrLen(ModuleDep."Dependency Module Name"));
            ModuleDep."Dependency Enum Ordinal" := GetJsonInt(DepJson, 'dependencyEnumOrdinal');
            ModuleDep.Insert(false);
        end;
    end;

    internal procedure CleanUpModule(var ModuleDef: Record "Module Definition")
    var
        TablesFieldsRemoved: Dictionary of [Integer, List of [Integer]];
        DictKey, FieldNo : Integer;
        DictValue: List of [Integer];
        CleanupInfoMsg: TextBuilder;
        TableRemovedMsgLbl: Label 'Table ID %1 has been removed from the module.', Comment = '%1 = Table ID', Locked = true;
        FieldRemovedMsgLbl: Label 'Table ID %1 has the following fields removed: ', Comment = '%1 = Table ID', Locked = true;
    begin
        CleanupTableSelection(ModuleDef, TablesFieldsRemoved);
        // Additional clean up logic can be added here if needed
        foreach DictKey in TablesFieldsRemoved.Keys do begin
            DictValue := TablesFieldsRemoved.Get(DictKey);
            if DictValue.Contains(0) then
                CleanupInfoMsg.AppendLine(StrSubstNo(TableRemovedMsgLbl, DictKey))
            else begin
                CleanupInfoMsg.AppendLine(StrSubstNo(FieldRemovedMsgLbl, DictKey));
                foreach FieldNo in DictValue do
                    CleanupInfoMsg.AppendLine(StrSubstNo('- %1, ', FieldNo));
            end;
        end;
        if CleanupInfoMsg.Length > 0 then
            Message(CleanupInfoMsg.ToText());
    end;

    local procedure CleanupTableSelection(var ModuleDef: Record "Module Definition"; var TablesFieldsRemoved: Dictionary of [Integer, List of [Integer]])
    var
        TableSelection, TableSelectionToDelete : Record "Table Selection";
        AllObj: Record AllObj;
        FieldsRemoved: List of [Integer];
    begin
        TableSelection.SetRange("Module Code", ModuleDef.Code);
        if not TableSelection.FindSet() then
            exit;
        repeat
            FieldsRemoved := CleanupFieldConfigs(ModuleDef, TableSelection);
            if not AllObj.Get(AllObj."Object Type"::Table, TableSelection."Table ID") then begin
                FieldsRemoved.Add(0); // 0 indicates the entire table is missing, so all fields should be considered removed
                TablesFieldsRemoved.Add(TableSelection."Table ID", FieldsRemoved);
                TableSelectionToDelete := TableSelection; // Store the record to delete after moving to the next one
                TableSelectionToDelete.Delete(true);
            end else
                if FieldsRemoved.Count > 0 then
                    TablesFieldsRemoved.Add(TableSelection."Table ID", FieldsRemoved);
        until TableSelection.Next() = 0;
    end;

    local procedure CleanupFieldConfigs(var ModuleDef: Record "Module Definition"; var TableSelection: Record "Table Selection"): List of [Integer]
    var
        Field: Record Field;
        FieldConfig, FieldConfigToDelete : Record "Field Configuration";
        FieldsRemoved: List of [Integer];
    begin
        FieldConfig.SetRange("Module Code", ModuleDef.Code);
        FieldConfig.SetRange("Table ID", TableSelection."Table ID");
        if not FieldConfig.FindSet() then
            exit;
        repeat
            if not Field.Get(FieldConfig."Table ID", FieldConfig."Field No.") then begin
                FieldsRemoved.Add(FieldConfig."Field No.");
                FieldConfigToDelete := FieldConfig; // Need to store the record to delete after moving to the next one, since deleting the current record will invalidate the record variable
                FieldConfigToDelete.Delete(true);
            end;
        until FieldConfig.Next() = 0;
        exit(FieldsRemoved);
    end;
    // ═══════════════════════════════════ JSON Helpers ═══════════════════════════════════

    local procedure GetJsonText(Json: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Json.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure GetJsonInt(Json: JsonObject; PropertyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if Json.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsInteger());
        exit(0);
    end;

    local procedure GetJsonBool(Json: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if Json.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsBoolean());
        exit(false);
    end;

    var
        ExportDialogTitleLbl: Label 'Export Module Definition';
        ImportDialogTitleLbl: Label 'Import Module Definition';
        JsonFilterLbl: Label 'JSON Files (*.json)|*.json';
        InvalidJsonErr: Label 'The uploaded file does not contain valid JSON.';
        MissingCodeErr: Label 'The JSON file does not contain a module code.';
        ModuleExistsQst: Label 'Module "%1" already exists. Do you want to overwrite it?', Comment = '%1 = Module Code';
        ImportCompleteMsg: Label 'Module "%1" has been imported successfully.', Comment = '%1 = Module Code';
}
