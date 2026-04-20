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

    local procedure AddCreateDataProc(var ModuleCU: Codeunit "CodeGen Codeunit"; ModuleCode: Code[20]; ProcName: Text; Level: Enum "Data Level"; IsStub: Boolean)
    var
        TableSelection: Record "Table Selection";
        Proc: Codeunit "CodeGen Procedure";
        HasTables: Boolean;
        CodeunitRunPlaceholderLbl: Label 'Codeunit.Run(Codeunit::"%1");', Comment = 'Used in Create*Data procedures to run a data codeunit for a table, %1 = Codeunit Name', Locked = true;
    begin
        Clear(Proc);
        Proc.Init(ProcName);

        TableSelection.SetRange("Module Code", ModuleCode);
        TableSelection.SetRange("Data Level", Level);
        TableSelection.SetCurrentKey("Module Code", "Data Level", "Sort Order");
        HasTables := TableSelection.FindSet();

        if HasTables then begin
            if IsStub then
                Proc.AddCodeLine('// TODO: Review — auto-generated from selected tables');
            repeat
                if TableSelection."Data Codeunit Name" = '' then
                    TableSelection."Data Codeunit Name" := CopyStr(this.IdentifierHelper.GetCreateCodeunitName(TableSelection."Table Name"), 1, MaxStrLen(TableSelection."Data Codeunit Name"));
                Proc.AddCodeLine(StrSubstNo(CodeunitRunPlaceholderLbl, TableSelection."Data Codeunit Name"));
            until TableSelection.Next() = 0;
        end;

        ModuleCU.AddProcedure(Proc);
    end;
}
