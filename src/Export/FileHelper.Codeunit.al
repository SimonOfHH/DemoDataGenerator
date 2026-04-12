namespace SimonOfHH.DemoData.Export;

using System.Utilities;

/// <summary>
/// Utility for downloading single files from the browser.
/// </summary>
codeunit 70132 "File Helper"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    /// <summary>
    /// Downloads a text file to the client.
    /// </summary>
    procedure DownloadText(FileName: Text; Content: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        InStream: InStream;
    begin
        TempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(Content);
        TempBlob.CreateInStream(InStream);
        DownloadFromStream(InStream, 'Download File', '', 'All Files (*.*)|*.*', FileName);
    end;

    /// <summary>
    /// Downloads a blob file to the client.
    /// </summary>
    procedure DownloadBlob(FileName: Text; var TempBlob: Codeunit "Temp Blob")
    var
        InStream: InStream;
    begin
        TempBlob.CreateInStream(InStream);
        DownloadFromStream(InStream, 'Download File', '', 'All Files (*.*)|*.*', FileName);
    end;
}
