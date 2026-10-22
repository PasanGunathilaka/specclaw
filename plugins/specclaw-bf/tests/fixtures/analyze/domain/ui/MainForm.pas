unit MainForm;

interface

uses
  SysUtils, Classes, Forms, Controls, StdCtrls, Menus;

type
  TMainForm = class(TForm)
    procedure OKButtonClick(Sender: TObject);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.OKButtonClick(Sender: TObject);
begin
  ShowMessage('OK clicked');
end;

end.
