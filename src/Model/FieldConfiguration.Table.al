namespace SimonOfHH.DemoData.Model;

/// <summary>
/// Child of Table Selection. Each record represents one field of a selected table
/// and controls how that field is handled during code generation.
/// </summary>
table 70102 "Field Configuration"
{
    Caption = 'Field Configuration';
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
        }
        field(3; "Field No."; Integer)
        {
            Caption = 'Field No.';
        }
        field(10; "Field Name"; Text[100])
        {
            Caption = 'Field Name';
            Editable = false;
        }
        field(11; "Data Type"; Text[50])
        {
            Caption = 'Data Type';
            Editable = false;
        }
        field(12; "Data Length"; Integer)
        {
            Caption = 'Data Length';
            Editable = false;
        }
        field(13; "Data Subtype"; Text[100])
        {
            Caption = 'Data Subtype';
            Editable = false;
        }
        field(20; "Is Primary Key"; Boolean)
        {
            Caption = 'Is Primary Key';
            Editable = false;
        }
        field(21; Behavior; Enum "Field Behavior")
        {
            Caption = 'Behavior';

            trigger OnValidate()
            var
                ExcludedFieldRequirementErr: Label 'This field must be set to "Exclude" because of its type or other characteristics.';
            begin
                if "Is Primary Key" and (Behavior = Behavior::Exclude) then
                    Error(PKFieldMustBeIncludeErr);
                if not Rec.ShouldIncludeField() and (Behavior <> Behavior::Exclude) then
                    Error(ExcludedFieldRequirementErr);
            end;
        }
        field(30; "Source App ID"; Guid)
        {
            Caption = 'Source App ID';
            Editable = false;
        }
        field(31; "Sort Order"; Integer)
        {
            Caption = 'Sort Order';
        }
        field(40; "Reference Table ID"; Integer)
        {
            Caption = 'Reference Table ID';
            Description = 'For fields with Behavior "Reference Value", this is the ID of the table that the field references. Used for generating lookup code.';
            TableRelation = "Table Selection"."Table ID" where("Module Code" = field("Module Code"));

        }
        field(41; "Reference Field ID"; Integer)
        {
            Caption = 'Reference Field ID';
            Description = 'For fields with Behavior "Reference Value", this is the ID of the field that the field references. Used for generating lookup code.';
            // TODO: Add table relation to Field ID based on Reference Table ID once cross-table relations are supported in AL. For now, validated manually in code.
        }
        field(42; "Is Referenced Field"; Boolean)
        {
            Caption = 'Is Referenced Field';
            Description = 'Indicates whether this field is referenced by any other field with Behavior "Reference Value". Used for determining whether to generate code for this field.';
            FieldClass = FlowField;
            Editable = false;
            CalcFormula = exist("Field Configuration" where("Module Code" = field("Module Code"), "Reference Table ID" = field("Table ID"), "Reference Field ID" = field("Field No."), Behavior = const("Reference Value")));
        }
        field(51; "Locked Label"; Boolean)
        {
            Caption = 'Locked Label';
            Description = 'When enabled, the generated Label variable will include the Locked = true property, preventing translation.';
        }
        field(50; "Relative Date"; enum "Relative Date Option")
        {
            Caption = 'Relative Date';
            Description = 'For date fields; when set the generator will calculate all dates relative to workdate instead of using fixed dates. This helps keep demo data relevant regardless of when it is generated. The specific behavior depends on the selected option. Example: workdate is set to 31.01.2026, and the processed date has a value of 05.02.2026, the generator will calculate the difference of 5 days and use workdate + 5 days as the value for the processed date if you select "Relative to Workdate".';

            trigger OnValidate()
            begin
                if Rec."Relative Date" <> Enum::"Relative Date Option"::None then begin
                    Rec.TestField("Data Type", 'Date');
                    Rec.TestField(Behavior, Behavior::Include);
                end;
            end;
        }
    }

    keys
    {
        key(PK; "Module Code", "Table ID", "Field No.")
        {
            Clustered = true;
        }
        key(SortKey; "Module Code", "Table ID", "Sort Order")
        {
        }
    }

    var
        PKFieldMustBeIncludeErr: Label 'Primary key fields must always have Behavior set to Include.';

    procedure ShouldIncludeField(): Boolean; // Forward declaration for use in trigger
    var
        RecRef: RecordRef;
        FldRef: FieldRef;
    begin
        RecRef.Open("Table ID");
        FldRef := RecRef.Field("Field No.");
        exit(ShouldIncludeField(FldRef));
    end;

    procedure ShouldIncludeField(FldRef: FieldRef): Boolean
    var
        Field: Record System.Reflection.Field;
    begin
        // Skip system fields (>= 2000000000)
        if FldRef.Number >= 2000000000 then
            exit(false);

        // Skip FlowFields, FlowFilters
        if FldRef.Class <> FieldClass::Normal then
            exit(false);

        // Skip Blob, Media, MediaSet, RecordId
        if FldRef.Type in [FieldType::Blob, FieldType::Media, FieldType::MediaSet, FieldType::RecordId] then
            exit(false);

        // Skip obsoleted fields
        if Field.Get(FldRef.Record().Number, FldRef.Number) then
            if Field.ObsoleteState = Field.ObsoleteState::Removed then
                exit(false);

        exit(true);
    end;
}
