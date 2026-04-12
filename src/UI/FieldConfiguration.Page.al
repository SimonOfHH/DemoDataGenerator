namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;

/// <summary>
/// List page for configuring field behavior per table.
/// </summary>
page 70103 "Field Configuration"
{
    ApplicationArea = All;
    Caption = 'Field Configuration';
    PageType = List;
    SourceTable = "Field Configuration";
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Fields)
            {
                field("Field No."; Rec."Field No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the field number.';
                    Editable = false;
                }
                field("Field Name"; Rec."Field Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the field name.';
                    Editable = false;
                }
                field("Data Type"; Rec."Data Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the AL data type of the field.';
                    Editable = false;
                }
                field("Data Length"; Rec."Data Length")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the data length (e.g., 20 for Code[20]).';
                    Editable = false;
                }
                field("Is Primary Key"; Rec."Is Primary Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates whether this field is part of the primary key.';
                    Editable = false;
                }
                field(Behavior; Rec.Behavior)
                {
                    ApplicationArea = All;
                    ToolTip = 'Controls how this field is handled during code generation: Include (inline value), Label Field (constant + accessor), Dynamic Field (placeholder procedure), Exclude (skip).';
                }
                field("Sort Order"; Rec."Sort Order")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the order of this field in the generated code.';
                    Visible = false; // we assume that fields will be sorted by field number, so we don't need to show this on the page by default.
                }
                field("Reference Table ID"; Rec."Reference Table ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'For fields with Behavior "Reference Value", this is the ID of the table that the field references. Used for generating lookup code.';
                    Editable = Rec.Behavior = Rec.Behavior::"Reference Value";
                }
                field("Reference Field ID"; Rec."Reference Field ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'For fields with Behavior "Reference Value", this is the ID of the field that the field references. Used for generating lookup code.';
                    Editable = Rec.Behavior = Rec.Behavior::"Reference Value";
                }
                field("Is Referenced Field"; Rec."Is Referenced Field")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates whether this field is referenced by any other field with Behavior "Reference Value". Used for determining whether to generate code for this field.';
                    Editable = false;
                }
                field("Locked Label"; Rec."Locked Label")
                {
                    ApplicationArea = All;
                    ToolTip = 'When enabled, the generated Label variable will include the Locked = true property, preventing translation.';
                    Editable = LockedLabelEditable;
                }
                field("Relative Date"; Rec."Relative Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'For date fields; when set the generator will calculate all dates relative to workdate instead of using fixed dates. This helps keep demo data relevant regardless of when it is generated. The specific behavior depends on the selected option. Example: workdate is set to 31.01.2026, and the processed date has a value of 05.02.2026, the generator will calculate the difference of 5 days and use workdate + 5 days as the value for the processed date if you select "Relative to Workdate".';
                    Editable = Rec."Data Type" = 'Date';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(MarkAllInclude)
            {
                ApplicationArea = All;
                Caption = 'Mark All Include';
                Image = Apply;
                ToolTip = 'Sets all non-PK fields to Include behavior.';

                trigger OnAction()
                var
                    FieldConfig: Record "Field Configuration";
                begin
                    FieldConfig.CopyFilters(Rec);
                    FieldConfig.SetRange("Is Primary Key", false);
                    FieldConfig.ModifyAll(Behavior, FieldConfig.Behavior::Include);
                end;
            }
            action(AutoSuggest)
            {
                ApplicationArea = All;
                Caption = 'Auto-Suggest';
                Image = Suggest;
                ToolTip = 'Auto-detects Label Field candidates (PK Code/Text fields) and sets appropriate behavior.';

                trigger OnAction()
                var
                    FieldConfig: Record "Field Configuration";
                begin
                    FieldConfig.CopyFilters(Rec);
                    if FieldConfig.FindSet() then
                        repeat
                            if FieldConfig."Is Primary Key" and
                               (FieldConfig."Data Type" in ['Code', 'Text'])
                            then begin
                                FieldConfig.Behavior := FieldConfig.Behavior::"Label Field";
                                FieldConfig.Modify(true);
                            end;
                        until FieldConfig.Next() = 0;
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(MarkAllInclude_Promoted; MarkAllInclude) { }
                actionref(AutoSuggest_Promoted; AutoSuggest) { }
            }
        }
    }

    var
        LockedLabelEditable: Boolean;

    trigger OnAfterGetRecord()
    begin
        // We only allow editing the Locked Label property if the field is a Text or Code field, since that's the only scenario where it makes sense to lock the label.
        LockedLabelEditable := Rec."Data Type" in ['Text', 'Code'];
        LockedLabelEditable := LockedLabelEditable and (Rec.Behavior in [Rec.Behavior::"Label Field", Rec.Behavior::"Procedure with Token-Label"]);
    end;
}
