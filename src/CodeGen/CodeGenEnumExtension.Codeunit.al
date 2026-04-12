namespace SimonOfHH.DemoData.CodeGen;

/// <summary>
/// In-memory AST node representing an AL enumextension file.
/// Generates enum extensions for the Contoso Demo Data Module enum.
/// </summary>
codeunit 70113 "CodeGen Enum Extension"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        BaseObject: Codeunit "CodeGen Base Object";
        EnumValueOrdinal: Integer;
        EnumValueName: Text;
        EnumValueImplCodeunitName: Text;

    procedure Initialize(NewId: Integer; NewName: Text)
    begin
        this.Initialize(NewId, NewName, '');
    end;

    procedure Initialize(NewId: Integer; NewName: Text; NewImplements: Text)
    begin
        this.BaseObject.InitializeEnumExtension(NewId, NewName, NewImplements);
    end;

    procedure Implements(InterfaceName: Text)
    begin
        this.BaseObject.Implements(InterfaceName);
    end;

    procedure Namespace(NewNamespace: Text)
    begin
        this.BaseObject.Namespace(NewNamespace);
    end;

    procedure AddUsing(Using: Text)
    begin
        this.BaseObject.AddUsing(Using);
    end;

    procedure Id(): Integer
    begin
        exit(this.BaseObject.Id());
    end;

    procedure Name(): Text
    begin
        exit(this.BaseObject.Name());
    end;

    procedure AddProperty("Key": Text; Value: Text)
    begin
        this.BaseObject.AddProperty("Key", Value);
    end;

    procedure ToIdentifierString(): Text
    begin
        exit(this.BaseObject.ToIdentifierString());
    end;

    procedure AddEnumValue(NewOrdinal: Integer; NewName: Text; NewImplementationCodeunitName: Text)
    begin
        this.EnumValueOrdinal := NewOrdinal;
        this.EnumValueName := NewName;
        this.EnumValueImplCodeunitName := NewImplementationCodeunitName;
    end;
    /// <summary>
    /// Serializes to a complete AL enumextension source file.
    /// </summary>
    procedure ToString(): Text
    var
        Writer: Codeunit "CodeGen Writer";
    begin
        Writer.WriteBaseObject(this.BaseObject);
        Writer.IncreaseIndent();
#pragma warning disable AA0217
        Writer.AppendLine(StrSubstNo('value(%1; "%2")', this.EnumValueOrdinal, this.EnumValueName));
        Writer.AppendLine('{');
        Writer.IncreaseIndent();
        Writer.AppendLine(StrSubstNo('Caption = ''%1'';', this.EnumValueName));
        Writer.AppendLine(StrSubstNo('Implementation = "Contoso Demo Data Module" = "%1";', this.EnumValueImplCodeunitName));
        Writer.DecreaseIndent();
        Writer.AppendLine('}');
        Writer.DecreaseIndent();
        Writer.AppendLine('}');
#pragma warning restore AA0217
        exit(Writer.ToText());
    end;
}

