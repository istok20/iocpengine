unit msgtest;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Contnrs, DnMsgClient, DnMsgServer, DnRtl, ExtCtrls, SyncObjs;

type
  TFrmTest = class(TForm)
    BtServer: TButton;
    BtClient: TButton;
    MmLog: TMemo;
    TmrSend: TTimer;
    TmrLog: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure BtServerClick(Sender: TObject);
    procedure BtClientClick(Sender: TObject);
    procedure TmrSendTimer(Sender: TObject);
    procedure TmrLogTimer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

  private
    FServer: TCommonMsgServer;
    FClient: TCommonMsgClient;
    FLog: TStringList;
    FLogGuard: TCriticalSection;

    procedure LogServer(const S: string);
    procedure LogClient(const S: string);

    // Server handlers
    procedure Server_ClientConnected(Sender: TObject; ClientRec: TClientRec);
    procedure Server_ClientAuthentication(Sender: TObject; ClientRec: TClientRec; var Authenticated: boolean);
    procedure Server_DataReceived(Sender: TObject; ClientRec: TClientRec; Stream: TStream);
    procedure Server_ClientDisconnectedEvent(Sender: TObject; ClientRec: TClientRec);
    procedure Server_Error(Sender: TObject; Client: TClientRec; ErrorMessage: string);
    procedure Server_StreamSent(Sender: TObject; Client: TClientRec; Stream: TStream);

    // Client handlers
    procedure Client_Connected(Sender: TObject);
    procedure Client_Disconnected(Sender: TObject);
    procedure Client_Error(Sender: TObject; ErrorMessage: ansistring);
    procedure Client_DataReceived(Sender: TObject; Stream: TStream);
    procedure Client_StreamSent(Sender: TObject; Stream: TStream);
    procedure Client_AuthResult(Sender: TObject; Res: boolean; const Msg: RawByteString);
    procedure Client_ListOfClients(Sender: TObject; ClientList: TObjectList);

  public
  end;

var
  FrmTest: TFrmTest;

implementation

{$R *.dfm}

function GetStringFromStream(aStream: TStream):ansistring;
begin
  if (aStream.Size > 0) then
  begin
    aStream.Position := 0;
    SetLength(result, aStream.Size);
    aStream.Read(result[1], aStream.Size);
  end else
    result := '';
end;

procedure TFrmTest.FormCreate(Sender: TObject);
begin
  FLog := TStringList.Create();
  FLogGuard := TCriticalSection.Create();

  FClient := TCommonMsgClient.Create(nil);
  FServer := TCommonMsgServer.Create(nil);
  FClient.HeartbeatInterval := 20;
  FClient.Handshake := false; // Do Authentification
  FClient.Host := '127.0.0.1';
  //FClient.Host := '127.0.0.1';
  FClient.Port := 80;
  FClient.OnConnected := Self.Client_Connected;
  FClient.OnDisconnected := Self.Client_Disconnected;
  FClient.OnStreamSent := Self.Client_StreamSent;
  FClient.OnError := Self.Client_Error;
  FClient.OnDataReceived := Self.Client_DataReceived;
  FClient.OnStreamSent := Self.Client_StreamSent;
  FClient.OnAuthResult := Self.Client_AuthResult;
  FClient.OnClientList := Self.Client_ListOfClients;
  FClient.MarshallWindow := Self.Handle;

  FServer.Port := 80;
  FServer.OnClientConnected := Self.Server_ClientConnected;
  FServer.OnClientDisconnected := Self.Server_ClientDisconnectedEvent;
  FServer.OnClientAuthentication := Self.Server_ClientAuthentication;
  FServer.OnDataReceived := Self.Server_DataReceived;
  FServer.OnError := Self.Server_Error;
  FServer.OnStreamSent := Self.Server_StreamSent;

  TmrLog.Enabled := true;
end;

procedure TFrmTest.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FClient);
  FreeAndNil(FServer);
  FreeAndNil(FLog);
  FreeAndNil(FLogGuard);
end;

procedure TFrmTest.LogServer(const S: string);
var
  Msg: string;
begin
  Msg := 'Server: ' + S;
  FLogGuard.Enter;
  try
    FLog.Add(Msg);
  finally
    FLogGuard.Leave;
  end;
  //OutputDebugString(PWideChar(Msg));
end;

procedure TFrmTest.LogClient(const S: string);
var
  Msg: string;
