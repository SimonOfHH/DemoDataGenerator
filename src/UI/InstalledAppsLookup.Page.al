namespace SimonOfHH.DemoData.UI;
using System.Apps;

/// <summary>
/// Lookup page showing installed apps in the environment.
/// Used to select apps for the "Apps to Exclude" field.
/// </summary>
page 70105 "Installed Apps Lookup"
{
    ApplicationArea = All;
    Caption = 'Installed Apps';
    UsageCategory = None;
    PageType = List;
    SourceTable = "NAV App Installed App";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Apps)
            {
                field("App ID"; Rec."App ID")
                {
                    ToolTip = 'Specifies the unique identifier of the installed app.';
                    StyleExpr = LineStyleExpr;
                }
                field(Name; Rec.Name)
                {
                    ToolTip = 'Specifies the name of the installed app.';
                    StyleExpr = LineStyleExpr;
                }
                field(Publisher; Rec.Publisher)
                {
                    ToolTip = 'Specifies the publisher of the installed app.';
                    StyleExpr = LineStyleExpr;
                }
            }
        }
    }

    var
        ExclusionIds: Text[2048];
        LineStyleExpr: Text;

    trigger OnAfterGetRecord()
    begin
        if StrPos(ExclusionIds.ToUpper(), Rec."App ID".ToText().ToUpper()) > 0 then
            LineStyleExpr := 'Favorable'
        else
            LineStyleExpr := 'Standard';
    end;

    procedure SetExclusionIds(Ids: Text[2048])
    begin
        ExclusionIds := Ids;
    end;

    procedure GetExclusionIds(): Text
    var
        Ids: Text;
    begin
        CurrPage.SetSelectionFilter(Rec);
        if Rec.FindSet() then
            repeat
                if Ids <> '' then
                    Ids := Ids + ',';
                Ids := Ids + Rec."App ID";
            until Rec.Next() = 0;
        exit(Ids);
    end;
}
