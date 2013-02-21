unit JsonRpcClient;

interface

{http://groups.google.com/group/json-rpc/web/json-rpc-over-http}

uses
  SysUtils, Classes, Contnrs, XmlRpcTypes, XmlRpcCommon,
  IdHTTP,
  IdSSLOpenSSL,
  IdHashMessageDigest,
  IdHash,
  IdCookieManager,
  JCLZlib,
  superobject;

type
  IJsonRpcFunction = interface(IInterface)
  ['{EAAAF3D9-F747-4B85-BB67-692529D5DB27}']
    function GetMethod: string;
    procedure SetMethod(const Value: string);
    function GetParams: ISuperObject;
    procedure SetParams(const Value: ISuperObject);
    function GetRequestJson: string;
    property Method: string read GetMethod write SetMethod;
    property Params: ISuperObject read GetParams write SetParams;
    property RequestJson: string read GetRequestJson;

    procedure Clear;
  end;

  IJsonRpcResult = interface(IInterface)
  ['{5F318081-AEB6-4588-A1B6-FF2D8910E3CC}']
    function GetErrorCode: Integer;
    function GetErrorMsg: string;
    function GetResponseJsonData: ISuperObject;
    procedure SetResponseJsonData(const Value: ISuperObject);

    procedure SetError(Code: Integer; const Msg: string);
    function IsError: Boolean;

    property ErrorCode: Integer read GetErrorCode;
    property ErrorMsg: string read GetErrorMsg;
    property ResponseJsonData: ISuperObject read GetResponseJsonData write SetResponseJsonData;
  end;

  TJsonCaller = class(TObject)
  private
    FHostName: string;
    FHostPort: Integer;
    FProxyName: string;
    FProxyPort: Integer;
    FProxyUserName: string;
    FProxyPassword: string;
    FCompress: Boolean;
    FIdCookieManager: TIdCookieManager;
    FSSLEnable: Boolean;
    FSSLRootCertFile: string;
    FSSLCertFile: string;
    FSSLKeyFile: string;
    FEndPoint: string;
    FProxyBasicAuth: Boolean;
    function Post(const RawData: string; var ResponseCode: Integer; var ResponseText: string): string;
    function Parse(const ResponseData: string): ISuperObject;
    procedure OnError(Sender: Pointer; Error: TSuperValidateError; const Path: string);
  public
    constructor Create;
    property EndPoint: string read FEndPoint write FEndPoint;
    property HostName: string read FHostName write FHostName;
    property HostPort: Integer read FHostPort write FHostPort;
    property ProxyName: string read FProxyName write FProxyName;
    property ProxyPort: Integer read FProxyPort write FProxyPort;
    property ProxyUserName: string read FProxyUserName write FProxyUserName;
    property ProxyPassword: string read FProxyPassword write FProxyPassword;
    property ProxyBasicAuth: Boolean read FProxyBasicAuth write FProxyBasicAuth;
    property Compress: Boolean read FCompress write FCompress;
    property IdCookieManager: TIdCookieManager read FIdCookieManager write FIdCookieManager;
    property SSLEnable: Boolean read FSSLEnable write FSSLEnable;
    property SSLRootCertFile: string read FSSLRootCertFile write FSSLRootCertFile;
    property SSLCertFile: string read FSSLCertFile write FSSLCertFile;
    property SSLKeyFile: string read FSSLKeyFile write FSSLKeyFile;
    function Execute(JsonRpcFunction: IJsonRpcFunction; Ttl: Integer = -1): IJsonRpcResult; overload;
    procedure DeleteOldCache(Ttl: Integer);
  end;

  TJsonRpcFunction = class(TInterfacedObject, IJsonRpcFunction)
  private
    FMethod: String;
    FParams: ISuperObject;
  protected
    function GetMethod: string;
    procedure SetMethod(const Value: string);
    function GetParams: ISuperObject;
    procedure SetParams(const Value: ISuperObject);
    function GetRequestJson: string;
  public
    property Method: string read GetMethod write SetMethod;
    property Params: ISuperObject read GetParams write SetParams;
    property RequestJson: string read GetRequestJson;

