namespace SimonOfHH.DemoData.Model;

using SimonOfHH.DemoData.UI;

/// <summary>
/// Central entity representing a module to be code-generated.
/// Each record produces one complete AL extension following the Contoso Coffee pattern.
/// </summary>
table 70100 "Module Definition"
{
    Caption = 'Module Definition';
    DataClassification = CustomerContent;
    LookupPageId = "Module Definition List";
    DrillDownPageId = "Module Definition List";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
        }
        field(2; Name; Text[100])
        {
            Caption = 'Name';

            trigger OnValidate()
            begin
                if "Enum Value Name" = '' then
                    "Enum Value Name" := Name;
            end;
        }
        field(3; Description; Text[250])
        {
            Caption = 'Description';
        }
        field(10; Publisher; Text[100])
        {
            Caption = 'Publisher';
            InitValue = 'SimonOfHH';
        }
        field(11; "App Version"; Text[20])
        {
            Caption = 'App Version';
            InitValue = '1.0.0.0';
        }
        field(12; "App ID"; Guid)
        {
            Caption = 'App ID';
        }
        field(20; "ID Range Start"; Integer)
        {
            Caption = 'ID Range Start';
            MinValue = 50000;

            trigger OnValidate()
            begin
                if ("ID Range End" <> 0) and ("ID Range Start" > "ID Range End") then
                    Error(RangeStartMustBeLessErr);
                if Rec."Enum Ordinal" = 0 then
                    Rec."Enum Ordinal" := "ID Range Start";
            end;
        }
        field(21; "ID Range End"; Integer)
        {
            Caption = 'ID Range End';
            MinValue = 50000;

            trigger OnValidate()
            begin
                if ("ID Range Start" <> 0) and ("ID Range End" < "ID Range Start") then
                    Error(RangeEndMustBeGreaterErr);
                if Rec."Enum Ordinal" = 0 then
                    Rec."Enum Ordinal" := "ID Range Start";
            end;
        }
        field(30; "Enum Ordinal"; Integer)
        {
            Caption = 'Enum Ordinal';
            MinValue = 0;
        }
        field(31; "Enum Value Name"; Text[100])
        {
            Caption = 'Enum Value Name';
        }
        field(35; "Helper Prefix"; Text[250])
        {
            Caption = 'Helper Prefix';
            InitValue = 'Contoso';
        }
        field(40; Status; Enum "Module Status")
        {
            Caption = 'Status';
        }
        field(50; "Apps to Exclude"; Text[2048])
        {
            Caption = 'Apps to Exclude';
        }
        field(60; "Base Namespace"; Text[250])
        {
            Caption = 'Base Namespace';
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    begin
        if IsNullGuid("App ID") then
            "App ID" := CreateGuid();
    end;

    trigger OnDelete()
    var
        TableSelection: Record "Table Selection";
        ModuleDependency: Record "Module Dependency";
    begin
        TableSelection.SetRange("Module Code", Code);
        TableSelection.DeleteAll(true);

        ModuleDependency.SetRange("Module Code", Code);
        ModuleDependency.DeleteAll(true);
    end;

    var
        RangeStartMustBeLessErr: Label 'ID Range Start must be less than or equal to ID Range End.';
        RangeEndMustBeGreaterErr: Label 'ID Range End must be greater than or equal to ID Range Start.';
}
