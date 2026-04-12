namespace SimonOfHH.DemoData.Generator;

using SimonOfHH.DemoData.Model;
using System.Apps;
using SimonOfHH.DemoData.CodeGen;

/// <summary>
/// Generates the app.json manifest for the generated AL extension.
/// Always includes the Contoso Coffee Demo Dataset dependency.
/// Auto-detects additional dependencies from Field Configuration Source App IDs.
/// </summary>
codeunit 70124 "App Manifest Generator"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    /// <summary>
    /// Generates the app manifest for the given module definition.
    /// </summary>
    procedure Generate(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container")
    var
        FieldConfig: Record "Field Configuration";
        Manifest: Codeunit "CodeGen App Manifest";
        ProcessedAppIds: List of [Guid];
        ExcludeList: List of [Text];
        ExcludeEntry: Text;
        AppId: Guid;
    begin
        Manifest.Id(ModuleDef."App ID");
        Manifest.Name(ModuleDef.Name);
        Manifest.Publisher(ModuleDef.Publisher);
        Manifest.Version(ModuleDef."App Version");
        Manifest.Description(ModuleDef.Description);
        Manifest.IdRange(ModuleDef."ID Range Start", ModuleDef."ID Range End");

        // Mandatory: Contoso Coffee Demo Dataset dependency
        Manifest.AddDefaultDependencies();

        // Parse excluded app IDs
        if ModuleDef."Apps to Exclude" <> '' then
            foreach ExcludeEntry in ModuleDef."Apps to Exclude".Split(',') do
                ExcludeList.Add(ExcludeEntry.Trim());

        // Auto-detect additional dependencies from Source App IDs
        FieldConfig.SetRange("Module Code", ModuleDef.Code);
        FieldConfig.SetFilter(Behavior, '<>%1', FieldConfig.Behavior::Exclude);
        if FieldConfig.FindSet() then
            repeat
                AppId := FieldConfig."Source App ID";
                if not IsNullGuid(AppId) then
                    if not ProcessedAppIds.Contains(AppId) then
                        if not ExcludeList.Contains(Format(AppId)) then begin
                            ProcessedAppIds.Add(AppId);
                            ResolveAndAddDependency(Manifest, AppId);
                        end;
            until FieldConfig.Next() = 0;
        ModuleContainer.AddManifestCodeunit(Manifest);
    end;

    local procedure ResolveAndAddDependency(var Manifest: Codeunit "CodeGen App Manifest"; AppId: Guid)
    var
        NAVAppInstalledApp: Record "NAV App Installed App";
    begin
        NAVAppInstalledApp.SetRange("App ID", AppId);
        if NAVAppInstalledApp.FindFirst() then
            Manifest.AddDependency(
                Format(AppId),
                NAVAppInstalledApp.Name,
                NAVAppInstalledApp.Publisher,
                StrSubstNo('%1.0.0.0', NAVAppInstalledApp."Version Major"));
    end;
}