    procedure Clear;
  end;

  TJsonRpcResult = class(TInterfacedObject, IJsonRpcResult)
  private
    FErrorCode: Integer;
    FErrorMsg: string;
    FResponseJsonData: ISuperObject;
  protected
    function GetErrorCode: Integer;
    function GetErrorMsg: string;
    function GetResponseJsonData: ISuperObject;
    procedure SetResponseJsonData(const Value: ISuperObject);
  public
    procedure SetError(Code: Integer; const Msg: string);
    function IsError: Boolean;

    property ErrorCode: Integer read GetErrorCode;
    property ErrorMsg: string read GetErrorMsg;
    property ResponseJsonData: ISuperObject read GetResponseJsonData write SetResponseJsonData;

    constructor Create;
  end;

  EJsonRpcError = class(Exception)
  end;

const
  ERROR_RESULT_200 = 200;
  ERROR_RESULT_200_MESSAGE = 'Success Response.';
  ERROR_RESULT_204 = 204;
  ERROR_RESULT_204_MESSAGE = 'Success Response(V1.2).';
  ERROR_RESULT_500 = 500;
  ERROR_RESULT_500_MESSAGE = 'Parse error.';
  ERROR_RESULT_400 = 400;
  ERROR_RESULT_400_MESSAGE = 'Invalid Request.';
  ERROR_RESULT_404 = 404;
  ERROR_RESULT_404_MESSAGE = 'Method not found.';

implementation

{ TJsonRpcClient }

constructor TJsonCaller.Create;
begin
  inherited Create;
  FHostPort := 80;
  FSSLEnable := False;
  FProxyBasicAuth := False;
end;

procedure TJsonCaller.DeleteOldCache(Ttl: Integer);
var
  SearchRec: TSearchRec;
begin
  if FindFirst(GetTempDir + '*.csh', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Attr and faDirectory = 0) then
        if FileIsExpired(GetTempDir + SearchRec.Name, Ttl) then
          DeleteFile(GetTempDir + SearchRec.Name);
    until FindNext(SearchRec) <> 0;
    FindClose(SearchRec);
  end;
end;

function TJsonCaller.Execute(JsonRpcFunction: IJsonRpcFunction; Ttl: Integer = -1): IJsonRpcResult;
var
  Strings: TStrings;
  ResponseJsonData: string;
  RequestJsonData: string;
  Hash: string;
  HashMessageDigest: TIdHashMessageDigest5;

  ResponseCode: Integer;
  ResponseText: string;
begin
  RequestJsonData := JsonRpcFunction.RequestJson;
  HashMessageDigest := TIdHashMessageDigest5.Create;
  try
    { determine the md5 digest hash of the request }
    Hash := Hash128AsHex(HashMessageDigest.HashValue(RequestJsonData));
  finally
    HashMessageDigest.Free;
  end;
  Strings := TStringList.Create;
  Result := TJsonRpcResult.Create;
  try
    { if we have a cached file from a previous request
      that has not expired then load it }
    if (Ttl > 0) and FileExists(GetTempDir + Hash + '.csh')
      and (not FileIsExpired(GetTempDir + Hash + '.csh', Ttl)) then
    begin
      Strings.LoadFromFile(GetTempDir + Hash + '.csh');
      Result.ResponseJsonData := Parse(Strings.Text);
    end
    else begin
      { ok we got here so we where expired or did not exist
        make the call and cache the result this time }
      ResponseJsonData := Post(RequestJsonData, ResponseCode, ResponseText);
      Result.ResponseJsonData := Parse(ResponseJsonData);
      Result.SetError(ResponseCode, ResponseText);

