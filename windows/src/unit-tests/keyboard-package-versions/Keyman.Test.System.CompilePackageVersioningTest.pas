unit Keyman.Test.System.CompilePackageVersioningTest;

interface

uses
  DUnitX.TestFramework,
  ProjectLog;

type

  [TestFixture]
  TCompilePackageVersioningTest = class(TObject)
  private
    FRoot: string;
    procedure PackageMessage(Sender: TObject; msg: string;
      State: TProjectLogState);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    // Sample Methods
    // Simple single Test
    // Test with TestCase Attribute to supply parameters.
    [Test]
    [TestCase('test-single-version-1-package', 'test1.kps,False')]
    [TestCase('test-single-version-2-package', 'test2.kps,False')]
    [TestCase('test-version-2-1-mismatch', 'test2-1.kps,True')]
    [TestCase('test-version-1-2-mismatch', 'test1-2.kps,True')]
    [TestCase('test-keyboard-1-package-2', 'test-keyboard-1-vs-package-2.kps,False')]
    [TestCase('test-package-1-keyboard-2', 'test-package-1-vs-keyboard-2.kps,False')]
    procedure TestPackageCompile(Path: string; ExpectError: Boolean);
  end;

implementation

uses
  System.SysUtils,
  compile,
  CompilePackage,
  kmnProjectFile,
  ProjectFile,
  kpsfile;

type
  TProjectConsole = class(TProject)
  private
    FSilent: Boolean;
    FFullySilent: Boolean;
  public
    procedure Log(AState: TProjectLogState; Filename: string; Msg: string); override;   // I4706
    function Save: Boolean; override;   // I4709

    property Silent: Boolean read FSilent write FSilent;
    property FullySilent: Boolean read FFullySilent write FFullySilent;
  end;

procedure TCompilePackageVersioningTest.Setup;
var
  p: TProjectConsole;
  i: Integer;
begin
  FRoot := ExtractFileDir(ExtractFileDir(ExtractFileDir(ParamStr(0))));

  //
  // Force load development version of kmcmpdll
  // Assumes it has already been built, of course...
  //
  FUnitTestKMCmpDllPath := FRoot + '\..\..\developer\kmcmpdll\';

  p := TProjectConsole.Create(FRoot+'\test-1.0\test-1.0.kpj', False);
  try
    for i := 0 to p.Files.Count - 1 do
      if p.Files[i] is TkmnProjectFile then
        Assert.IsTrue((p.Files[i] as TkmnProjectFile).CompileKeyboard, 'Could not compile keyboard');
  finally
    p.Free;
  end;

  p := TProjectConsole.Create(FRoot+'\test-2.0\test-2.0.kpj', False);
  try
    for i := 0 to p.Files.Count - 1 do
      if p.Files[i] is TkmnProjectFile then
        Assert.IsTrue((p.Files[i] as TkmnProjectFile).CompileKeyboard, 'Could not compile keyboard');
  finally
    p.Free;
  end;
end;

procedure TCompilePackageVersioningTest.TearDown;
begin
end;

procedure TCompilePackageVersioningTest.PackageMessage(Sender: TObject; msg: string; State: TProjectLogState);
const
  Map: array[TProjectLogState] of TLogLevel = (TLogLevel.Information, TLogLevel.Warning, TLogLevel.Error, TLogLevel.Error);
begin
  Log(Map[State], msg);
end;

procedure TCompilePackageVersioningTest.TestPackageCompile(Path: string; ExpectError: Boolean);
var
  pack: TKPSFile;
  res: Boolean;
begin
  pack := TKPSFile.Create;
  try
    pack.FileName := FRoot+'\'+Path;
    pack.LoadXML;
    res := DoCompilePackage(pack, PackageMessage, False, FRoot+'\'+ChangeFileExt(Path,'.kmp'));
    Assert.AreEqual(not ExpectError, res);
  finally
    pack.Free;
  end;
end;

procedure TProjectConsole.Log(AState: TProjectLogState; Filename, Msg: string);   // I4706
begin
{$IFDEF DEBUG_PROJECT}
  case AState of
    plsInfo:
      if not FSilent then
        writeln(ExtractFileName(Filename)+': '+Msg);
    plsWarning:
      if not FFullySilent then
        writeln(ExtractFileName(Filename)+': Warning: '+Msg);
    plsError:
      if not FFullySilent then
        writeln(ExtractFileName(Filename)+': Error: '+Msg);
    plsFatal:
      writeln(ExtractFileName(Filename)+': Fatal error: '+Msg);
  end;
{$ENDIF}
end;

function TProjectConsole.Save: Boolean;   // I4709
begin
  // We don't modify the project file in the console
  Result := True;
end;

initialization
  TDUnitX.RegisterTestFixture(TCompilePackageVersioningTest);
end.
