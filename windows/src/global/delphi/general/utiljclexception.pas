unit utiljclexception;

interface

uses
  System.Classes,
  System.SysUtils;

type
  TKeymanHandleException = class
  public
    procedure OnException(Sender: TObject; E: Exception);
  end;

procedure KeymanHandleException(E: Exception);
function KeymanHandleExceptionWrapper: TKeymanHandleException;

implementation

uses
  JclDebug,
  ExternalExceptionHandler,
  Vcl.Forms;

procedure KeymanHandleException(E: Exception);
var
  FExceptionMessageDetail : TStringList;
  i: Integer;

begin
  FExceptionMessageDetail := TStringList.Create;
  try
    FExceptionMessageDetail.Add('Timestamp=' + FormatDateTime('yyyy-mm-dd hh:nn', Now));
    FExceptionMessageDetail.Add('Exception=' + E.ClassName);
    FExceptionMessageDetail.Add('Address=' + Format('%p', [ExceptAddr]));
    FExceptionMessageDetail.Add('Message='+E.Message);
    FExceptionMessageDetail.Add('');

    // Log unhandled exception stack info to ExceptionLogMemo
    JclLastExceptStackListToStrings(FExceptionMessageDetail, True, True, True, False);
    for i := 0 to FExceptionMessageDetail.Count - 1 do
      if Copy(FExceptionMessageDetail[i], 1, 1) = '[' then
        FExceptionMessageDetail[i] := ':' + FExceptionMessageDetail[i];

    SendExceptionToExternalHandler(
      E,
      Application.Title,
      'Exception '+E.ClassName+' in '+ExtractFileName(ParamStr(0))+': '+E.Message,
      FExceptionMessageDetail);
  finally
    FExceptionMessageDetail.Free;
  end;
end;

{ TKeymanHandleException }

procedure TKeymanHandleException.OnException(Sender: TObject; E: Exception);
begin
  KeymanHandleException(E);
end;

var
  FKeymanHandleException: TKeymanHandleException = nil;

function KeymanHandleExceptionWrapper: TKeymanHandleException;
begin
  if not Assigned(FKeymanHandleException) then
    FKeymanHandleException := TKeymanHandleException.Create;
  Result := FKeymanHandleException;
end;

initialization
  // Enable raw mode (default mode uses stack frames which aren't always generated by the compiler)
  Include(JclStackTrackingOptions, stRawMode);
  // Disable stack tracking in dynamically loaded modules (it makes stack tracking code a bit faster)
  Include(JclStackTrackingOptions, stStaticModuleList);

  // Initialize Exception tracking
  JclStartExceptionTracking;

  Application.OnException := KeymanHandleExceptionWrapper.OnException;

finalization
  // Uninitialize Exception tracking
  JclStopExceptionTracking;
end.