namespace SimonOfHH.DemoData.CodeGen;

/// <summary>
/// In-memory AST node representing an AL procedure or trigger.
/// Holds parameters, local variables, return type, and body code lines.
/// </summary>
codeunit 70111 "CodeGen Procedure"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        Parameters: List of [Codeunit "CodeGen Variable"];
        LocalVariables: List of [Codeunit "CodeGen Variable"];
        Codebuilder: TextBuilder;
        ProcName: Text;
        ProcIsTrigger: Boolean;
        ProcIsLocal: Boolean;
        ProcReturnType: Text;
        ProcReturnName: Text;
        CurrentIndentLevel: Integer;

    /// <summary>
    /// Initialize the procedure with its name.
    /// </summary>
    procedure Init(Name: Text)
    begin
        this.ProcName := Name;
    end;

    procedure Init(ComplexArgument: Codeunit "CodeGen Argument")
    begin
        this.ProcName := ComplexArgument.Name(true);
        this.ProcReturnType := ComplexArgument.ReturnType();
        this.ProcReturnName := ComplexArgument.ReturnName();
#pragma warning disable AA0217
        this.AddCodeLine(StrSubstNo('exit(%1);', ComplexArgument.Name(false)));
#pragma warning restore AA0217
    end;

    procedure SetTrigger(IsTrigger: Boolean)
    begin
        this.ProcIsTrigger := IsTrigger;
    end;

    procedure GetTrigger(): Boolean
    begin
        exit(this.ProcIsTrigger);
    end;

    procedure SetLocal(IsLocal: Boolean)
    begin
        this.ProcIsLocal := IsLocal;
    end;

    procedure SetReturn(ReturnType: Text; ReturnName: Text)
    begin
        this.ProcReturnType := ReturnType;
        this.ProcReturnName := ReturnName;
    end;

    procedure GetName(): Text
    begin
        exit(this.ProcName);
    end;

    procedure AddParameters(Params: List of [Codeunit "CodeGen Variable"])
    var
        Parameter: Codeunit "CodeGen Variable";
    begin
        foreach Parameter in Params do
            this.Parameters.Add(Parameter);
    end;

    procedure AddParameter(Variable: Codeunit "CodeGen Variable")
    begin
        this.Parameters.Add(Variable);
    end;

    procedure AddLocalVariable(Variable: Codeunit "CodeGen Variable")
    begin
        this.LocalVariables.Add(Variable);
    end;

    procedure IncreaseIndent()
    begin
        this.CurrentIndentLevel += 1;
    end;

    procedure DecreaseIndent()
    begin
        if this.CurrentIndentLevel > 0 then
            this.CurrentIndentLevel -= 1;
    end;

    procedure GetIndent(IndentLevel: Integer): Text
    var
        Result: TextBuilder;
        i: Integer;
    begin
        for i := 1 to IndentLevel * 4 do
            Result.Append(' ');
        exit(Result.ToText());
    end;

    procedure AppendLine(Line: Text)
    begin
        this.Codebuilder.AppendLine(this.GetIndent(this.CurrentIndentLevel) + Line);
    end;
    /// <summary>
    /// Appends a line of code to the procedure body.
    /// </summary>
    procedure AddCodeLine(CodeLine: Text)
    begin
        this.AppendLine(CodeLine);
    end;

    /// <summary>
    /// Serializes the procedure to AL source code.
    /// </summary>
    /// <param name="BaseIndent">Number of indent levels for the procedure itself</param>
    procedure ToString(BaseIndent: Integer): Text
    var
        Variable: Codeunit "CodeGen Variable";
        Result: TextBuilder;
        Prefix: Text;
        BodyPrefix: Text;
        First: Boolean;
    begin
        if this.ProcName.EndsWith('()') then
            this.ProcName := this.ProcName.Substring(1, StrLen(this.ProcName) - 2);
        Prefix := this.GetIndent(BaseIndent);
        BodyPrefix := this.GetIndent(BaseIndent + 1);
#pragma warning disable AA0217
        // Procedure signature
        if this.ProcIsTrigger then
            Result.Append(Prefix + StrSubstNo('trigger %1()', this.ProcName))
        else begin
            if this.ProcIsLocal then
                Result.Append(Prefix + 'local ')
            else
                Result.Append(Prefix);

            Result.Append(StrSubstNo('procedure %1(', this.ProcName));

            // Parameters
            First := true;
            foreach Variable in this.Parameters do begin
                if not First then
                    Result.Append('; ');
                Result.Append(Variable.ToString());
                First := false;
            end;

            Result.Append(')');

            // Return type
            if this.ProcReturnName <> '' then
                Result.Append(StrSubstNo(' %1: %2', this.ProcReturnName, this.ProcReturnType))
            else
                if this.ProcReturnType <> '' then
                    Result.Append(StrSubstNo(': %1', this.ProcReturnType));
        end;

        Result.AppendLine('');

        // Local variables
        if this.LocalVariables.Count > 0 then begin
            Result.AppendLine(Prefix + 'var');
            foreach Variable in this.LocalVariables do
                Result.AppendLine(BodyPrefix + Variable.ToString() + ';');
        end;

        // Begin/End
        Result.AppendLine(Prefix + 'begin');

        // Body
        if this.Codebuilder.Length > 0 then
            // Add body prefix indent to each line
            Result.Append(this.IndentBody(this.Codebuilder.ToText(), BodyPrefix));

        Result.Append(Prefix + 'end;');
        Result.AppendLine('');
#pragma warning restore AA0217
        exit(Result.ToText());
    end;

    local procedure IndentBody(BodyText: Text; Prefix: Text): Text
    var
        Lines: List of [Text];
        Line: Text;
        Result: TextBuilder;
        LF, CR : Char;
        NewLine: Text;
    begin
        LF := 10;
        CR := 13;
        NewLine := Format(LF);
        Lines := BodyText.Split(NewLine);
        foreach Line in Lines do begin
            Line := Line.TrimEnd(CR); // Remove any carriage return characters
            if Line <> '' then
                Result.AppendLine(Prefix + Line);
        end;
        exit(Result.ToText());
    end;
}
