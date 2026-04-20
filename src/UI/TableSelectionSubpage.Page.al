namespace SimonOfHH.DemoData.UI;

using SimonOfHH.DemoData.Model;

/// <summary>
/// Subpage showing selected tables for a module definition.
/// </summary>
page 70102 "Table Selection Subpage"
{
    ApplicationArea = All;
    Caption = 'Table Selections';
    PageType = ListPart;
    SourceTable = "Table Selection";
    SourceTableView = sorting("Module Code", "Sort Order");
    AutoSplitKey = true;

    layout
    {
        area(Content)
        {
            repeater(Tables)
            {
                field("Table ID"; Rec."Table ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the ID of the selected table.';
                }
                field("Table Name"; Rec."Table Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the selected table.';
                }
                field("Data Level"; Rec."Data Level")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies which Contoso data level this table belongs to.';
                }
                field("Helper Group"; Rec."Helper Group")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the helper codeunit grouping key. Tables sharing the same group are combined into one Contoso helper codeunit.';
                }
                field("Sort Order"; Rec."Sort Order")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the generation order within a data level.';
                }
                field("No. of Fields"; Rec."No. of Fields")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the total number of field configuration records.';
                }
                field("No. of Configured Fields"; Rec."No. of Configured Fields")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the number of fields with behavior other than Exclude.';
                }
                field("AL Namespace"; Rec."AL Namespace")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the AL namespace for the generated code for this table. If not specified, the default namespace will be used.';
                    Visible = false; // This is an advanced option that is not commonly used, so we hide it by default to reduce clutter.
                }
                field("Helper Codeunit Name"; Rec."Helper Codeunit Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the helper codeunit for this table. If not specified, a name will be auto-generated based on the module and helper group.';
                    Visible = false; // This is an advanced option that is not commonly used, so we hide it by default to reduce clutter.
                }
                field("Data Codeunit Name"; Rec."Data Codeunit Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the name of the data codeunit for this table. If not specified, a name will be auto-generated based on the table name.';
                    Visible = false; // This is an advanced option that is not commonly used, so we hide it by default to reduce clutter.   
                }
                field("Table View"; Rec."Table View")
                {
                    ApplicationArea = All;
                    ToolTip = 'Shows the current filter that will be applied when generating code for this table. This can be edited by clicking the "Apply Filter" action.';
                    Visible = false; // This is an advanced option that is not commonly used, so we hide it by default to reduce clutter.
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ConfigureFields)
            {
                ApplicationArea = All;
                Caption = 'Configure Fields';
                Image = Setup;
                ToolTip = 'Open the field configuration page for this table.';
                Scope = Repeater;

                trigger OnAction()
                var
                    FieldConfig: Record "Field Configuration";
                begin
                    FieldConfig.SetRange("Module Code", Rec."Module Code");
                    FieldConfig.SetRange("Table ID", Rec."Table ID");
                    Page.RunModal(Page::"Field Configuration", FieldConfig);
                end;
            }
            action(PopulateFields)
            {
                ApplicationArea = All;
                Caption = 'Populate Fields';
                Image = Refresh;
                ToolTip = 'Read table metadata and populate field configurations for this table.';
                Scope = Repeater;

                trigger OnAction()
                begin
                    Rec.PopulateFields();
                    Message(FieldsPopulatedMsg, Rec."Table Name");
                end;
            }
            action(AutoSuggestLevels)
            {
                ApplicationArea = All;
                Caption = 'Auto-Suggest Levels';
                Image = Suggest;
                ToolTip = 'Auto-assigns data levels based on table name heuristics.';

                trigger OnAction()
                var
                    TableSel: Record "Table Selection";
                    TableName: Text;
                begin
                    TableSel.CopyFilters(Rec);
                    if TableSel.FindSet() then
                        repeat
                            TableName := LowerCase(TableSel."Table Name");
                            if TableName.Contains('setup') or TableName.Contains('config') or
                               TableName.Contains('posting group') or TableName.Contains('template') or
                               TableName.Contains('journal batch') or TableName.Contains('no. series')
                            then
                                TableSel."Data Level" := "Data Level"::"Setup Data"
                            else
                                if TableSel."Data Level" = "Data Level"::" " then
                                    TableSel."Data Level" := "Data Level"::"Master Data";
                            TableSel.Modify(true);
                        until TableSel.Next() = 0;
                end;
            }
            group(TableActions)
            {
                Caption = 'Table';
                ShowAs = SplitButton;
                Image = Table;
                action(OpenTablePage)
                {
                    ApplicationArea = All;
                    Caption = 'Open Table';
                    Image = ViewPage;
                    ToolTip = 'Open the default page for this table in a new session to help with data exploration.';
                    Scope = Repeater;

                    trigger OnAction()
                    var
                    begin
                        if not TryOpenTablePage('') then
                            Message('Could not open a page for table "%1". Please make sure this table has a default page and that you have access to it.', Rec."Table Name");
                    end;
                }
                action(ApplyFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Apply Filter';
                    Image = Filter;
                    ToolTip = 'Apply a filter to this table to limit the generated code to a subset of the data. The filter should be specified in the format "FieldName=Value". For example, "CountryRegionCode=''US''" would generate code only for records where the CountryRegionCode field is blank or US.';

                    trigger OnAction()
                    var
                        FilterView: Text;
                    begin
                        Rec.TestField("Table ID");
                        FilterView := Rec."Table View";
                        if not TryGetTableFilter(Rec."Table ID", FilterView) then
                            Message('Could not open a page for table "%1". Please make sure this table has a default page and that you have access to it.', Rec."Table Name");
                        if StrLen(FilterView) > MaxStrLen(Rec."Table View") then
                            Message('The filtered view is too long to be saved (max. %1 characters). The filter will be shortened to fit.\\Original Filter: %2\\Shortened Filter: %3', MaxStrLen(Rec."Table View"), FilterView, CopyStr(FilterView, 1, MaxStrLen(Rec."Table View")));
                        Rec."Table View" := CopyStr(FilterView, 1, MaxStrLen(Rec."Table View"));
                        Rec.Modify();
                    end;
                }
                action(ClearFilter)
                {
                    ApplicationArea = All;
                    Caption = 'Clear Filter';
                    Image = ClearFilter;
                    ToolTip = 'Clear any filters applied to this table. This will cause the generated code to include all records from this table.';

                    trigger OnAction()
                    begin
                        Rec."Table View" := '';
                        Rec.Modify();
                    end;
                }
                action(OpenTableFilteredPage)
                {
                    ApplicationArea = All;
                    Caption = 'Open Table with Filter';
                    Image = ViewPage;
                    ToolTip = 'Open a filtered view of this table to help with data exploration and to assist with building filters for code generation.';
                    Scope = Repeater;

                    trigger OnAction()
                    var
                    begin
                        if not TryOpenTablePage(Rec."Table View") then
                            Message('Could not open a page for table "%1". Please make sure this table has a default page and that you have access to it.', Rec."Table Name");
                    end;
                }
            }
        }
    }

    var
        FieldsPopulatedMsg: Label 'Field configurations populated for table "%1".', Comment = '%1 = Table Name';

    [TryFunction]
    local procedure TryOpenTablePage(FilterView: Text)
    var
        RecRef: RecordRef;
        VarRecRef: Variant;
    begin
        RecRef.Open(Rec."Table ID");
        if FilterView <> '' then
            RecRef.SetView(FilterView);
        VarRecRef := RecRef;
        Page.Run(0, VarRecRef);
    end;

    [TryFunction]
    local procedure TryGetTableFilter(TableId: Integer; var FilterView: Text)
    var
        FilterPageBuilder: FilterPageBuilder;
        RecRef: RecordRef;
    begin
        RecRef.Open(TableId);
        RecRef.SetView(FilterView);
        FilterPageBuilder.AddRecordRef('Filter', RecRef);
        if FilterPageBuilder.RunModal() then
            FilterView := FilterPageBuilder.GetView('Filter');
    end;
}
