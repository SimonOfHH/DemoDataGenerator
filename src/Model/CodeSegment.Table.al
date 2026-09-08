namespace SimonOfHH.DemoData.Model;

/// <summary>
/// Persists one generated code fragment (a procedure, a global-variable block, a file
/// header/footer, etc.) belonging to one generated .al file within a module. Enables
/// incremental regeneration: on every export, the freshly generated text for a segment is
/// compared against what was generated last time ("Baseline Code") and what is currently
/// stored ("Code"), so developer edits are preserved instead of being silently overwritten.
/// See "Code Segment Store" for the reconciliation logic that maintains these fields.
/// </summary>
table 70106 "Code Segment"
{
    Caption = 'Code Segment';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Module Code"; Code[20])
        {
            Caption = 'Module Code';
            TableRelation = "Module Definition".Code;
        }
        field(2; "Segment ID"; Text[100])
        {
            Caption = 'Segment ID';
            Description = 'Stable, deterministic identifier for this segment. Also used as the marker token wrapping the segment''s text in the generated .al file (e.g. "HELPER.BANK.INSERT.36").';
        }
        field(10; "Artifact Kind"; Enum "Code Artifact Kind")
        {
            Caption = 'Artifact Kind';
            Editable = false;
        }
        field(11; "Artifact Key"; Text[100])
        {
            Caption = 'Artifact Key';
            Description = 'Identifies WHICH generated file this segment belongs to within its Artifact Kind, e.g. the Helper Group name or the Data Codeunit name.';
            Editable = false;
        }
        field(12; "Table ID"; Integer)
        {
            Caption = 'Table ID';
            Description = 'The BC table this segment was generated for, if applicable (0 for module-level artifacts such as the Module Codeunit or Enum Extension).';
            Editable = false;
        }
        field(13; "Data Level"; Enum "Data Level")
        {
            Caption = 'Data Level';
            Editable = false;
        }
        field(14; "File Path"; Text[250])
        {
            Caption = 'File Path';
            Description = 'Relative path of the generated .al file this segment belongs to, e.g. "src/Helpers/ContosoBank.Codeunit.al".';
            Editable = false;
        }
        field(20; "Segment Kind"; Enum "Code Segment Kind")
        {
            Caption = 'Segment Kind';
            Editable = false;
        }
        field(21; "Segment Name"; Text[100])
        {
            Caption = 'Segment Name';
            Description = 'Human-readable name for this segment, e.g. the procedure name.';
            Editable = false;
        }
        field(22; "Sort Order"; Integer)
        {
            Caption = 'Sort Order';
            Description = 'Position of this segment within its file. Does not affect "Segment ID", which must remain stable regardless of ordering.';
            Editable = false;
        }
        field(30; "Code"; Blob)
        {
            Caption = 'Code';
            Description = 'The current text of this segment - what will actually be written into the next export. May differ from the most recently generated text if the developer has edited it.';
        }
        field(31; "Current Hash"; Text[64])
        {
            Caption = 'Current Hash';
            Description = 'Hash of "Code". Compared against "Baseline Hash" to detect whether the developer has modified this segment since it was last generated.';
            Editable = false;
        }
        field(32; "Baseline Code"; Blob)
        {
            Caption = 'Baseline Code';
            Description = 'The text this segment had immediately after it was last (re)generated, before any developer edits. Used only to compute "Baseline Hash"; not itself displayed.';
        }
        field(33; "Baseline Hash"; Text[64])
        {
            Caption = 'Baseline Hash';
            Editable = false;
        }
        field(34; "Pending Code"; Blob)
        {
            Caption = 'Pending Code';
            Description = 'Freshly generated text parked here when this segment is in Conflict (developer edited it AND the generator output changed). "Accept Regenerated" promotes this into "Code".';
        }
        field(35; "Pending Hash"; Text[64])
        {
            Caption = 'Pending Hash';
            Editable = false;
        }
        field(40; "Status"; Enum "Code Segment Status")
        {
            Caption = 'Status';
            Editable = false;
        }
        field(41; "Locked"; Boolean)
        {
            Caption = 'Locked';
            Description = 'When set, this segment is skipped entirely during sync/regeneration - neither overwritten nor flagged as changed.';
        }
        field(50; "Last Generated At"; DateTime)
        {
            Caption = 'Last Generated At';
            Editable = false;
        }
        field(51; "Last Modified At"; DateTime)
        {
            Caption = 'Last Modified At';
            Editable = false;
        }
        field(52; "Last Import At"; DateTime)
        {
            Caption = 'Last Import At';
            Editable = false;
        }
        field(60; "Line Count"; Integer)
        {
            Caption = 'Line Count';
            Editable = false;
        }
        field(61; "Preview"; Text[250])
        {
            Caption = 'Preview';
            Description = 'First meaningful line of "Code" - lets the segment list be scanned without opening every record.';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Module Code", "Segment ID")
        {
            Clustered = true;
        }
        key(ArtifactKey; "Module Code", "Artifact Kind", "Artifact Key", "Sort Order")
        {
        }
        key(StatusKey; "Module Code", "Status")
        {
        }
    }

    trigger OnDelete()
    begin
        // Segments are the persisted record of a developer's manual edits - only Orphaned
        // segments (already excluded from export, no longer produced by any generator) are safe
        // to remove. Everything else must go through the reconciliation algorithm in
        // "Code Segment Store" instead of ad-hoc deletion.
        if Rec.Status <> Rec.Status::Orphaned then
            Error(OnlyOrphanedCanBeDeletedErr);
    end;

    var
        OnlyOrphanedCanBeDeletedErr: Label 'Only segments with Status = Orphaned can be deleted directly. Other segments are managed automatically during sync/export.';
}
