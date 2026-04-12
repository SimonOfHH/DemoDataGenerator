namespace SimonOfHH.DemoData.CodeGen;

/// <summary>
/// Indent-aware text writer for serializing AST nodes to AL source code.
/// Manages indentation levels and provides helper methods for writing
/// object declarations, namespaces, usings, properties, and global variables.
/// </summary>
codeunit 70127 "CodeGen Writer"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        Output: TextBuilder;
        IndentLevel: Integer;

    procedure WriteBaseObject(BaseObject: Codeunit "CodeGen Base Object")
    begin
        this.WriteNamespace(BaseObject.Namespace());
        this.WriteUsings(BaseObject.Usings());
        this.WriteObjectDeclaration(BaseObject.ObjectType(), BaseObject.Id(), BaseObject.Name(), BaseObject.Implements());
        this.AppendLine('{');
        this.IncreaseIndent();
        this.WriteProperties(BaseObject.Properties());
        this.DecreaseIndent();
    end;

    procedure WriteNamespace(Namespace: Text)
    begin
#pragma warning disable AA0217 // allow using StrSubstNo in code generation templates for readability
        if Namespace = '' then
            exit;
        this.AppendLine(StrSubstNo('namespace %1;', Namespace));
        this.AppendLine('');
#pragma warning restore AA0217
    end;

    procedure WriteUsings(Usings: List of [Text])
    var
        "Key": Text;
    begin
#pragma warning disable AA0217
        if Usings.Count = 0 then
            exit;
        foreach "Key" in Usings do
            this.AppendLine(StrSubstNo('using %1;', "Key"));
        this.AppendLine('');
#pragma warning restore AA0217
    end;

    procedure WriteObjectDeclaration(ObjType: Text; ObjId: Integer; ObjName: Text; ObjImplements: Text)
    var
        ImplementationText: Text;
    begin
#pragma warning disable AA0217
        if ObjImplements <> '' then
            if ObjType.ToLower() = 'codeunit' then
                ImplementationText := StrSubstNo(' implements "%1"', ObjImplements)
            else
                ImplementationText := StrSubstNo(' extends "%1"', ObjImplements);
        this.AppendLine(StrSubstNo('%1 %2 "%3"%4', ObjType, ObjId, ObjName, ImplementationText));
#pragma warning restore AA0217
    end;

    procedure WriteProperties(Properties: Dictionary of [Text, Text])
    var
        "Key": Text;
        Value: Text;
    begin
        if Properties.Count = 0 then
            exit;
        foreach "Key" in Properties.Keys do begin
            Properties.Get("Key", Value);
            this.AppendLine(StrSubstNo('%1 = %2;', "Key", Value));
        end;
        this.AppendLine('');
    end;

    procedure WriteGlobalVariables(GlobalVariables: List of [Codeunit "CodeGen Variable"]; LabelDeclarations: List of [Text])
    var
        Variable: Codeunit "CodeGen Variable";
        LabelLine: Text;
    begin
        if GlobalVariables.Count = 0 then
            exit;
        this.AppendLine('var');
        this.IncreaseIndent();
        foreach Variable in GlobalVariables do
            this.AppendLine(Variable.ToString() + ';');
        foreach LabelLine in LabelDeclarations do
            this.AppendLine(LabelLine);
        this.DecreaseIndent();
        this.AppendLine('');
    end;

    procedure AppendLine(Line: Text)
    begin
        this.Output.AppendLine(this.GetIndent(this.IndentLevel) + Line);
    end;

    procedure ToText(): Text
    begin
        exit(this.Output.ToText());
    end;

    procedure IncreaseIndent()
    begin
        this.IndentLevel += 1;
    end;

    procedure DecreaseIndent()
    begin
        if this.IndentLevel > 0 then
            this.IndentLevel -= 1;
    end;

    procedure GetIndent(Level: Integer): Text
    var
        Result: TextBuilder;
        i: Integer;
    begin
        for i := 1 to Level do
            Result.Append('    ');
        exit(Result.ToText());
    end;
}