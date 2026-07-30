namespace SimonOfHH.DemoData.Core;

using System.Reflection;
using SimonOfHH.DemoData.UI;

/// <summary>
/// Generic helper for looking up a field number on an arbitrary table. Replaces the
/// unsupported Page.RunModal(0, FieldRecord) pattern (there is no generic default page for
/// the "Field" table) and the base application's OnPrem-only "Fields Lookup" page (9806).
/// </summary>
codeunit 70138 "Field Lookup Helper"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    /// <summary>
    /// Opens a modal lookup over all fields of the given table and returns the selected field
    /// number. If FieldNo already has a value, that field is pre-selected when opening the page.
    /// </summary>
    /// <param name="TableId">The table whose fields should be listed.</param>
    /// <param name="FieldNo">On input, the currently selected field number (0 if none). On output, the field number chosen by the user (unchanged if the lookup was cancelled).</param>
    /// <returns>True if the user confirmed a selection; false if the lookup was cancelled.</returns>
    procedure LookupField(TableId: Integer; var FieldNo: Integer): Boolean
    var
        FieldRec: Record Field;
    begin
        FieldRec.SetRange(TableNo, TableId);
        if FieldNo <> 0 then
            if FieldRec.Get(TableId, FieldNo) then;
        if Page.RunModal(Page::"Field Lookup", FieldRec) <> Action::LookupOK then
            exit(false);
        FieldNo := FieldRec."No.";
        exit(true);
    end;
}
