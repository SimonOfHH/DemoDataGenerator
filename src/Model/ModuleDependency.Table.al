namespace SimonOfHH.DemoData.Model;

using SimonOfHH.DemoData.UI;

/// <summary>
/// Declares which existing Contoso modules the generated module depends on.
/// These dependencies are written into the generated module codeunit's GetDependencies() procedure.
/// </summary>
table 70103 "Module Dependency"
{
    Caption = 'Module Dependency';
    DataClassification = CustomerContent;
    LookupPageId = "Module Dependency List";
    DrillDownPageId = "Module Dependency List";

    fields
    {
        field(1; "Module Code"; Code[20])
        {
            Caption = 'Module Code';
            TableRelation = "Module Definition".Code;
        }
        field(2; "Dependency Module Name"; Text[100])
        {
            Caption = 'Dependency Module Name';

            trigger OnValidate()
            var
                TempModuleDep: Record "Module Dependency" temporary;
            begin
                TempModuleDep.InitTemporaryContosoModules(); // Helper function to get a list of Contoso modules as a temp record for the lookup
                TempModuleDep.SetRange("Dependency Module Name", Rec."Dependency Module Name");
                if TempModuleDep.FindFirst() then
                    Rec."Dependency Enum Ordinal" := TempModuleDep."Dependency Enum Ordinal";
            end;
        }
        field(3; "Dependency Enum Ordinal"; Integer)
        {
            Caption = 'Dependency Enum Ordinal';
            MinValue = 0;
        }
    }

    keys
    {
        key(PK; "Module Code", "Dependency Module Name")
        {
            Clustered = true;
        }
    }
    var
        TempRecordRequiredErr: Label 'This operation requires a temporary record.', Locked = true;

    internal procedure InitTemporaryContosoModules()
    begin
        if not Rec.IsTemporary() then
            Error(TempRecordRequiredErr);
        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Common Module';
        Rec."Dependency Enum Ordinal" := 0;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Manufacturing Module';
        Rec."Dependency Enum Ordinal" := 1;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Warehouse Module';
        Rec."Dependency Enum Ordinal" := 2;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Service Module';
        Rec."Dependency Enum Ordinal" := 3;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Fixed Asset Module';
        Rec."Dependency Enum Ordinal" := 4;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Human Resources Module';
        Rec."Dependency Enum Ordinal" := 5;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Job Module';
        Rec."Dependency Enum Ordinal" := 6;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Foundation';
        Rec."Dependency Enum Ordinal" := 10;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Finance';
        Rec."Dependency Enum Ordinal" := 11;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'CRM';
        Rec."Dependency Enum Ordinal" := 12;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Bank';
        Rec."Dependency Enum Ordinal" := 13;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Inventory';
        Rec."Dependency Enum Ordinal" := 14;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Purchase';
        Rec."Dependency Enum Ordinal" := 15;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'Sales';
        Rec."Dependency Enum Ordinal" := 16;
        Rec.Insert();

        Rec.Init();
        Rec."Module Code" := 'LOOKUP';
        Rec."Dependency Module Name" := 'EService';
        Rec."Dependency Enum Ordinal" := 17;
        Rec.Insert();
    end;
}
