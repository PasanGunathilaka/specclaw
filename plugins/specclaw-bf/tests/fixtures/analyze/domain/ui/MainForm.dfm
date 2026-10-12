object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Main Form'
  ClientHeight = 300
  ClientWidth = 400
  object OKButton: TButton
    Left = 8
    Top = 8
    Width = 75
    Height = 25
    Caption = 'OK'
    Glyph.Data = {04494D4200000000015C0000015C00000000000000000000}
    OnClick = OKButtonClick
  end
  object MainMenu1: TMainMenu
    Left = 200
    Top = 8
    object FileMenu: TMenuItem
      Caption = 'File'
      object RecentFilesItem: TMenuItem
        Caption = 'Recent Files'
        OnClick = RecentFileClick
      end
    end
  end
end
