namespace SimonOfHH.DemoData.Export;

using System.IO;
using System.Utilities;

/// <summary>
/// Wrapper around BC's Data Compression codeunit for building zip archives.
/// Used to package the generated AL extension into a downloadable zip file.
/// </summary>
codeunit 70131 "Zip Helper"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        DataCompression: Codeunit "Data Compression";
        IsOpen: Boolean;

    /// <summary>
    /// Initializes a new zip archive.
    /// </summary>
    procedure Initialize()
    begin
        this.DataCompression.CreateZipArchive();
        this.IsOpen := true;
    end;

    /// <summary>
    /// Adds a text file to the zip archive.
    /// </summary>
    /// <param name="RelativePath">The path within the zip, e.g., "src/Helpers/ContosoBank.Codeunit.al"</param>
    /// <param name="TextContent">The UTF-8 text content</param>
    procedure AddTextFile(RelativePath: Text; TextContent: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        InStream: InStream;
    begin
        if not this.IsOpen then
            this.Initialize();

        TempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(TextContent);
        TempBlob.CreateInStream(InStream);
        this.DataCompression.AddEntry(InStream, RelativePath);
    end;

    /// <summary>
    /// Adds a binary file to the zip archive from a TempBlob.
    /// </summary>
    procedure AddBlobFile(RelativePath: Text; var TempBlob: Codeunit "Temp Blob")
    var
        InStream: InStream;
    begin
        if not this.IsOpen then
            this.Initialize();

        TempBlob.CreateInStream(InStream);
        this.DataCompression.AddEntry(InStream, RelativePath);
    end;

    /// <summary>
    /// Finalizes the archive and triggers a browser download.
    /// </summary>
    procedure Download(FileName: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        InStream: InStream;
    begin
        if not this.IsOpen then
            exit;

        TempBlob.CreateOutStream(OutStream);
        this.DataCompression.SaveZipArchive(OutStream);
        this.DataCompression.CloseZipArchive();
        this.IsOpen := false;

        TempBlob.CreateInStream(InStream);
        DownloadFromStream(InStream, 'Download Generated Extension', '', 'Zip Files (*.zip)|*.zip', FileName);
    end;
}
