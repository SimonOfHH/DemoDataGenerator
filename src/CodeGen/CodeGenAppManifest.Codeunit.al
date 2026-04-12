namespace SimonOfHH.DemoData.CodeGen;

/// <summary>
/// In-memory AST node representing an app.json manifest file.
/// Generates the app.json for the generated AL extension.
/// </summary>
codeunit 70114 "CodeGen App Manifest"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        ManifestJson: JsonObject;
        Dependencies: JsonArray;
        AppId: Guid;
        AppName, AppPublisher, AppVersion, AppDescription, AppRuntime, AppPlatform, AppApplication : Text;
        RangeStart, RangeEnd : Integer;
        ContosoDemoDataAppIdTok: Label '5a0b41e9-7a42-4123-d521-2265186cfb31', Locked = true;

    local procedure BuildJsonObject()
    var
        IdRanges, Features, EmptyArray : JsonArray;
        IdRangeObject, ResourceExposurePolicy : JsonObject;
    begin
        this.EnsureDefaults();
        this.ManifestJson.Add('id', this.AppId.ToText().Replace('{', '').Replace('}', ''));
        this.ManifestJson.Add('name', this.AppName);
        this.ManifestJson.Add('publisher', this.AppPublisher);
        this.ManifestJson.Add('version', this.AppVersion);
        this.ManifestJson.Add('brief', this.AppDescription);
        this.ManifestJson.Add('description', this.AppDescription);
        this.ManifestJson.Add('privacyStatement', '');
        this.ManifestJson.Add('EULA', '');
        this.ManifestJson.Add('help', '');
        this.ManifestJson.Add('url', '');
        this.ManifestJson.Add('logo', '');
        this.ManifestJson.Add('dependencies', this.Dependencies);
        this.ManifestJson.Add('screenshots', EmptyArray);
        this.ManifestJson.Add('propagateDependencies', false);
        IdRangeObject.Add('from', this.RangeStart);
        IdRangeObject.Add('to', this.RangeEnd);
        IdRanges.Add(IdRangeObject);
        this.ManifestJson.Add('application', this.AppApplication);
        this.ManifestJson.Add('platform', this.AppPlatform);
        this.ManifestJson.Add('idRanges', IdRanges);
        Features.Add('TranslationFile');
        Features.Add('NoImplicitWith');
        this.ManifestJson.Add('features', Features);
        this.ManifestJson.Add('runtime', this.AppRuntime);
        this.ManifestJson.Add('target', 'Cloud');
        ResourceExposurePolicy.Add('allowDebugging', true);
        ResourceExposurePolicy.Add('allowDownloadingSource', true);
        ResourceExposurePolicy.Add('includeSourceInSymbolFile', true);
        this.ManifestJson.Add('resourceExposurePolicy', ResourceExposurePolicy);
    end;

    local procedure EnsureDefaults()
    begin
        if this.AppRuntime = '' then
            this.AppRuntime := '16.0';
        if this.AppPlatform = '' then
            this.AppPlatform := '27.0.0.0';
        if this.AppApplication = '' then
            this.AppApplication := '27.0.0.0';
    end;

    procedure Id(NewId: Guid)
    begin
        this.AppId := NewId;
    end;

    procedure Name(NewName: Text)
    begin
        this.AppName := NewName;
    end;

    procedure Publisher(NewPublisher: Text)
    begin
        this.AppPublisher := NewPublisher;
    end;

    procedure Version(NewVersion: Text)
    begin
        this.AppVersion := NewVersion;
    end;

    procedure Description(NewDescription: Text)
    begin
        this.AppDescription := NewDescription;
    end;

    procedure IdRange(NewRangeStart: Integer; NewRangeEnd: Integer)
    begin
        this.RangeStart := NewRangeStart;
        this.RangeEnd := NewRangeEnd;
    end;

    procedure Runtime(NewRuntime: Text)
    begin
        this.AppRuntime := NewRuntime;
    end;

    procedure Platform(NewPlatform: Text)
    begin
        this.AppPlatform := NewPlatform;
    end;

    procedure Application(NewApplication: Text)
    begin
        this.AppApplication := NewApplication;
    end;

    /// <summary>
    /// Add a dependency to the manifest.
    /// </summary>
    procedure AddDependency(DepId: Text; DepName: Text; DepPublisher: Text; DepVersion: Text)
    var
        Dependency: JsonObject;
    begin
        Dependency.Add('id', DepId);
        Dependency.Add('name', DepName);
        Dependency.Add('publisher', DepPublisher);
        Dependency.Add('version', DepVersion);
        this.Dependencies.Add(Dependency);
    end;

    /// <summary>
    /// Adds the default dependencies on Contoso Coffee Demo Dataset.
    /// </summary>
    procedure AddDefaultDependencies()
    begin
        this.AddDependency(this.ContosoDemoDataAppIdTok, 'Contoso Coffee Demo Dataset', 'Microsoft', '27.0.0.0');
    end;

    /// <summary>
    /// Serializes to a complete app.json file.
    /// </summary>
    procedure ToString(): Text
    var
        ManifestAsText: Text;
    begin
        this.BuildJsonObject();
        this.ManifestJson.WriteTo(ManifestAsText);

        exit(ManifestAsText);
    end;
}
