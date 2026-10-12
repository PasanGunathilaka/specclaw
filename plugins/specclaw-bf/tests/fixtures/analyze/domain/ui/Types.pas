unit Types;

interface

type
  TWaterQuality = (wqNone, wqChem, wqTrace, wqAge);

  TReading = record
    Value: Double;
    Timestamp: TDateTime;
  end;

const
  MaxReadings = 100;
  DefaultUnit = 'ppm';

implementation

function ValidateReading(Value: Double): Boolean;
begin
  if Value < 0 then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
end;

function ComputeAverage(Values: array of Double): Double;
var
  i: Integer;
  total: Double;
begin
  total := 0;
  for i := Low(Values) to High(Values) do
    total := total + Values[i];
  Result := total / Length(Values);
end;

function CanRedo(AItem: Integer): Boolean;
begin
  Result := False;
end;

procedure LogMessage(const Msg: string);
begin
  WriteLn(Msg);
end;

end.
