namespace SimonOfHH.DemoData.CodeGen;

/// <summary>
/// Shared base for all code generation AST nodes.
/// Holds the common object header (type, ID, name), namespace, usings, implements clause, and properties.
/// Used by CodeGen Codeunit and CodeGen Enum Extension to avoid duplicating object-level metadata.
/// </summary>
codeunit 70128 "CodeGen Base Object"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        InternalUsings: List of [Text];
        InternalProperties: Dictionary of [Text, Text];
        InternalID: Integer;
        InternalType, InternalName, InternalImplements, InternalNamespace : Text;

    procedure InitializeCodeunit(NewObjectId: Integer; NewObjectName: Text)
    begin
        this.InitializeCodeunit(NewObjectId, NewObjectName, '');
    end;

    procedure InitializeCodeunit(NewObjectId: Integer; NewObjectName: Text; NewImplements: Text)
    begin
        this.SetHeader('codeunit', NewObjectId, NewObjectName);
        this.InternalImplements := NewImplements;
    end;

    procedure InitializeEnumExtension(NewObjectId: Integer; NewObjectName: Text)
    begin
        this.InitializeEnumExtension(NewObjectId, NewObjectName, '');
    end;

    procedure InitializeEnumExtension(NewObjectId: Integer; NewObjectName: Text; NewBaseEnumExt: Text)
    begin
        this.SetHeader('enumextension', NewObjectId, NewObjectName);
        this.InternalImplements := NewBaseEnumExt;
    end;

    procedure SetHeader(NewObjType: Text; NewObjectId: Integer; NewObjectName: Text)
    begin
        this.InternalType := NewObjType;
        this.InternalID := NewObjectId;
        this.InternalName := NewObjectName;
    end;

    procedure AddUsing(Using: Text)
    begin
        this.InternalUsings.Add(Using);
    end;

    procedure AddProperty("Key": Text; Value: Text)
    begin
        this.InternalProperties.Set("Key", Value);
    end;

    procedure Implements(NewImplements: Text)
    begin
        this.InternalImplements := NewImplements;
    end;

    procedure Implements(): Text
    begin
        exit(this.InternalImplements);
    end;

    procedure Namespace(NewNamespace: Text)
    begin
        this.InternalNamespace := NewNamespace;
    end;

    procedure Namespace(): Text
    begin
        exit(this.InternalNamespace);
    end;

    procedure ObjectType(): Text
    begin
        exit(this.InternalType);
    end;

    procedure Id(): Integer
    begin
        exit(this.InternalID);
    end;

    procedure Name(): Text
    begin
        exit(this.InternalName);
    end;

    procedure Properties(): Dictionary of [Text, Text]
    begin
        exit(this.InternalProperties);
    end;

    procedure Usings(): List of [Text]
    begin
        exit(this.InternalUsings);
    end;

    procedure ToIdentifierString(): Text
    begin
        exit(StrSubstNo('%1 "%2"', this.InternalID, this.InternalName));
    end;
}