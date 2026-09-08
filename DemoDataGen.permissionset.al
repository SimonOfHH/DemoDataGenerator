namespace SimonOfHH.DemoData;

using SimonOfHH.DemoData.Model;

permissionset 70100 DemoDataGen
{
    Assignable = true;
    Permissions = tabledata "Code Segment" = RIMD,
        tabledata "Document Group" = RIMD,
        tabledata "Document Group Link" = RIMD,
        tabledata "Field Configuration" = RIMD,
        tabledata "Module Definition" = RIMD,
        tabledata "Module Dependency" = RIMD,
        tabledata "Table Selection" = RIMD;
}