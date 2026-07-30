namespace SimonOfHH.DemoData.Model;

using SimonOfHH.DemoData.UI;
using SimonOfHH.DemoData.Core;

/// <summary>
/// Child of Module Definition. Groups a Header table (e.g. Sales Header) with one or more
/// Line tables (e.g. Sales Line) so that Transaction/Historical data can be captured as one
/// correlated document snapshot instead of independent, uncorrelated per-table snapshots.
/// </summary>
table 70104 "Document Group"
{
    Caption = 'Document Group';
    DataClassification = CustomerContent;
    LookupPageId = "Document Group List";
    DrillDownPageId = "Document Group List";

    fields
    {
        field(1; "Module Code"; Code[20])
        {
            Caption = 'Module Code';
            TableRelation = "Module Definition".Code;
        }
        field(2; "Code"; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
        }
        field(10; "Name"; Text[100])
        {
            Caption = 'Name';
            Description = 'Short descriptive name, e.g. "Sales Document". Used to derive the generated stub codeunit name and JSON sidecar file name.';
        }
        field(11; "Data Level"; Enum "Data Level")
        {
            Caption = 'Data Level';
            Description = 'Document Groups are only valid for Transaction Data or Historical Data. Every member table must share this exact Data Level.';

            trigger OnValidate()
            begin
                if not (Rec."Data Level" in [Rec."Data Level"::"Transaction Data", Rec."Data Level"::"Historical Data"]) then
                    Error(InvalidDataLevelErr);
            end;
        }
        field(20; "Data Codeunit Name"; Text[30])
        {
            Caption = 'Data Codeunit Name';
            Description = 'Optional name for the generated stub data codeunit. If not specified, a default name will be derived from Name.';
        }
        field(30; "No. of Tables"; Integer)
        {
            Caption = 'No. of Tables';
            FieldClass = FlowField;
            CalcFormula = count("Table Selection" where("Module Code" = field("Module Code"), "Document Group Code" = field("Code")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Module Code", "Code")
        {
            Clustered = true;
        }
    }

    trigger OnDelete()
    var
        TableSelection: Record "Table Selection";
        DocumentGroupLink: Record "Document Group Link";
    begin
        TableSelection.SetRange("Module Code", Rec."Module Code");
        TableSelection.SetRange("Document Group Code", Rec.Code);
        if TableSelection.FindSet() then
            repeat
                DocumentGroupLink.SetRange("Module Code", TableSelection."Module Code");
                DocumentGroupLink.SetRange("Table ID", TableSelection."Table ID");
                DocumentGroupLink.DeleteAll(true);
                TableSelection."Document Group Code" := '';
                TableSelection."Group Role" := TableSelection."Group Role"::" ";
#pragma warning disable AA0214
                TableSelection.Modify(true);
#pragma warning restore AA0214
            until TableSelection.Next() = 0;
    end;

    /// <summary>
    /// Returns the Table ID of this group's Header-role member, or 0 if none is assigned yet.
    /// </summary>
    procedure GetHeaderTableID(): Integer
    var
        TableSelection: Record "Table Selection";
    begin
        TableSelection.SetRange("Module Code", Rec."Module Code");
        TableSelection.SetRange("Document Group Code", Rec.Code);
        TableSelection.SetRange("Group Role", TableSelection."Group Role"::Header);
        if TableSelection.FindFirst() then
            exit(TableSelection."Table ID");
        exit(0);
    end;

    /// <summary>
    /// Returns the name of the generated stub data codeunit for this group: the explicitly
    /// configured "Data Codeunit Name" if set, otherwise a name derived from "Name". Used by
    /// both "Document Data Generator" (which creates the codeunit) and "Module Generator"
    /// (which emits the Codeunit.Run call for it) so both always agree on the same name.
    /// </summary>
    procedure GetEffectiveDataCodeunitName(): Text
    var
        IdentifierHelper: Codeunit "Identifier Helper";
    begin
        if Rec."Data Codeunit Name" <> '' then
            exit(Rec."Data Codeunit Name");
        exit(IdentifierHelper.GetCreateCodeunitName(Rec."Name"));
    end;

    var
        InvalidDataLevelErr: Label 'Document Group is only valid for "Transaction Data" or "Historical Data".';
}
