namespace SimonOfHH.DemoData.CodeGen;

using SimonOfHH.DemoData.Model;

/// <summary>
/// Simple AST node representing a generated non-AL sidecar file (e.g. a JSON data
/// snapshot for a Document Group or a standalone Transaction/Historical table) that
/// must be bundled into the export zip next to its paired stub data codeunit.
/// </summary>
codeunit 70129 "CodeGen Data File"
{
    var
        FileNameValue: Text;
        ContentValue: Text;
        TableDataLevel: Enum "Data Level";

    procedure Initialize(NewFileName: Text; NewContent: Text; NewDataLevel: Enum "Data Level")
    begin
        this.FileNameValue := NewFileName;
        this.ContentValue := NewContent;
        this.TableDataLevel := NewDataLevel;
    end;

    procedure FileName(): Text
    begin
        exit(this.FileNameValue);
    end;

    procedure Content(): Text
    begin
        exit(this.ContentValue);
    end;

    procedure DataLevel(): Enum "Data Level"
    begin
        exit(this.TableDataLevel);
    end;
}