      { save XmlResult in to the cache }
      Strings.Text := ResponseJsonData;
      Strings.SaveToFile(GetTempDir + Hash + '.csh');
    end;
  finally
    Strings.Free;
  end;
  JsonRpcFunction.Clear;
end;

procedure TJsonCaller.OnError(Sender: Pointer;
  Error: TSuperValidateError; const Path: string);
const
  Errors: array[TSuperValidateError] of string =
   ('RuleMalformated',
    'FieldIsRequired',
    'InvalidDataType',
    'FieldNotFound',
    'UnexpectedField',
    'DuplicateEntry',
    'ValueNotInEnum',
    'InvalidLengthRule',
    'InvalidRange');
begin
  //writeln(errors[error], ' -> ', path)
end;

function TJsonCaller.Parse(const ResponseData: string): ISuperObject;
var
  JsonObject: ISuperObject;
  r, f: string;
begin
  JsonObject := TSuperObject.Parse(PChar(ResponseData));
 { TODO -oNHSoft.YHW : How to Validate ResponseStream }
//  if not JsonObject.Validate(r, f, @OnError) then
//  begin
//    raise EJsonRpcError.Create('Json Parse Error');
//  end;
  Result := JsonObject;
end;

function TJsonCaller.Post(const RawData: string; var ResponseCode: Integer; var ResponseText: string): string;
var
  SendStream: TStream;
  ResponseStream: TStream;
  Session: TIdHttp;
  IdSSLIOHandlerSocket: TIdSSLIOHandlerSocket;
  gzipWriter: TJclGZipWriter;
  gzipReader: TJclGZipReader;
  dataStream: TStream;
  buf: PByte;
  count: Integer;
begin
  SendStream := nil;
  ResponseStream := nil;
  IdSSLIOHandlerSocket := nil;
  try
    SendStream := TMemoryStream.Create;
    ResponseStream := TMemoryStream.Create;

    if (FCompress) then
    begin
      gzipWriter := TJclGZipWriter.Create(SendStream, 1024);
      dataStream := TMemoryStream.Create;
      StringToStream(RawData, dataStream); { convert to a stream }
      dataStream.Seek(0, soFromBeginning);
      GetMem(buf, 1024);
      count := dataStream.Read(buf^, 1024);
      while (count > 0 ) do
      begin
        gzipWriter.Write(buf^, count);
        count := dataStream.Read(buf^, 1024)
      end;
      FreeMem(buf);
      dataStream.Free;
      gzipWriter.Free;
    end
    else begin
      StringToStream(RawData, SendStream); { convert to a stream }
    end;

    SendStream.Position := 0;
    Session := TIdHttp.Create(nil);
    try
      IdSSLIOHandlerSocket := nil;
      if (FSSLEnable) then
      begin
        IdSSLIOHandlerSocket := TIdSSLIOHandlerSocket.Create(nil);
        IdSSLIOHandlerSocket.SSLOptions.RootCertFile := FSSLRootCertFile;
        IdSSLIOHandlerSocket.SSLOptions.Method := sslvTLSv1;
        IdSSLIOHandlerSocket.SSLOptions.Mode := sslmClient;
        IdSSLIOHandlerSocket.SSLOptions.VerifyDepth := 1;
        //IdSSLIOHandlerSocket.SSLOptions.VerifyMode := [sslvrfFailIfNoPeerCert];
        IdSSLIOHandlerSocket.SSLOptions.CertFile := FSSLCertFile;
        IdSSLIOHandlerSocket.SSLOptions.KeyFile := FSSLKeyFile;
        Session.IOHandler := IdSSLIOHandlerSocket;
      end;

      { proxy setup }
      if (FProxyName <> '') then
      begin
        {proxy basic auth}
        if (FProxyBasicAuth) then
          Session.ProxyParams.BasicAuthentication := True;

        Session.ProxyParams.ProxyServer := FProxyName;
        Session.ProxyParams.ProxyPort := FProxyPort;
        Session.ProxyParams.ProxyUserName := FProxyUserName;
        Session.ProxyParams.ProxyPassword := FProxyPassword;
      end;

      { CookieManager Setup }
      if (FIdCookieManager <> nil) then
      begin
        Session.CookieManager := FIdCookieManager;
      end;

