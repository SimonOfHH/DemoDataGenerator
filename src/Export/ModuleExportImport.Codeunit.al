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

        DepsArray := BuildDependenciesJson(ModuleDef.Code);
        Json.Add('dependencies', DepsArray);

        exit(Json);
    end;

    local procedure BuildTableSelectionsJson(ModuleCode: Code[20]): JsonArray
    var
        TableSel: Record "Table Selection";
        Arr: JsonArray;
        TableJson: JsonObject;
    begin
        TableSel.SetRange("Module Code", ModuleCode);
        if TableSel.FindSet() then
            repeat
                Clear(TableJson);
                TableJson.Add('tableId', TableSel."Table ID");
                TableJson.Add('tableName', TableSel."Table Name");
                TableJson.Add('dataLevel', TableSel."Data Level".AsInteger());
                TableJson.Add('helperGroup', TableSel."Helper Group");
                TableJson.Add('sortOrder', TableSel."Sort Order");
                TableJson.Add('alNamespace', TableSel."AL Namespace");
                TableJson.Add('fields', BuildFieldConfigsJson(ModuleCode, TableSel."Table ID"));
                Arr.Add(TableJson);
            until TableSel.Next() = 0;
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
        ReadDependenciesJson(Json, ModuleCode);

        // Now do a "clean up" pass to e.g. remove fields that don't exist in this environment
        CleanUpModule(ModuleDef);
    end;

    local procedure ReadTableSelectionsJson(Json: JsonObject; ModuleCode: Code[20])
    var
        TableSel: Record "Table Selection";
        Token: JsonToken;
        Arr: JsonArray;
        TableToken: JsonToken;
        TableJson: JsonObject;
        i: Integer;
    begin
        if not Json.Get('tableSelections', Token) then
            exit;
        Arr := Token.AsArray();

        // Delete existing table selections (cascades to field configs via OnDelete)
        TableSel.SetRange("Module Code", ModuleCode);
        TableSel.DeleteAll(true);

        for i := 0 to Arr.Count - 1 do begin
            Arr.Get(i, TableToken);
            TableJson := TableToken.AsObject();

            TableSel.Init();
            TableSel."Module Code" := ModuleCode;
            TableSel."Table ID" := GetJsonInt(TableJson, 'tableId');
            TableSel."Table Name" := CopyStr(GetJsonText(TableJson, 'tableName'), 1, MaxStrLen(TableSel."Table Name"));
            TableSel."Data Level" := "Data Level".FromInteger(GetJsonInt(TableJson, 'dataLevel'));
            TableSel."Helper Group" := CopyStr(GetJsonText(TableJson, 'helperGroup'), 1, MaxStrLen(TableSel."Helper Group"));
            TableSel."Sort Order" := GetJsonInt(TableJson, 'sortOrder');
            TableSel."AL Namespace" := CopyStr(GetJsonText(TableJson, 'alNamespace'), 1, MaxStrLen(TableSel."AL Namespace"));
            TableSel.Insert(false);

            ReadFieldConfigsJson(TableJson, ModuleCode, TableSel."Table ID");
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
