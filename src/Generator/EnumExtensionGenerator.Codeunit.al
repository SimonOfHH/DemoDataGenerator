namespace SimonOfHH.DemoData.Generator;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Core;

/// <summary>
/// Generates the enumextension for "Contoso Demo Data Module" (Enum 5160).
/// Adds one value mapping to the generated module codeunit.
/// </summary>
codeunit 70123 "Enum Extension Generator"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        IdentifierHelper: Codeunit "Identifier Helper";

    /// <summary>
    /// Generates the enum extension for the given module definition.
    /// </summary>
    procedure Generate(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container"): Codeunit "CodeGen Enum Extension"
    var
        EnumExt: Codeunit "CodeGen Enum Extension";
        ExtName: Text;
        ModuleCUName: Text;
    begin
        ExtName := this.IdentifierHelper.GetEnumExtensionName(ModuleDef.Name);
        ModuleCUName := this.IdentifierHelper.GetModuleCodeunitName(ModuleDef.Name);
        EnumExt.Initialize(ModuleContainer.GetNextEnumExtensionId(true), ExtName, 'Contoso Demo Data Module');
        EnumExt.AddEnumValue(ModuleDef."Enum Ordinal", ModuleDef."Enum Value Name", ModuleCUName);

        if ModuleDef."Base Namespace" <> '' then
            EnumExt.Namespace(ModuleDef."Base Namespace");
        EnumExt.AddUsing('Microsoft.DemoTool');
        ModuleContainer.AddEnumExtension(EnumExt);
        exit(EnumExt);
    end;
}