      Session.Request.Accept := 'application/json-rpc';
      Session.Request.ContentType := 'application/json-rpc';
      Session.Request.Connection := 'Keep-Alive';
      Session.Request.ContentLength := Length(RawData);

      if (FCompress) then
      begin
        Session.Request.AcceptEncoding  := 'gzip';
        Session.Request.ContentEncoding := 'gzip';
      end;

      if not FSSLEnable then
        if FHostPort = 80 then
          Session.Post('http://' + FHostName + FEndPoint, SendStream,
            ResponseStream)
        else
          Session.Post('http://' + FHostName + ':' + IntToStr(FHostPort) +
            FEndPoint, SendStream, ResponseStream);

      if FSSLEnable then
        Session.Post('https://' + FHostName + ':' + IntToStr(FHostPort) +
          FEndPoint, SendStream, ResponseStream);

      if (Session.Response.ContentEncoding = 'gzip') then
      begin
        GetMem(buf,1024);
        ResponseStream.Seek(0, soFromBeginning);
        dataStream := TMemoryStream.Create;
        gzipReader := TJclGZipReader.Create(ResponseStream);
        //while (not gzipReader.EndOfStream) do
        repeat
          count := gzipReader.Read(buf^, 1024);
          dataStream.Write(buf^, count);
        until (count = 0);
        gzipReader.Free;
        FreeMem(buf);
        result := StreamToString(dataStream);
        dataStream.Free;
      end
      else begin
        Result := StreamToString(ResponseStream);
      end;
      ResponseCode := Session.ResponseCode;
      ResponseText := Session.ResponseText;
    finally
      Session.Free;
    end;
  finally
    IdSSLIOHandlerSocket.Free;
    ResponseStream.Free;
    SendStream.Free;
  end;
end;

{ TJsonRpcFunction }

procedure TJsonRpcFunction.Clear;
begin
  FParams := nil;
end;

function TJsonRpcFunction.GetMethod: string;
begin
  Result := FMethod;
end;

function TJsonRpcFunction.GetParams: ISuperObject;
begin
  Result := FParams;
end;

function TJsonRpcFunction.GetRequestJson: string;
var
  RequestParams: ISuperObject;
begin
  RequestParams := SO();
  //RequestParams.S['jsonrpc'] := '2.0';
  RequestParams.S['method'] := FMethod;
  RequestParams.O['params'] := FParams;
  { TODO -oNHSoft.YHW : How to Generate Request Id; it is required running mutli-thread }
  RequestParams.I['id'] := 1;
  Result := RequestParams.AsJSon();
end;

procedure TJsonRpcFunction.SetMethod(const Value: string);
begin
  FMethod := Value;
end;

procedure TJsonRpcFunction.SetParams(const Value: ISuperObject);
begin
  FParams := Value;
end;

constructor TJsonRpcResult.Create;
begin
  inherited;
  SetError(ERROR_RESULT_200, ERROR_RESULT_200_MESSAGE);
end;

{ TJsonRpcResult }

function TJsonRpcResult.GetErrorCode: Integer;
begin
  Result := FErrorCode;
end;

function TJsonRpcResult.GetErrorMsg: string;
begin
  Result := FErrorMsg;
end;

function TJsonRpcResult.GetResponseJsonData: ISuperObject;
begin
  Result := FResponseJsonData;
end;

function TJsonRpcResult.IsError: Boolean;
begin
  Result := (FErrorCode = 500) or (FErrorCode = 400) or (FErrorCode = 404);
end;

procedure TJsonRpcResult.SetError(Code: Integer; const Msg: string);
begin
  FErrorCode := Code;
  FErrorMsg := Msg;
end;

procedure TJsonRpcResult.SetResponseJsonData(const Value: ISuperObject);
begin
  if FResponseJsonData <> nil then
  begin
    FResponseJsonData := nil;
  end;
  FResponseJsonData := Value;
end;

end.