begin
  Msg := 'Client: ' + S;
  FLogGuard.Enter;
  try
    FLog.Add(Msg);
  finally
    FLogGuard.Leave;
  end;
  //OutputDebugString(PWideChar(Msg));
end;

procedure TFrmTest.Server_ClientConnected(Sender: TObject; ClientRec: TClientRec);
begin
  LogServer('client connected');
  //FServer.SendString('', ClientRec);
end;

procedure TFrmTest.Server_ClientAuthentication(Sender: TObject; ClientRec: TClientRec; var Authenticated: boolean);
var
  Request: ansistring;
begin
  LogServer('client authenticated');
  Authenticated := true;
  SetLength(Request, 2048);
  FillChar(Request[1], 2048, 123);
  FServer.SendString(Request, ClientRec);
  //FServer.SendString('test', ClientRec);
end;

procedure TFrmTest.Server_DataReceived(Sender: TObject; ClientRec: TClientRec; Stream: TStream);
var
  zStr: ansistring;
begin
  LogServer('received ' + GetStringFromStream(Stream));
  Stream.Position := 0;
  LogServer('send ' + '(TTTTTTTTTTTTT)');
  FServer.SendString('(TTTTTTTTTTTTT)', ClientRec);
  zStr := '';
end;

procedure TFrmTest.Server_ClientDisconnectedEvent(Sender: TObject; ClientRec: TClientRec);
begin
  LogServer('client disconnected');
end;

procedure TFrmTest.Server_Error(Sender: TObject; Client: TClientRec; ErrorMessage: string);
begin
  LogServer('error ' + ErrorMessage);
end;

procedure TFrmTest.Server_StreamSent(Sender: TObject; Client: TClientRec; Stream: TStream);
begin
  LogServer('sent ' + GetStringFromStream(Stream));
end;

procedure TFrmTest.TmrLogTimer(Sender: TObject);
//var
//  i: integer;
begin
  FLogGuard.Enter;
  try
    MmLog.Lines.AddStrings(FLog);
    FLog.Clear;
    (*if MmLog.Lines.Count > 200 then
    for i:=0 to 99 do
      MmLog.Lines.Delete(0);*)
  finally
    FLogGuard.Leave;
  end;

  if Assigned(FClient) then
  begin
    if FClient.MarshallWindow <> 0 then
      FClient.ProcessEvents;

    if FClient.Active then
      BtClient.Caption := 'Stop client'
    else
      BtClient.Caption := 'Start client';
  end;
end;

procedure TFrmTest.TmrSendTimer(Sender: TObject);
begin
  if FClient.Active then
  begin
    LogClient('Send ' + '(TESTESTESTESTESTEST)');
    FClient.SendString('(TESTESTESTESTESTEST)');
  end;
end;

procedure TFrmTest.Client_Connected(Sender: TObject);
begin
  LogClient('client connected to server');
end;

procedure TFrmTest.Client_Disconnected(Sender: TObject);
begin
  LogClient('client disconnected from server');
  //FClient.Connect;  auto reconnect
end;

procedure TFrmTest.Client_Error(Sender: TObject; ErrorMessage: ansistring);
begin
  LogClient('client error ' + string(ErrorMessage));
end;

procedure TFrmTest.Client_DataReceived(Sender: TObject; Stream: TStream);
begin
  LogClient('Received: ' + GetStringFromStream(Stream));
end;

procedure TFrmTest.Client_StreamSent(Sender: TObject; Stream: TStream);
begin
  LogClient('sent ' + GetStringFromStream(Stream));
end;

procedure TFrmTest.BtClientClick(Sender: TObject);
begin
  if FClient.Active then
  begin
    TmrSend.Enabled := false;
    FClient.Active := false;
    BtClient.Caption := 'Start client';
  end
  else
  begin
    FClient.Active := true;
    TmrSend.Enabled := true;
    BtClient.Caption := 'Stop client';
  end;
end;

procedure TFrmTest.BtServerClick(Sender: TObject);
begin
  if FServer.Active then
  begin
    FServer.DisconnectAll;
    Sleep(500);
    FServer.Active := false;
    BtServer.Caption := 'Start server';
  end
  else
  begin
    FServer.Active := true;
    BtServer.Caption := 'Stop server';
  end;
end;

procedure TFrmTest.Client_AuthResult(Sender: TObject; Res: boolean; const Msg: RawByteString);
begin
  ;
end;

procedure TFrmTest.Client_ListOfClients(Sender: TObject; ClientList: TObjectList);
begin
  ;
end;

end.

