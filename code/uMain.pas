unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, IdBaseComponent,
  IdComponent, IdTCPConnection, IdTCPClient, IdHTTP,
  IdExplicitTLSClientServerBase, IdMessageClient, IdSMTPBase,
  superobject, IdMultipartFormData, msxml, Gauges, Vcl.ExtCtrls,
  DynamicSkinForm, SkinData, System.IniFiles, Vcl.Mask, SkinBoxCtrls, SkinCtrls;

type
  TfMain = class(TForm)
    btnopen: TspSkinButton;
    Memo1: TspSkinMemo;
    btnclose: TspSkinButton;
    btnstart: TspSkinButton;
    Timer1: TTimer;
    Label1: TspSkinLabel;
    edtime: TspSkinEdit;
    Label2: TspSkinLabel;
    GroupSet: TspSkinGroupBox;
    Label3: TspSkinLabel;
    edkey: TspSkinEdit;
    Label4: TspSkinLabel;
    edURL: TspSkinEdit;
    vvvvcxcvcv: TspCompressedStoredSkin;
    spskndt1: TspSkinData;
    spdynmcsknfrm1: TspDynamicSkinForm;
    btnsave: TspSkinButton;
    procedure btncloseClick(Sender: TObject);
    procedure btnopenClick(Sender: TObject);
    procedure btnstartClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Timer1Timer(Sender: TObject);
    procedure btnsaveClick(Sender: TObject);
  private
    { Private declarations }
    isHookInstalled: Boolean;
    IniFile: TIniFile;

    function WriteInteger(sKey, sName: string; Value: Integer): Boolean;
    function WriteString(sKey, sName, Value: string): Boolean;
    function ReadInteger(sKey, sName: string; DefValue: Integer): Integer;
    function ReadString(sKey, sName: string; sDefVaule: string = ''): string;
  public
    { Public declarations }
  end;

  { DLL �еĺ������� }
function SetHook: Boolean; stdcall;
function DelHook: Boolean; stdcall;
function PrintHook: int64; stdcall;

var
  fMain: TfMain;

implementation

{$R *.dfm}
{ DLL �еĺ���ʵ��, Ҳ����˵����������, ԭ����ʲô�� }
function SetHook; external 'KeyboardHook.dll' name 'SetHook';
function DelHook; external 'KeyboardHook.dll' name 'DelHook';
function PrintHook; external 'KeyboardHook.dll' name 'PrintHook';

procedure TfMain.btnopenClick(Sender: TObject);
begin
  Self.btnopen.Enabled := False;
  Self.btnstart.Enabled := True;
  Self.btnclose.Enabled := True;

  if SetHook then
  begin
    isHookInstalled := True;
    Self.Memo1.Lines.Add('���̹����Ѱ�װ������');
  end;
end;

procedure TfMain.btncloseClick(Sender: TObject);
begin
  if DelHook then
  begin
    isHookInstalled := False;
    Self.Memo1.Lines.Add('���̹����ѳ���������');
    Self.Memo1.Lines.Add(' ');
  end;

  Self.btnopen.Enabled := True;
  Self.btnstart.Enabled := False;
  Self.btnclose.Enabled := False;
end;

procedure TfMain.btnsaveClick(Sender: TObject);
begin
  WriteString('System', 'key', edkey.Text);
  WriteString('System', 'url', edURL.Text);
  WriteInteger('System', 'time', strtoint(edtime.Text));

  Self.btnopen.Enabled := True;
end;

procedure TfMain.btnstartClick(Sender: TObject);
begin
  try
    Timer1.Interval := strtoint(edtime.Text) * 1000;
  except
    on E: Exception do
    begin
      showmessage('������ȷ��ֵ');
      exit;
    end;
  end;

  Timer1.Enabled := not Timer1.Enabled;
  Self.GroupSet.Enabled := not Timer1.Enabled;

  if Timer1.Enabled then
  begin
    Self.Memo1.Lines.Add('������ʱ��');
    btnstart.Caption := '�رն�ʱ��';
  end
  else
  begin
    Self.Memo1.Lines.Add('�رն�ʱ��');
    btnstart.Caption := '������ʱ��';
  end;
end;

procedure TfMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if isHookInstalled then
    DelHook;
end;

procedure TfMain.FormCreate(Sender: TObject);
var
  sIniFile: string;
begin
  sIniFile := ExtractFilePath(Application.ExeName) + 'cfg.ini';

  IniFile := TIniFile.Create(sIniFile);
  if FileExists(sIniFile) then
  begin
    edkey.Text := ReadString('System', 'key', '');
    edURL.Text := ReadString('System', 'url', '');
    edtime.Text := inttostr(ReadInteger('System', 'time', 60));

    Self.btnopen.Enabled := True;
  end
  else
  begin
    showmessage('�����ó���');
    Self.btnopen.Enabled := False;
  end;

  Self.btnstart.Enabled := False;
  Self.btnclose.Enabled := False;
  isHookInstalled := False;

  Self.Memo1.Color := clBlack;
  Self.Memo1.Font.Color := clGreen;
end;

function TfMain.ReadInteger(sKey, sName: string; DefValue: Integer): Integer;
begin
  Result := IniFile.ReadInteger(sKey, sName, DefValue);
end;

function TfMain.ReadString(sKey, sName, sDefVaule: string): string;
begin
  Result := IniFile.ReadString(sKey, sName, sDefVaule);
end;

procedure TfMain.Timer1Timer(Sender: TObject);
var
  cnx: IXMLHttpRequest;
  params: ISuperObject;
  clickcount: int64;
begin
  clickcount := PrintHook;

  cnx := CoXMLHTTP.Create;
  cnx.open('POST', edURL.Text, False, EmptyParam, EmptyParam);
  cnx.setRequestHeader('Content-Type', 'application/json-rpc');
  cnx.setRequestHeader('Accept', 'application/json-rpc');
  cnx.setRequestHeader('U-ApiKey', edkey.Text);

  params := SO('{"value":' + inttostr(clickcount) + '}');

  cnx.send(string(params.AsJson));

  if Memo1.Lines.Count > 1000 then
    Memo1.Lines.Delete(memo1.Lines.Count - 1);

  Self.Memo1.Lines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' �㱨���� ' +
    inttostr(clickcount));
end;

function TfMain.WriteInteger(sKey, sName: string; Value: Integer): Boolean;
begin
  Result := IniFile <> nil;
  if Result then
    IniFile.WriteInteger(sKey, sName, Value);
end;

function TfMain.WriteString(sKey, sName, Value: string): Boolean;
begin
  Result := IniFile <> nil;
  if Result then
    IniFile.WriteString(sKey, sName, Value);
end;

end.
