namespace SimonOfHH.DemoData.Model;

using System.Reflection;
using SimonOfHH.DemoData.UI;

/// <summary>
/// Child of Module Definition. Each record represents a BC table selected for code generation.
/// </summary>
table 70101 "Table Selection"
{
    Caption = 'Table Selection';
    DataClassification = CustomerContent;
    LookupPageId = "Table Selection Lookup";

    fields
    {
        field(1; "Module Code"; Code[20])
        {
            Caption = 'Module Code';
            TableRelation = "Module Definition".Code;
        }
        field(2; "Table ID"; Integer)
        {
            Caption = 'Table ID';
            NotBlank = true;

            trigger OnValidate()
            var
                AllObjWithCaption: Record AllObjWithCaption;
                TableSelection: Record "Table Selection";
            begin
                if AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Table, "Table ID") then begin
                    Rec."Table Name" := AllObjWithCaption."Object Caption";
                    Rec."AL Namespace" := AllObjWithCaption."AL Namespace";
                    if Rec."Helper Group" = '' then
                        Rec."Helper Group" := GetDefaultHelperGroup(AllObjWithCaption."Object Caption");
                    if TableSelection.Get(Rec."Module Code", Rec."Table ID") then // check if already inserted
                        PopulateFields();
                end;
                PopulateNames();
            end;

            trigger OnLookup()
            var
                AllObjWithCaption: Record AllObjWithCaption;
            begin
                AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Table);
                if Page.RunModal(Page::"All Objects with Caption", AllObjWithCaption) = Action::LookupOK then
                    Validate("Table ID", AllObjWithCaption."Object ID");
            end;
        }
        field(3; "Table Name"; Text[249])
        {
            Caption = 'Table Name';
            Editable = false;
        }
        field(10; "Data Level"; Enum "Data Level")
        {
            Caption = 'Data Level';
        }
        field(11; "Helper Group"; Text[100])
        {
            Caption = 'Helper Group';
        }
        field(12; "Sort Order"; Integer)
        {
            Caption = 'Sort Order';
        }
        field(20; "No. of Fields"; Integer)
        {
            Caption = 'No. of Fields';
            FieldClass = FlowField;
            CalcFormula = count("Field Configuration" where("Module Code" = field("Module Code"), "Table ID" = field("Table ID")));
            Editable = false;
        }
        field(21; "No. of Configured Fields"; Integer)
        {
            Caption = 'No. of Configured Fields';
            FieldClass = FlowField;
            CalcFormula = count("Field Configuration" where("Module Code" = field("Module Code"), "Table ID" = field("Table ID"), Behavior = filter(<> Exclude)));
            Editable = false;
        }
        field(100; "AL Namespace"; Text[500])
        {
            Caption = 'AL Namespace';
            Description = 'Optional AL namespace for the generated code. If not specified, a default namespace will be used.';
        }
        field(110; "Helper Codeunit Name"; Text[30])
        {
            Caption = 'Helper Codeunit Name';
            Description = 'Optional name for the generated helper codeunit. If not specified, a default name will be used.';
        }
        field(111; "Data Codeunit Name"; Text[30])
        {
            Caption = 'Data Codeunit Name';
            Description = 'Optional name for the generated data codeunit. If not specified, a default name will be used.';
        }
    }

    keys
    {
        key(PK; "Module Code", "Table ID")
        {
            Clustered = true;
        }
        key(SortKey; "Module Code", "Data Level", "Sort Order")
        {
        }
    }

    trigger OnInsert()
    var
        FieldConfiguration: Record "Field Configuration";
    begin
        FieldConfiguration.SetRange("Module Code", "Module Code");
        FieldConfiguration.SetRange("Table ID", "Table ID");
        if FieldConfiguration.IsEmpty() then
            PopulateFields();
    end;

    trigger OnDelete()
    var
        FieldConfiguration: Record "Field Configuration";
    begin
        FieldConfiguration.SetRange("Module Code", "Module Code");
        FieldConfiguration.SetRange("Table ID", "Table ID");
        FieldConfiguration.DeleteAll(true);
    end;

    procedure PopulateNames()
    var
        ModuleDefinition: Record "Module Definition";
        IdentifierHelper: Codeunit SimonOfHH.DemoData.Core."Identifier Helper";
        NewName: Text;
    begin
        ModuleDefinition.Get("Module Code");
        if Rec."Helper Codeunit Name" = '' then begin
            NewName := IdentifierHelper.GetHelperCodeunitName(ModuleDefinition."Helper Prefix", Rec."Helper Group");
            if StrLen(NewName) > 30 then
                Message('Generated Helper Codeunit Name "%1" exceeds the maximum length of 30 characters. Please specify a shorter Helper Group or Helper Prefix.', NewName)
            else
                Rec."Helper Codeunit Name" := CopyStr(NewName, 1, MaxStrLen(Rec."Helper Codeunit Name"));
        end;
        if Rec."Data Codeunit Name" = '' then begin
            NewName := IdentifierHelper.GetCreateCodeunitName(Rec."Table Name"); // GetCreateCodeunitName already ensures the name is sanitized and fits into 30 chars
            Rec."Data Codeunit Name" := CopyStr(NewName, 1, MaxStrLen(Rec."Data Codeunit Name"));
        end;
    end;

    /// <summary>
    /// Populates Field Configuration records for this table by reading table metadata.
    /// Auto-detects primary key fields, excludes FlowFields, Blob, Media, MediaSet, and obsoleted fields.
    /// </summary>
    procedure PopulateFields()
    var
        ModuleDefinition: Record "Module Definition";
        FieldConfiguration: Record "Field Configuration";
        RecRef: RecordRef;
        FldRef: FieldRef;
        KeyRef: KeyRef;
        PKFieldNos: List of [Integer];
        i: Integer;
    begin
        ModuleDefinition.Get("Module Code");

        // Collect primary key field numbers
        RecRef.Open("Table ID");
        KeyRef := RecRef.KeyIndex(1);
        for i := 1 to KeyRef.FieldCount do begin
            FldRef := KeyRef.FieldIndex(i);
            PKFieldNos.Add(FldRef.Number);
        end;

        // Iterate all fields
        for i := 1 to RecRef.FieldCount do begin
            FldRef := RecRef.FieldIndex(i);

            if not FieldConfiguration.Get("Module Code", "Table ID", FldRef.Number) then begin
                FieldConfiguration.Init();
                FieldConfiguration."Module Code" := "Module Code";
                FieldConfiguration."Table ID" := "Table ID";
                FieldConfiguration."Field No." := FldRef.Number;
                FieldConfiguration."Field Name" := CopyStr(FldRef.Name, 1, MaxStrLen(FieldConfiguration."Field Name"));
                FieldConfiguration."Data Type" := CopyStr(Format(FldRef.Type), 1, MaxStrLen(FieldConfiguration."Data Type"));
                FieldConfiguration."Data Length" := FldRef.Length;
                FieldConfiguration."Is Primary Key" := PKFieldNos.Contains(FldRef.Number);
                FieldConfiguration."Sort Order" := FldRef.Number;
                FieldConfiguration."Source App ID" := GetAppIdForField("Table ID", FldRef.Number);
                if not FieldConfiguration.ShouldIncludeField(FldRef) then
                    FieldConfiguration.Behavior := FieldConfiguration.Behavior::Exclude;
                if FieldConfiguration."Is Primary Key" then
                    FieldConfiguration.Behavior := FieldConfiguration.Behavior::Include;
                // If the module has specified apps to exclude, and this table belongs to any of those apps, default to Exclude
                if ModuleDefinition."Apps to Exclude" <> '' then
                    if StrPos(ModuleDefinition."Apps to Exclude", FieldConfiguration."Source App ID") > 0 then
                        FieldConfiguration.Behavior := FieldConfiguration.Behavior::Exclude;

                FieldConfiguration.Insert(true);
            end;
        end;

        RecRef.Close();
    end;

    local procedure GetAppIdForField(TableID: Integer; FieldNo: Integer): Guid
    var
        Field: Record Field;
    begin
        if Field.Get(TableID, FieldNo) then
            exit(GetAppIdForAppPackageId(Field."App Package ID"));
    end;

    local procedure GetAppIdForAppPackageId(NewAppPackageId: Guid): Guid
    var
        NavInstalledApp: Record System.Apps."NAV App Installed App";
        EmptyGuid: Guid;
    begin
        if IsNullGuid(NewAppPackageId) then
            exit(EmptyGuid);
        if NavInstalledApp.Get(NewAppPackageId) then
            exit(NavInstalledApp."App ID");
        NavInstalledApp.Reset();
        NavInstalledApp.SetRange("Package ID", NewAppPackageId);
        if not NavInstalledApp.FindFirst() then begin
            NavInstalledApp.SetRange("Package ID");
            NavInstalledApp.SetRange("App ID", NewAppPackageId);
            if not NavInstalledApp.FindFirst() then
                exit(EmptyGuid);
        end;
        exit(NavInstalledApp."App ID");
    end;

    local procedure GetDefaultHelperGroup(TableCaption: Text): Text[100]
    var
        SpacePos: Integer;
        Substring: Text;
    begin
        // Use the first word of the table name as default group
        // e.g., "Bank Account" → "Bank", "Payment Method" → "Payment"
        SpacePos := StrPos(TableCaption, ' ');
        if SpacePos > 0 then begin
            Substring := CopyStr(TableCaption, 1, SpacePos - 1);
            // If the first word is longer than 100 chars, abbreviate it to fit into the Helper Group field
            if StrLen(Substring) > 100 then
                Substring := CopyStr(Substring, 1, 100);
#pragma warning disable AA0139
            exit(Substring);
#pragma warning restore AA0139
        end;
        exit(CopyStr(TableCaption, 1, 100));
    end;
}
