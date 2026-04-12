namespace SimonOfHH.DemoData.CodeGen;

/// <summary>
/// Container that holds all generated AST nodes for a single module.
/// Tracks the app manifest, module codeunit, enum extension, helper codeunits,
/// and data codeunits, as well as the object ID allocation sequence.
/// </summary>
codeunit 70126 "CodeGen Module Container"
{
    var
        ManifestCodeunit: Codeunit "CodeGen App Manifest";
        ModuleCodeunit: Codeunit "CodeGen Codeunit";
        EnumExt: Codeunit "CodeGen Enum Extension";
        HelperCodeunits: List of [Codeunit "CodeGen Codeunit"];
        DataCodeunits: List of [Codeunit "CodeGen Codeunit"];
        ObjectIds: Dictionary of [Text, Integer];

    procedure Init(StartIdRange: Integer)
    begin
        this.ObjectIds.Add('Codeunit', StartIdRange);
        this.ObjectIds.Add('EnumExtension', StartIdRange);
    end;

    /// <summary>
    /// Returns the next available codeunit ID.
    /// </summary>
    /// <param name="Increment">When true, advances the internal counter so the next call returns a new ID. When false, peeks at the current value without consuming it.</param>
    procedure GetNextCodeunitId(Increment: Boolean): Integer
    begin
        exit(this.GetNextObjectId('Codeunit', Increment));
    end;

    /// <summary>
    /// Returns the next available enum extension ID.
    /// </summary>
    /// <param name="Increment">When true, advances the internal counter so the next call returns a new ID. When false, peeks at the current value without consuming it.</param>
    procedure GetNextEnumExtensionId(Increment: Boolean): Integer
    begin
        exit(this.GetNextObjectId('EnumExtension', Increment));
    end;

    /// <summary>
    /// Returns the next available object ID for the given type and optionally advances the counter.
    /// </summary>
    /// <param name="ObjectType">Object type key ('Codeunit' or 'EnumExtension').</param>
    /// <param name="Increment">When true, increments the counter after reading, allocating the ID. When false, returns the current value without side effects (peek).</param>
    procedure GetNextObjectId(ObjectType: Text; Increment: Boolean): Integer
    var
        Result: Integer;
    begin
        this.ObjectIds.Get(ObjectType, Result);
        if Increment then
            this.ObjectIds.Set(ObjectType, Result + 1);
        exit(Result);
    end;

    procedure AddHelperCodeunit(Codeunit: Codeunit "CodeGen Codeunit")
    begin
        this.HelperCodeunits.Add(Codeunit);
    end;

    procedure AddDataCodeunit(Codeunit: Codeunit "CodeGen Codeunit")
    begin
        this.DataCodeunits.Add(Codeunit);
    end;

    procedure AddManifestCodeunit(Manifest: Codeunit "CodeGen App Manifest")
    begin
        this.ManifestCodeunit := Manifest;
    end;

    procedure AddModuleCodeunit(ModuleCU: Codeunit "CodeGen Codeunit")
    begin
        this.ModuleCodeunit := ModuleCU;
    end;

    procedure AddEnumExtension(EnumExtension: Codeunit "CodeGen Enum Extension")
    begin
        this.EnumExt := EnumExtension;
    end;

    procedure GetHelperCodeunits(): List of [Codeunit "CodeGen Codeunit"]
    begin
        exit(this.HelperCodeunits);
    end;

    procedure GetDataCodeunits(): List of [Codeunit "CodeGen Codeunit"]
    begin
        exit(this.DataCodeunits);
    end;

    procedure GetManifestCodeunit(): Codeunit "CodeGen App Manifest"
    begin
        exit(this.ManifestCodeunit);
    end;

    procedure GetModuleCodeunit(): Codeunit "CodeGen Codeunit"
    begin
        exit(this.ModuleCodeunit);
    end;

    procedure GetEnumExtension(): Codeunit "CodeGen Enum Extension"
    begin
        exit(this.EnumExt);
    end;
}