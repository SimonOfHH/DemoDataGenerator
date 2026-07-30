namespace SimonOfHH.DemoData.Generator;

using SimonOfHH.DemoData.Model;
using SimonOfHH.DemoData.CodeGen;
using SimonOfHH.DemoData.Core;

/// <summary>
/// Generates the module codeunit that implements "Contoso Demo Data Module".
/// Contains RunConfigurationPage, GetDependencies, and Create*Data procedures
/// that call Codeunit.Run for each data codeunit at the corresponding level.
/// </summary>
codeunit 70122 "Module Generator"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        IdentifierHelper: Codeunit "Identifier Helper";

    /// <summary>
    /// Generates the module codeunit for the given module definition.
    /// </summary>
    procedure Generate(ModuleDef: Record "Module Definition"; var ModuleContainer: Codeunit "CodeGen Module Container"): Codeunit "CodeGen Codeunit"
    var
        ModuleCU: Codeunit "CodeGen Codeunit";
        CUName: Text;
    begin
        CUName := this.IdentifierHelper.GetModuleCodeunitName(ModuleDef.Name);

        ModuleCU.Initialize(ModuleContainer.GetNextCodeunitId(true), CUName, 'Contoso Demo Data Module');
        ModuleCU.AddUsing('Microsoft.DemoTool');

        if ModuleDef."Base Namespace" <> '' then begin
            ModuleCU.Namespace(ModuleDef."Base Namespace");
            ModuleCU.AddUsing(ModuleDef."Base Namespace" + '.DemoData');
        end;

        ModuleCU.AddProperty('InherentEntitlements', 'X');
        ModuleCU.AddProperty('InherentPermissions', 'X');

        this.AddRunConfigurationPage(ModuleCU);
        this.AddGetDependencies(ModuleCU, ModuleDef.Code);
        this.AddCreateDataProc(ModuleCU, ModuleDef.Code, 'CreateSetupData', "Data Level"::"Setup Data", false);
        this.AddCreateDataProc(ModuleCU, ModuleDef.Code, 'CreateMasterData', "Data Level"::"Master Data", false);
        this.AddCreateDataProc(ModuleCU, ModuleDef.Code, 'CreateTransactionalData', "Data Level"::"Transaction Data", true);
        this.AddCreateDataProc(ModuleCU, ModuleDef.Code, 'CreateHistoricalData', "Data Level"::"Historical Data", true);
        ModuleContainer.AddModuleCodeunit(ModuleCU);
        exit(ModuleCU);
    end;

    local procedure AddRunConfigurationPage(var ModuleCU: Codeunit "CodeGen Codeunit")
    var
        Proc: Codeunit "CodeGen Procedure";
    begin
        Clear(Proc);
        Proc.Init('RunConfigurationPage');
        Proc.AddCodeLine('Message(''No configuration is needed for this module.'');');
        ModuleCU.AddProcedure(Proc);
    end;

    local procedure AddGetDependencies(var ModuleCU: Codeunit "CodeGen Codeunit"; ModuleCode: Code[20])
    var
        ModuleDep: Record "Module Dependency";
        Proc: Codeunit "CodeGen Procedure";
        DependencyAddPlaceholderLbl: Label 'Dependencies.Add(Enum::"Contoso Demo Data Module"::"%1");', Comment = 'Used in GetDependencies procedure to add a dependency, %1 = Dependency Module Name', Locked = true;
    begin
        Clear(Proc);
        Proc.Init('GetDependencies');
        Proc.SetReturn('List of [Enum "Contoso Demo Data Module"]', 'Dependencies');

        ModuleDep.SetRange("Module Code", ModuleCode);
        if ModuleDep.FindSet() then
            repeat
                Proc.AddCodeLine(
                    StrSubstNo(DependencyAddPlaceholderLbl, ModuleDep."Dependency Module Name"));
            until ModuleDep.Next() = 0;

        ModuleCU.AddProcedure(Proc);
    end;

    /// <summary>
    /// Builds a Create*Data procedure containing one Codeunit.Run call per generated data
    /// codeunit at the given level. For Setup/Master levels this is one call per selected
    /// table (matching "Data Generator"). For Transaction/Historical levels this is one call
    /// per Document Group plus one per standalone (ungrouped) table (matching what "Document
    /// Data Generator" actually emits for those levels).
    /// </summary>
    local procedure AddCreateDataProc(var ModuleCU: Codeunit "CodeGen Codeunit"; ModuleCode: Code[20]; ProcName: Text; Level: Enum "Data Level"; IsStub: Boolean)
    var
        Proc: Codeunit "CodeGen Procedure";
        CodeunitNames: List of [Text];
    begin
        Clear(Proc);
        Proc.Init(ProcName);

        if IsStub then
            CodeunitNames := this.GetStubCodeunitNames(ModuleCode, Level)
        else
            CodeunitNames := this.GetPerTableCodeunitNames(ModuleCode, Level);

        this.AddCodeunitRunLines(Proc, CodeunitNames, IsStub);

        ModuleCU.AddProcedure(Proc);
    end;

    local procedure AddCodeunitRunLines(var Proc: Codeunit "CodeGen Procedure"; CodeunitNames: List of [Text]; IsStub: Boolean)
    var
        CodeunitName: Text;
        CodeunitRunPlaceholderLbl: Label 'Codeunit.Run(Codeunit::"%1");', Comment = 'Used in Create*Data procedures to run a data codeunit, %1 = Codeunit Name', Locked = true;
    begin
        if CodeunitNames.Count() = 0 then
            exit;
        if IsStub then
            Proc.AddCodeLine('// TODO: Review — auto-generated from selected tables');
        foreach CodeunitName in CodeunitNames do
            Proc.AddCodeLine(StrSubstNo(CodeunitRunPlaceholderLbl, CodeunitName));
    end;

    /// <summary>
    /// Returns one Data Codeunit Name per selected table at the given level, deriving and
    /// caching a default name on the in-memory record when not already set.
    /// </summary>
    local procedure GetPerTableCodeunitNames(ModuleCode: Code[20]; Level: Enum "Data Level"): List of [Text]
    var
        TableSelection: Record "Table Selection";
        Results: List of [Text];
    begin
        TableSelection.SetRange("Module Code", ModuleCode);
        TableSelection.SetRange("Data Level", Level);
        TableSelection.SetCurrentKey("Module Code", "Data Level", "Sort Order");
        if TableSelection.FindSet() then
            repeat
                if TableSelection."Data Codeunit Name" = '' then
                    TableSelection."Data Codeunit Name" := CopyStr(this.IdentifierHelper.GetCreateCodeunitName(TableSelection."Table Name"), 1, MaxStrLen(TableSelection."Data Codeunit Name"));
                Results.Add(TableSelection."Data Codeunit Name");
            until TableSelection.Next() = 0;
        exit(Results);
    end;

    /// <summary>
    /// Returns one codeunit name per Document Group at the given level, plus one per
    /// standalone (ungrouped) table at that level - matching exactly what "Document Data
    /// Generator" produces for Transaction/Historical data levels.
    /// </summary>
    local procedure GetStubCodeunitNames(ModuleCode: Code[20]; Level: Enum "Data Level"): List of [Text]
    var
        DocumentGroup: Record "Document Group";
        TableSelection: Record "Table Selection";
        Results: List of [Text];
    begin
        DocumentGroup.SetRange("Module Code", ModuleCode);
        DocumentGroup.SetRange("Data Level", Level);
        if DocumentGroup.FindSet() then
            repeat
                Results.Add(DocumentGroup.GetEffectiveDataCodeunitName());
            until DocumentGroup.Next() = 0;

        TableSelection.SetRange("Module Code", ModuleCode);
        TableSelection.SetRange("Data Level", Level);
        TableSelection.SetRange("Document Group Code", '');
        TableSelection.SetCurrentKey("Module Code", "Data Level", "Sort Order");
        if TableSelection.FindSet() then
            repeat
                if TableSelection."Data Codeunit Name" = '' then
                    TableSelection."Data Codeunit Name" := CopyStr(this.IdentifierHelper.GetCreateCodeunitName(TableSelection."Table Name"), 1, MaxStrLen(TableSelection."Data Codeunit Name"));
                Results.Add(TableSelection."Data Codeunit Name");
            until TableSelection.Next() = 0;
        exit(Results);
    end;
}
