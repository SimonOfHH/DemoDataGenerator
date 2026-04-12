namespace SimonOfHH.DemoData.Core;

/// <summary>
/// Centralizes all AL value formatting logic for code generation.
/// Converts FieldRef values to their AL source code literal representations.
/// </summary>
codeunit 70115 "AL Formatter"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    /// <summary>
    /// Formats a FieldRef value as an AL literal suitable for generated source code.
    /// </summary>
    procedure FormatValue(FldRef: FieldRef): Text
    var
        FormattedDateTimeLbl: Label 'CreateDateTime(%1, %2)', Comment = '%1=Date, %2=Time';
        DateTimeValue: DateTime;
        BoolValue: Boolean;
        IntValue: Integer;
        BigIntValue: BigInteger;
        DecValue: Decimal;
        GuidValue: Guid;
        TextValue: Text;
    begin
        // Handle empty/default values first
        if Format(FldRef.Value) = '' then
            exit(GetDefaultForType(FldRef.Type));

        case FldRef.Type of
            FieldType::Code,
            FieldType::Text:
                begin
                    TextValue := Format(FldRef.Value);
                    exit(AddSingleQuotes(EscapeString(TextValue)));
                end;
            FieldType::Integer:
                begin
                    IntValue := FldRef.Value;
                    exit(Format(IntValue, 0, 9));
                end;
            FieldType::BigInteger:
                begin
                    BigIntValue := FldRef.Value;
                    exit(Format(BigIntValue, 0, 9));
                end;
            FieldType::Decimal:
                begin
                    DecValue := FldRef.Value;
                    exit(Format(DecValue, 0, 9));
                end;
            FieldType::Boolean:
                begin
                    BoolValue := FldRef.Value;
                    if BoolValue then
                        exit('true')
                    else
                        exit('false');
                end;
            FieldType::Date:
                exit(FormatDateValue(FldRef.Value));
            FieldType::Time:
                exit(FormatTimeValue(FldRef.Value));
            FieldType::DateTime:
                begin
                    DateTimeValue := FldRef.Value;
                    if DateTimeValue = 0DT then
                        exit('0DT');
                    exit(StrSubstNo(FormattedDateTimeLbl, FormatDateValue(DT2Date(DateTimeValue)), FormatTimeValue(DT2Time(DateTimeValue))));
                end;
            FieldType::DateFormula:
                begin
                    TextValue := Format(FldRef.Value);
                    // DateFormula is tricky — generate as Evaluate pattern
                    exit(AddSingleQuotes(EscapeString(TextValue)));
                end;
            FieldType::Option:
                begin
                    IntValue := FldRef.Value;
                    exit(Format(IntValue, 0, 9));
                end;
            FieldType::Guid:
                begin
                    GuidValue := FldRef.Value;
                    exit(Format(GuidValue, 0, 9));
                end;
            else
                // Fallback: format as text literal
                exit(AddSingleQuotes(EscapeString(Format(FldRef.Value))));

        end;
    end;

    procedure GetTypeString(FldRef: FieldRef): Text
    var
        TypeStr: Text;
    begin
        TypeStr := Format(FldRef.Type);
        if FldRef.Length > 0 then
            TypeStr += StrSubstNo('[%1]', FldRef.Length);
        exit(TypeStr);
    end;

    /// <summary>
    /// Returns the AL default value literal for a given field type.
    /// </summary>
    procedure GetDefaultForType(FieldType: FieldType): Text
    begin
        case FieldType of
            FieldType::Code,
            FieldType::Text:
                exit(AddSingleQuotes(''));
            FieldType::Integer,
            FieldType::BigInteger,
            FieldType::Decimal,
            FieldType::Option:
                exit('0');
            FieldType::Boolean:
                exit('false');
            FieldType::Date:
                exit('0D');
            FieldType::Time:
                exit('0T');
            FieldType::DateTime:
                exit('0DT');
            // TODO: fix
            FieldType::Guid:
                exit(AddSingleQuotes('{00000000-0000-0000-0000-000000000000}'));
            else
                exit(AddSingleQuotes(''));
        end;
    end;

    procedure AddSingleQuotes(Input: Text): Text
    var
        SingleQuoteChar: Char;
    begin
        SingleQuoteChar := 39; // ASCII code for single quote
        exit(SingleQuoteChar + Input + SingleQuoteChar);
    end;

    /// <summary>
    /// Escapes single quotes in a text value for use in AL string literals.
    /// </summary>
    procedure EscapeString(Input: Text): Text
    begin
        exit(Input.Replace('''', ''''''));
    end;

    /// <summary>
    /// Removes special characters from a text to produce a valid AL identifier.
    /// </summary>
    procedure SanitizeIdentifier(Input: Text): Text
    var
        Result: TextBuilder;
        Char: Char;
        i: Integer;
    begin
        for i := 1 to StrLen(Input) do begin
            Char := Input[i];
            if IsAlphaNumeric(Char) then
                Result.Append(Format(Char));
        end;
        exit(Result.ToText());
    end;

    /// <summary>
    /// Converts a space/underscore-separated string to PascalCase.
    /// E.g., "Bank Account" → "BankAccount", "payment_method" → "PaymentMethod"
    /// </summary>
    procedure ToPascalCase(Input: Text): Text
    var
        Result: TextBuilder;
        Char: Char;
        i: Integer;
        CapitalizeNext: Boolean;
    begin
        CapitalizeNext := true;
        for i := 1 to StrLen(Input) do begin
            Char := Input[i];
            if Char in [' ', '-'] then
                CapitalizeNext := true
            else
                if IsAlphaNumeric(Char) then
                    if CapitalizeNext then begin
                        Result.Append(UpperCase(Format(Char)));
                        CapitalizeNext := false;
                    end else
                        Result.Append(Format(Char));
        end;
        exit(Result.ToText());
    end;

    local procedure FormatDateValue(DateVal: Date): Text
    var
        FormattedDateLbl: Label 'DMY2Date(%1, %2, %3)', Comment = '%1=Day, %2=Month, %3=Year';
    begin
        if DateVal = 0D then
            exit('0D');
        exit(StrSubstNo(FormattedDateLbl, Date2DMY(DateVal, 1), Date2DMY(DateVal, 2), Date2DMY(DateVal, 3)));
    end;

    local procedure FormatTimeValue(TimeVal: Time): Text
    begin
        if TimeVal = 0T then
            exit('0T');
        exit(Format(TimeVal, 0, '<Hours24,2><Filler Character,0><Minutes,2><Seconds,2>T'));
    end;

    local procedure IsAlphaNumeric(Char: Char): Boolean
    begin
        exit(
            ((Char >= 'A') and (Char <= 'Z')) or
            ((Char >= 'a') and (Char <= 'z')) or
            ((Char >= '0') and (Char <= '9')) or
            ((Char = '_'))
        );
    end;

    procedure SanitizeTableName(TableName: Text): Text
    var
        NewTableName: Text;
    begin
        NewTableName := TableName;
        if StrLen(NewTableName) > 30 then
            NewTableName := AbbreviateName(NewTableName, 30);
        // Remove special characters and convert to PascalCase
        if StrLen(NewTableName) > 30 then
            NewTableName := ToPascalCase(SanitizeIdentifier(NewTableName));
        if StrLen(NewTableName) > 30 then
            NewTableName := CopyStr(NewTableName, 1, 30); // Truncate if still too long
        exit(NewTableName);
    end;

    procedure AbbreviateName(Name: Text; MaxLength: Integer): Text
    var
        HelperDictionary: Dictionary of [Text, Text];
        "Key", Value : Text;
        NoReplacements: Boolean;
    begin
        HelperDictionary := GetHelperDictionary();
        while StrLen(Name) > MaxLength do begin
            NoReplacements := true;
            foreach "Key" in HelperDictionary.Keys do
                if Name.Contains("Key") then begin
                    Value := HelperDictionary.Get("Key");
                    Name := Name.Replace("Key", Value);
                    NoReplacements := false;
                end;
            if NoReplacements then
                break; // Prevent infinite loop if no more replacements can be made
        end;

        exit(Name);
    end;

    procedure GetHelperDictionary(): Dictionary of [Text, Text]
    var
        HelperDictionary: Dictionary of [Text, Text];
    begin
        // table from https://alguidelines.dev/docs/bestpractices/suggested-abbreviations/
        HelperDictionary.Add('Absence', 'Abs');
        HelperDictionary.Add('Account', 'Acc');
        HelperDictionary.Add('Accounting', 'Acc');
        HelperDictionary.Add('Accumulated', 'Accum');
        HelperDictionary.Add('Action', 'Act');
        HelperDictionary.Add('Activity', 'Activ');
        HelperDictionary.Add('Additional', 'Add');
        HelperDictionary.Add('Address', 'Addr');
        HelperDictionary.Add('Adjust', 'Adj');
        HelperDictionary.Add('Adjusted', 'Adjd');
        HelperDictionary.Add('Adjustment', 'Adjmt');
        HelperDictionary.Add('Agreement', 'Agrmt');
        HelperDictionary.Add('Allocation', 'Alloc');
        HelperDictionary.Add('Allowance', 'Allow');
        HelperDictionary.Add('Alternative', 'Alt');
        HelperDictionary.Add('Amount', 'Amt');
        HelperDictionary.Add('Amounts', 'Amts');
        HelperDictionary.Add('Answer', 'Ans');
        HelperDictionary.Add('Applies', 'Appl');
        HelperDictionary.Add('Application', 'Appln');
        HelperDictionary.Add('Arrival', 'Arriv');
        HelperDictionary.Add('Assembly', 'Asm');
        HelperDictionary.Add('Assemble To Order', 'ATO');
        HelperDictionary.Add('Assignment', 'Assgnt');
        HelperDictionary.Add('Associated', 'Assoc');
        HelperDictionary.Add('Attachment', 'Attmt');
        HelperDictionary.Add('Authorities', 'Auth');
        HelperDictionary.Add('Automatic', 'Auto');
        HelperDictionary.Add('Availability', 'Avail');
        HelperDictionary.Add('Average', 'Avg');
        HelperDictionary.Add('Ba Db.', 'BA');
        HelperDictionary.Add('Balance', 'Bal');
        HelperDictionary.Add('Bill Of Materials', 'BOM');
        HelperDictionary.Add('Blanket', 'Blnkt');
        HelperDictionary.Add('Budget', 'Budg');
        HelperDictionary.Add('Buffer', 'Buf');
        HelperDictionary.Add('Business', 'Bus');
        HelperDictionary.Add('Business Interaction Management', 'BIM');
        HelperDictionary.Add('Buying', 'Buy');
        HelperDictionary.Add('Calculate', 'Calc');
        HelperDictionary.Add('Calculated', 'Calcd');
        HelperDictionary.Add('Calculation', 'Calcu');
        HelperDictionary.Add('Calendar', 'Cal');
        HelperDictionary.Add('Capacity', 'Cap');
        HelperDictionary.Add('Capacity Requirements Planning', 'CRP');
        HelperDictionary.Add('Cash Flow', 'CF');
        HelperDictionary.Add('Cashflow', 'CF');
        HelperDictionary.Add('Catalog', 'ctlg');
        HelperDictionary.Add('Category', 'Cat');
        HelperDictionary.Add('Central Processing Unit', 'CPU');
        HelperDictionary.Add('Center', 'Ctr');
        HelperDictionary.Add('Change', 'Chg');
        HelperDictionary.Add('Changes', 'Chgs');
        HelperDictionary.Add('Character', 'Char');
        HelperDictionary.Add('Characters', 'Chars');
        HelperDictionary.Add('Charge', 'Chrg');
        HelperDictionary.Add('Charges', 'Chrgs');
        HelperDictionary.Add('Check', 'Chk');
        HelperDictionary.Add('Classification', 'Class');
        HelperDictionary.Add('Collection', 'coll');
        HelperDictionary.Add('Column', 'col');
        HelperDictionary.Add('Comment', 'Cmt');
        HelperDictionary.Add('Company', 'Co');
        HelperDictionary.Add('Component', 'Comp');
        HelperDictionary.Add('Completion', 'Cmpltn');
        HelperDictionary.Add('Components', 'Comps');
        HelperDictionary.Add('Composition', 'Compn');
        HelperDictionary.Add('Compression', 'Compr');
        HelperDictionary.Add('Concurrent', 'Concrnt');
        HelperDictionary.Add('Confidential', 'Conf');
        HelperDictionary.Add('Confirmation', 'Cnfrmn');
        HelperDictionary.Add('Conflict', 'Confl');
        HelperDictionary.Add('Consolidate', 'Consol');
        HelperDictionary.Add('Consolidation', 'Consolid');
        HelperDictionary.Add('Consumption', 'Consump');
        HelperDictionary.Add('Contact', 'Cont');
        HelperDictionary.Add('Container', 'Cntr');
        HelperDictionary.Add('Contract', 'Contr');
        HelperDictionary.Add('Contracted', 'Contrd');
        HelperDictionary.Add('Control', 'Ctrl');
        HelperDictionary.Add('Controls', 'Ctrls');
        HelperDictionary.Add('Conversion', 'Conv');
        HelperDictionary.Add('Correction', 'Cor');
        HelperDictionary.Add('Correspondence', 'Corres');
        HelperDictionary.Add('Corresponding', 'Corresp');
        HelperDictionary.Add('Cost', 'Cst');
        HelperDictionary.Add('Sold', 'COGS');
        HelperDictionary.Add('Credit', 'Cr');
        HelperDictionary.Add('Cumulate', 'Cumul');
        HelperDictionary.Add('Currency', 'Curr');
        HelperDictionary.Add('Current', 'Crnt');
        HelperDictionary.Add('Customer', 'Cust');
        HelperDictionary.Add('Customer/Vendor', 'CV');
        HelperDictionary.Add('Daily', 'Dly');
        HelperDictionary.Add('Dampener', 'Damp');
        HelperDictionary.Add('Database Management System', 'DBMS');
        HelperDictionary.Add('Date', 'D');
        HelperDictionary.Add('Definition', 'Def');
        HelperDictionary.Add('Demonstration', 'Demo');
        HelperDictionary.Add('Department', 'Dept');
        HelperDictionary.Add('Department/Project', 'DP');
        HelperDictionary.Add('Depreciation', 'Depr');
        HelperDictionary.Add('Description', 'Desc');
        HelperDictionary.Add('Detail', 'Dtl');
        HelperDictionary.Add('Detailed', 'Dtld');
        HelperDictionary.Add('Details', 'Dtls');
        HelperDictionary.Add('Deviation', 'Dev');
        HelperDictionary.Add('Difference', 'Diff');
        HelperDictionary.Add('Dimension', 'Dim');
        HelperDictionary.Add('Direct', 'Dir');
        HelperDictionary.Add('Discount', 'Disc');
        HelperDictionary.Add('Discrete', 'Discr');
        HelperDictionary.Add('Distribute', 'Distr');
        HelperDictionary.Add('Distributed', 'Distrd');
        HelperDictionary.Add('Distributor', 'Distbtr');
        HelperDictionary.Add('Distribution', 'Distrn');
        HelperDictionary.Add('Document', 'Doc');
        HelperDictionary.Add('Duplicate', 'Dupl');
        HelperDictionary.Add('Entered', 'Entrd');
        HelperDictionary.Add('Engineering', 'Engin');
        HelperDictionary.Add('Exchange', 'Exch');
        HelperDictionary.Add('Excluding', 'Excl');
        HelperDictionary.Add('Execute', 'Exec');
        HelperDictionary.Add('Expected', 'Expd');
        HelperDictionary.Add('Expedited', 'Exped');
        HelperDictionary.Add('Expense', 'Exp');
        HelperDictionary.Add('Expression', 'Expr');
        HelperDictionary.Add('Expiration', 'Expir');
        HelperDictionary.Add('Extended', 'Ext');
        HelperDictionary.Add('Explode', 'Expl');
        HelperDictionary.Add('Export', 'Expt');
        HelperDictionary.Add('Final', 'Fnl');
        HelperDictionary.Add('Finance', 'Fin');
        HelperDictionary.Add('Fiscal', 'Fisc');
        HelperDictionary.Add('Finished', 'Fnshd');
        HelperDictionary.Add('Fixed Asset', 'FA');
        HelperDictionary.Add('Forward', 'Fwd');
        HelperDictionary.Add('Freight', 'Frt');
        HelperDictionary.Add('General', 'Gen');
        HelperDictionary.Add('General Ledger', 'GL');
        HelperDictionary.Add('Group', 'Gr');
        HelperDictionary.Add('Header', 'Hdr');
        HelperDictionary.Add('History', 'Hist');
        HelperDictionary.Add('Holiday', 'Hol');
        HelperDictionary.Add('Human Resource', 'HR');
        HelperDictionary.Add('Identification', 'ID');
        HelperDictionary.Add('Import', 'Imp');
        HelperDictionary.Add('Inbound', 'Inbnd');
        HelperDictionary.Add('Including', 'Incl');
        HelperDictionary.Add('Included', 'Incld');
        HelperDictionary.Add('Incoming', 'Incmg');
        HelperDictionary.Add('Independent Software Vendor', 'ISV');
        HelperDictionary.Add('Industry', 'Indust');
        HelperDictionary.Add('Information', 'Info');
        HelperDictionary.Add('Initial', 'Init');
        HelperDictionary.Add('Intrastat', 'Intra');
        HelperDictionary.Add('Interaction', 'Interact');
        HelperDictionary.Add('Integration', 'Integr');
        HelperDictionary.Add('Interest', 'Int');
        HelperDictionary.Add('Interim', 'Intm');
        HelperDictionary.Add('Internal Protocol', 'IP');
        HelperDictionary.Add('Inventory', 'Invt');
        HelperDictionary.Add('Inventoriable', 'Invtbl');
        HelperDictionary.Add('Invoice', 'Inv');
        HelperDictionary.Add('Invoiced', 'Invd');
        HelperDictionary.Add('Item Tracking', 'IT');
        HelperDictionary.Add('Journal', 'Jnl');
        HelperDictionary.Add('Language', 'Lang');
        HelperDictionary.Add('Ledger', 'Ledg');
        HelperDictionary.Add('Level', 'Lvl');
        HelperDictionary.Add('Line', 'Ln');
        HelperDictionary.Add('List', 'Lt');
        HelperDictionary.Add('Local Currency', 'LCY');
        HelperDictionary.Add('Location', 'Loc');
        HelperDictionary.Add('Mailing', 'Mail');
        HelperDictionary.Add('Maintenance', 'Maint');
        HelperDictionary.Add('Management', 'Mgt');
        HelperDictionary.Add('Manual', 'Man');
        HelperDictionary.Add('Manufacturing', 'Mfg');
        HelperDictionary.Add('Manufacturer', 'Mfr');
        HelperDictionary.Add('Material', 'Mat');
        HelperDictionary.Add('Marketing', 'Mktg');
        HelperDictionary.Add('Maximum', 'Max');
        HelperDictionary.Add('Measure', 'Meas');
        HelperDictionary.Add('Message', 'Msg');
        HelperDictionary.Add('Minimum', 'Min');
        HelperDictionary.Add('Miscellaneous', 'Misc');
        HelperDictionary.Add('Modify', 'Mod');
        HelperDictionary.Add('Month', 'Mth');
        HelperDictionary.Add('Negative', 'Neg');
        HelperDictionary.Add('Non-Inventoriable', 'NonInvtbl');
        HelperDictionary.Add('Notification', 'Notif');
        HelperDictionary.Add('Number', 'No');
        HelperDictionary.Add('Numbers', 'Nos');
        HelperDictionary.Add('Object', 'Obj');
        HelperDictionary.Add('Operating', 'Oper');
        HelperDictionary.Add('Opportunity', 'Opp');
        HelperDictionary.Add('Order', 'Ord');
        HelperDictionary.Add('Orders', 'Ords');
        HelperDictionary.Add('Original', 'Orig');
        HelperDictionary.Add('Organization', 'Org');
        HelperDictionary.Add('Outbound', 'Outbnd');
        HelperDictionary.Add('Outgoing', 'Outg');
        HelperDictionary.Add('Output', 'Out');
        HelperDictionary.Add('Outstanding', 'Outstd');
        HelperDictionary.Add('Overhead', 'Ovhd');
        HelperDictionary.Add('Payment', 'Pmt');
        HelperDictionary.Add('Percent', 'Pct');
        HelperDictionary.Add('Personnel', 'Persnl');
        HelperDictionary.Add('Physical', 'Phys');
        HelperDictionary.Add('Picture', 'Pic');
        HelperDictionary.Add('Planning', 'Plng');
        HelperDictionary.Add('Posted', 'Pstd');
        HelperDictionary.Add('Posting', 'Post');
        HelperDictionary.Add('Positive', 'Pos');
        HelperDictionary.Add('Precision', 'Prec');
        HelperDictionary.Add('Prepayment', 'Prepmt');
        HelperDictionary.Add('Product', 'Prod');
        HelperDictionary.Add('Production', 'Prod');
        HelperDictionary.Add('Production Order', 'ProdOrd');
        HelperDictionary.Add('Project', 'Proj');
        HelperDictionary.Add('Property', 'Prop');
        HelperDictionary.Add('Prospect', 'Prspct');
        HelperDictionary.Add('Purchase', 'Purch');
        HelperDictionary.Add('Purchases', 'Purch');
        HelperDictionary.Add('Purchaser', 'Purchr');
        HelperDictionary.Add('Purchase Order', 'PurchOrd');
        HelperDictionary.Add('Quality', 'Qlty');
        HelperDictionary.Add('Quantity', 'Qty');
        HelperDictionary.Add('Questionnaire', 'Questn');
        HelperDictionary.Add('Quote', 'Qte');
        HelperDictionary.Add('Radio Frequency', 'RF');
        HelperDictionary.Add('Range', 'Rng');
        HelperDictionary.Add('Receipt', 'Rcpt');
        HelperDictionary.Add('Received', 'Rcd');
        HelperDictionary.Add('Record', 'Rec');
        HelperDictionary.Add('Records', 'Recs');
        HelperDictionary.Add('Reconcile', 'Recncl');
        HelperDictionary.Add('Reconciliation', 'Recon');
        HelperDictionary.Add('Recurring', 'Recur');
        HelperDictionary.Add('Reference', 'Ref');
        HelperDictionary.Add('Register', 'Reg');
        HelperDictionary.Add('Registration', 'Regn');
        HelperDictionary.Add('Registered', 'Regd');
        HelperDictionary.Add('Relation', 'Rel');
        HelperDictionary.Add('Relations', 'Rels');
        HelperDictionary.Add('Relationship', 'Rlshp');
        HelperDictionary.Add('Release', 'Rlse');
        HelperDictionary.Add('Released', 'Rlsd');
        HelperDictionary.Add('Remaining', 'Rem');
        HelperDictionary.Add('Reminder', 'Rmdr');
        HelperDictionary.Add('Replacement', 'Repl');
        HelperDictionary.Add('Replenish', 'Rplnsh');
        HelperDictionary.Add('Replenishment', 'Rplnsht');
        HelperDictionary.Add('Report', 'Rpt');
        HelperDictionary.Add('Represent', 'Rep');
        HelperDictionary.Add('Represented', 'Repd');
        HelperDictionary.Add('Request', 'Rqst');
        HelperDictionary.Add('Required', 'Reqd');
        HelperDictionary.Add('Requirement', 'Reqt');
        HelperDictionary.Add('Requirements', 'Reqts');
        HelperDictionary.Add('Requisition', 'Req');
        HelperDictionary.Add('Reserve', 'Rsv');
        HelperDictionary.Add('Reserved', 'Rsvd');
        HelperDictionary.Add('Reservation', 'Reserv');
        HelperDictionary.Add('Resolution', 'Resol');
        HelperDictionary.Add('Resource', 'Res');
        HelperDictionary.Add('Response', 'Rsp');
        HelperDictionary.Add('Responsibility', 'Resp');
        HelperDictionary.Add('Retain', 'Rtn');
        HelperDictionary.Add('Retained', 'Rtnd');
        HelperDictionary.Add('Return', 'Ret');
        HelperDictionary.Add('Returns', 'Rets');
        HelperDictionary.Add('Revaluation', 'Revaln');
        HelperDictionary.Add('Reverse', 'Rev');
        HelperDictionary.Add('Review', 'Rvw');
        HelperDictionary.Add('Round', 'Rnd');
        HelperDictionary.Add('Rounded', 'Rndd');
        HelperDictionary.Add('Rounding', 'Rndg');
        HelperDictionary.Add('Route', 'Rte');
        HelperDictionary.Add('Routing', 'Rtng');
        HelperDictionary.Add('Routine', 'Rout');
        HelperDictionary.Add('Sales & Receivables', 'Sales');
        HelperDictionary.Add('Safety', 'Saf');
        HelperDictionary.Add('Schedule', 'Sched');
        HelperDictionary.Add('Second', 'Sec');
        HelperDictionary.Add('Segment', 'Seg');
        HelperDictionary.Add('Select', 'Sel');
        HelperDictionary.Add('Selection', 'Selctn');
        HelperDictionary.Add('Sequence', 'Seq');
        HelperDictionary.Add('Serial', 'Ser');
        HelperDictionary.Add('Serial Number', 'SN');
        HelperDictionary.Add('Service', 'Serv');
        HelperDictionary.Add('Sheet', 'Sh');
        HelperDictionary.Add('Shipment', 'Shpt');
        HelperDictionary.Add('Source', 'Src');
        HelperDictionary.Add('Special', 'Spcl');
        HelperDictionary.Add('Specification', 'Spec');
        HelperDictionary.Add('Specifications', 'Specs');
        HelperDictionary.Add('Standard', 'Std');
        HelperDictionary.Add('Frequency', 'SF');
        HelperDictionary.Add('Statement', 'Stmt');
        HelperDictionary.Add('Statistical', 'Stat');
        HelperDictionary.Add('Statistics', 'Stats');
        HelperDictionary.Add('Stock', 'Stk');
        HelperDictionary.Add('Stockkeeping Unit', 'SKU');
        HelperDictionary.Add('Stream', 'Stm');
        HelperDictionary.Add('Structured Query Language', 'SQL');
        HelperDictionary.Add('Subcontract', 'Subcontr');
        HelperDictionary.Add('Subcontracted', 'Subcontrd');
        HelperDictionary.Add('Subcontracting', 'Subcontrg');
        HelperDictionary.Add('Substitute', 'Sub');
        HelperDictionary.Add('Substitution', 'Subst');
        HelperDictionary.Add('Suggest', 'Sug');
        HelperDictionary.Add('Suggested', 'Sugd');
        HelperDictionary.Add('Suggestion', 'Sugn');
        HelperDictionary.Add('Summary', 'Sum');
        HelperDictionary.Add('Suspended', 'Suspd');
        HelperDictionary.Add('Symptom', 'Sympt');
        HelperDictionary.Add('Synchronize', 'Synch');
        HelperDictionary.Add('Temporary', 'Temp');
        HelperDictionary.Add('Total', 'Tot');
        HelperDictionary.Add('Transaction', 'Transac');
        HelperDictionary.Add('Transfer', 'Trans');
        HelperDictionary.Add('Translation', 'Transln');
        HelperDictionary.Add('Tracking', 'Trkg');
        HelperDictionary.Add('Troubleshoot', 'Tblsht');
        HelperDictionary.Add('Troubleshooting', 'Tblshtg');
        HelperDictionary.Add('Unit Of Measure', 'UOM');
        HelperDictionary.Add('Unit Test', 'UT');
        HelperDictionary.Add('Unrealized', 'Unreal');
        HelperDictionary.Add('Unreserved', 'Unrsvd');
        HelperDictionary.Add('Update', 'Upd');
        HelperDictionary.Add('Valuation', 'Valn');
        HelperDictionary.Add('Value', 'Val');
        HelperDictionary.Add('Value Added Tax', 'VAT');
        HelperDictionary.Add('Variance', 'Var');
        HelperDictionary.Add('Vendor', 'Vend');
        HelperDictionary.Add('Warehouse', 'Whse');
        HelperDictionary.Add('Web Shop', 'WS');
        HelperDictionary.Add('Worksheet', 'Wksh');
        HelperDictionary.Add('G/L', 'GL');
        HelperDictionary.Add('%', 'Pct');
        HelperDictionary.Add('3-Tier', 'Three-Tier');
        HelperDictionary.Add('Outlook Synch', 'Osynch');
        exit(HelperDictionary);
    end;
}
