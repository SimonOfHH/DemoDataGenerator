namespace SimonOfHH.DemoData.Model;

using System.Reflection;
using SimonOfHH.DemoData.Core;

/// <summary>
/// Child of a Line-role Table Selection. Each record maps one key field on the line/child
/// table to the corresponding key field on the Document Group's Header table (e.g. Sales
/// Line."Document No." -> Sales Header."No."). Used to correlate rows into nested JSON
/// documents when capturing Transaction/Historical data.
/// </summary>
table 70105 "Document Group Link"
{
    Caption = 'Document Group Link';
    DataClassification = CustomerContent;

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
            Description = 'The Line-role table (must match a "Table Selection" with Group Role = Line).';
        }
        field(3; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(10; "Child Field No."; Integer)
        {
            Caption = 'Child Field No.';

            trigger OnValidate()
            var
                FieldRec: Record Field;
            begin
                if Rec."Child Field No." = 0 then begin
                    Rec."Child Field Name" := '';
                    exit;
                end;
                Rec.TestField("Table ID");
                FieldRec.Get(Rec."Table ID", Rec."Child Field No.");
                Rec."Child Field Name" := CopyStr(FieldRec.FieldName, 1, MaxStrLen(Rec."Child Field Name"));
            end;

            trigger OnLookup()
            var
                FieldLookupHelper: Codeunit "Field Lookup Helper";
                NewFieldNo: Integer;
            begin
                Rec.TestField("Table ID");
                NewFieldNo := Rec."Child Field No.";
                if FieldLookupHelper.LookupField(Rec."Table ID", NewFieldNo) then
                    Rec.Validate("Child Field No.", NewFieldNo);
            end;
        }
        field(11; "Child Field Name"; Text[100])
        {
            Caption = 'Child Field Name';
            Editable = false;
        }
        field(20; "Header Field No."; Integer)
        {
            Caption = 'Header Field No.';

            trigger OnValidate()
            var
                FieldRec: Record Field;
            begin
                if Rec."Header Field No." = 0 then begin
                    Rec."Header Field Name" := '';
                    exit;
                end;
                FieldRec.Get(Rec.GetHeaderTableID(), Rec."Header Field No.");
                Rec."Header Field Name" := CopyStr(FieldRec.FieldName, 1, MaxStrLen(Rec."Header Field Name"));
            end;

            trigger OnLookup()
            var
                FieldLookupHelper: Codeunit "Field Lookup Helper";
                NewFieldNo: Integer;
            begin
                NewFieldNo := Rec."Header Field No.";
                if FieldLookupHelper.LookupField(Rec.GetHeaderTableID(), NewFieldNo) then
                    Rec.Validate("Header Field No.", NewFieldNo);
            end;
        }
        field(21; "Header Field Name"; Text[100])
        {
            Caption = 'Header Field Name';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Module Code", "Table ID", "Line No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        DocumentGroupLink: Record "Document Group Link";
    begin
        if Rec."Line No." <> 0 then
            exit;
        DocumentGroupLink.SetRange("Module Code", Rec."Module Code");
        DocumentGroupLink.SetRange("Table ID", Rec."Table ID");
        if DocumentGroupLink.FindLast() then
            Rec."Line No." := DocumentGroupLink."Line No." + 10000
        else
            Rec."Line No." := 10000;
    end;

    /// <summary>
    /// Returns the Table ID of the Header-role table belonging to the same Document Group
    /// as this link's owning (Line-role) Table Selection.
    /// </summary>
    internal procedure GetHeaderTableID(): Integer
    var
        TableSelection: Record "Table Selection";
        DocumentGroup: Record "Document Group";
    begin
        Rec.TestField("Module Code");
        Rec.TestField("Table ID");
        if not TableSelection.Get(Rec."Module Code", Rec."Table ID") then
            exit(0);
        TableSelection.TestField("Document Group Code");
        if not DocumentGroup.Get(TableSelection."Module Code", TableSelection."Document Group Code") then
            exit(0);
        exit(DocumentGroup.GetHeaderTableID());
    end;
}
