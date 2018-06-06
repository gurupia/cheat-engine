unit frmChangedAddressesCommonalityScannerUnit;

{$mode delphi}

interface

uses
  windows, Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  ComCtrls, StdCtrls, ExtCtrls, formChangedAddresses;

type

  { TfrmChangedAddressesCommonalityScanner }

  TfrmChangedAddressesCommonalityScanner = class(TForm)
    lvRegisters: TListView;
    procedure FormDestroy(Sender: TObject);
    procedure lvRegistersDblClick(Sender: TObject);
  private
    { private declarations }


    group: array [1..2] of array of TAddressEntry;
  public
    { public declarations }
    procedure setGroup(groupnr: integer; const grouplist: array of TAddressEntry);
    procedure initlist;
  end;


implementation

{$R *.lfm}

uses ProcessHandlerUnit, frmstructurecompareunit;

resourcestring
  rsDblClickLaunchComp = 'Doubleclick to launch structure compare';
  rsShowResults = 'Doubleclick to show scanner/results';

type
  TRegisterInfo=class
  private
    regnr: integer;
  public
    running: boolean;
    done: boolean;
    scanner: TfrmStructureCompare;
    constructor create(r: integer);
  end;

constructor TRegisterInfo.create(r: integer);
begin
  regnr:=r;
end;

procedure TfrmChangedAddressesCommonalityScanner.FormDestroy(Sender: TObject);
var i,j: integer;
  r: TRegisterInfo;
begin
  //tell all the scanners to stop if they where active
  for i:=0 to lvRegisters.items.count-1 do
  begin
    r:=lvRegisters.items[i].data;
    if (r.scanner<>nil) then
    begin
      if (r.scanner.Visible) then  //if visible, make it free itself when it's done
        r.scanner.donotfreeonclose:=false
      else
        freeandnil(r.scanner); //else free it now
    end
  end;

  //free memory
  for i:=1 to 2 do
    for j:=0 to length(group[i])-1 do
      group[i][j].free;
end;

procedure TfrmChangedAddressesCommonalityScanner.lvRegistersDblClick(Sender: TObject);
var
  r: TRegisterInfo;

  i,j: integer;
  addresslist: array [1..2] of array of TAddressWithShadow;
  a: pointer;
  x: ptruint;
begin
  if lvRegisters.Selected<>nil then
  begin
    r:=TRegisterInfo(lvRegisters.Selected.data);

    if r.scanner=nil then
    begin
      //create it
      r.scanner:=TfrmStructureCompare.Create(application);

      for i:=1 to 2 do
      begin
        setlength(addresslist[i], length(group[i]));

        for j:=0 to length(group[i])-1 do
        begin
          addresslist[i][j].shadow:=0;
          addresslist[i][j].shadowsize:=0;

          case r.regnr of
            0: addresslist[i][j].address:=group[i][j].context.Rax;
            1: addresslist[i][j].address:=group[i][j].context.Rbx;
            2: addresslist[i][j].address:=group[i][j].context.Rcx;
            3: addresslist[i][j].address:=group[i][j].context.Rdx;
            4: addresslist[i][j].address:=group[i][j].context.Rsi;
            5: addresslist[i][j].address:=group[i][j].context.Rdi;
            6: addresslist[i][j].address:=group[i][j].context.Rbp;
            7: //stack snapshot
               begin
                 addresslist[i][j].address:=group[i][j].context.rsp;
                 //create a shadow

                 if group[1][j].stack.stack<>nil then
                 begin
                   a:=VirtualAllocEx(processhandle, nil, group[i][j].stack.savedsize, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
                   if a<>nil then
                   begin
                     if writeprocessmemory(processhandle, a, group[i][j].stack.stack, group[i][j].stack.savedsize, x) then
                     begin
                       addresslist[i][j].shadow:=ptruint(a);
                       addresslist[i][j].shadowsize:=group[i][j].stack.savedsize;
                     end;
                   end;
                 end;
               end;
            8: addresslist[i][j].address:=group[i][j].context.R8;
            9: addresslist[i][j].address:=group[i][j].context.R9;
            10: addresslist[i][j].address:=group[i][j].context.R10;
            11: addresslist[i][j].address:=group[i][j].context.R11;
            12: addresslist[i][j].address:=group[i][j].context.R12;
            13: addresslist[i][j].address:=group[i][j].context.R13;
            14: addresslist[i][j].address:=group[i][j].context.R14;
            15: addresslist[i][j].address:=group[i][j].context.R15;
          end;
        end;

        r.scanner.addAddress(addresslist[i][j].address, addresslist[i][j].shadow, addresslist[i][j].shadowsize, i);
      end;

      lvRegisters.Items[i].SubItems[0]:=rsShowResults;
    end;

    r.scanner.show;
  end;
end;


procedure TfrmChangedAddressesCommonalityScanner.setGroup(groupnr: integer; const grouplist: array of TAddressEntry);
var i: integer;
begin
  //copy the data so it won't be freed when the previous window closes
  if (groupnr<1) or (groupnr>2) then raise exception.create('invalid parameter');

  setlength(group[groupnr], length(grouplist));

  for i:=0 to length(grouplist)-1 do
  begin
    group[groupnr][i]:=TAddressEntry.Create;
    group[groupnr][i].address:=grouplist[i].address;
    group[groupnr][i].context:=grouplist[i].context;
    if grouplist[i].stack.stack<>nil then
    begin
      getmem(group[groupnr][i].stack.stack, grouplist[i].stack.savedsize);
      CopyMemory(group[groupnr][i].stack.stack, grouplist[i].stack.stack, grouplist[i].stack.savedsize);
    end;
  end;
end;

procedure TfrmChangedAddressesCommonalityScanner.initlist;
var
  registers: record //list to keep track of which registers are different
    RAX: boolean;
    RBX: boolean;
    RCX: boolean;
    RDX: boolean;
    RSI: boolean;
    RDI: boolean;
    RBP: boolean;
    R8: boolean;
    R9: boolean;
    R10: boolean;
    R11: boolean;
    R12: boolean;
    R13: boolean;
    R14: boolean;
    R15: boolean;
  end;

  li: TListItem;
  ri: TRegisterInfo;
  i,j: integer;
begin
  //todo for next version
  //check the register values in g1 and g2 for commonalities
  ZeroMemory(@registers, sizeof(registers));

  for i:=0 to length(group[1])-1 do
  begin
    for j:=0 to length(group[2])-1 do
    begin
      if (group[1][i].context.{$ifdef cpu64}RAX{$else}EAX{$endif}=group[2][i].context.rax) then registers.rax:=true;
      if (group[1][i].context.{$ifdef cpu64}RBX{$else}EBX{$endif}=group[2][i].context.rbx) then registers.rbx:=true;
      if (group[1][i].context.{$ifdef cpu64}RCX{$else}Ecx{$endif}=group[2][i].context.rcx) then registers.rcx:=true;
      if (group[1][i].context.{$ifdef cpu64}RDX{$else}Edx{$endif}=group[2][i].context.rdx) then registers.rdx:=true;
      if (group[1][i].context.{$ifdef cpu64}RSI{$else}Esi{$endif}=group[2][i].context.rsi) then registers.rsi:=true;
      if (group[1][i].context.{$ifdef cpu64}RDI{$else}Edi{$endif}=group[2][i].context.rdi) then registers.rdi:=true;
      if (group[1][i].context.{$ifdef cpu64}RBP{$else}Ebp{$endif}=group[2][i].context.rbp) then registers.rbp:=true;
      {$ifdef cpu64}
      if (group[1][i].context.R8=group[2][i].context.r8) then registers.r8:=true;
      if (group[1][i].context.R9=group[2][i].context.r9) then registers.r9:=true;
      if (group[1][i].context.R10=group[2][i].context.r10) then registers.r10:=true;
      if (group[1][i].context.R11=group[2][i].context.r11) then registers.r11:=true;
      if (group[1][i].context.R12=group[2][i].context.r12) then registers.r12:=true;
      if (group[1][i].context.R13=group[2][i].context.r13) then registers.r13:=true;
      if (group[1][i].context.R14=group[2][i].context.r14) then registers.r14:=true;
      if (group[1][i].context.R15=group[2][i].context.r15) then registers.r15:=true;
      {$endif}
    end;
  end;

  //do not bother with the registers that are the same in g1 and g2
  //start a compare on the registers
  if registers.rax=false then
  begin
    li:=lvregisters.Items.Add;
    if processhandler.is64Bit then li.caption:='RAX' else li.caption:='EAX';
    li.data:=pointer(tregisterinfo.Create(0));
  end;

  if registers.rbx=false then
  begin
    li:=lvregisters.Items.Add;
    if processhandler.is64Bit then li.caption:='RBX' else li.caption:='EBX';
    li.data:=pointer(tregisterinfo.Create(1));
  end;

  if registers.rcx=false then
  begin
    li:=lvregisters.Items.Add;
    if processhandler.is64Bit then li.caption:='RCX' else li.caption:='ECX';
    li.data:=pointer(tregisterinfo.Create(2));
  end;

  if registers.rdx=false then
  begin
    li:=lvregisters.Items.Add;
    if processhandler.is64Bit then li.caption:='RDX' else li.caption:='EDX';
    li.data:=pointer(tregisterinfo.Create(3));
  end;

  if registers.rsi=false then
  begin
    li:=lvregisters.Items.Add;
    if processhandler.is64Bit then li.caption:='RSI' else li.caption:='ESI';
    li.data:=pointer(tregisterinfo.Create(4));
  end;

  if registers.rdi=false then
  begin
    li:=lvregisters.Items.Add;
    if processhandler.is64Bit then li.caption:='RDI' else li.caption:='EDI';
    li.data:=pointer(tregisterinfo.Create(5));
  end;

  if registers.rbp=false then
  begin
    li:=lvregisters.Items.Add;
    if processhandler.is64Bit then li.caption:='RBP' else li.caption:='EBP';
    li.data:=pointer(tregisterinfo.Create(6));
  end;

  li:=lvregisters.Items.Add;
  if processhandler.is64Bit then li.caption:='RSP (Snapshot)' else li.caption:='RSP (Snapshot)';
  li.data:=pointer(tregisterinfo.Create(7));

  if processhandler.is64bit then
  begin
    if registers.r8=false then
    begin
      li:=lvregisters.Items.Add;
      li.caption:='R8';
      li.data:=pointer(tregisterinfo.Create(8));
    end;

    if registers.r9=false then
    begin
      li:=lvregisters.Items.Add;
      li.caption:='R9';
      li.data:=pointer(tregisterinfo.Create(9));
    end;

    if registers.r10=false then
    begin
      li:=lvregisters.Items.Add;
      li.caption:='R10';
      li.data:=pointer(tregisterinfo.Create(10));
    end;

    if registers.r11=false then
    begin
      li:=lvregisters.Items.Add;
      li.caption:='R11';
      li.data:=pointer(tregisterinfo.Create(11));
    end;

    if registers.r12=false then
    begin
      li:=lvregisters.Items.Add;
      li.caption:='R12';
      li.data:=pointer(tregisterinfo.Create(12));
    end;

    if registers.r13=false then
    begin
      li:=lvregisters.Items.Add;
      li.caption:='R13';
      li.data:=pointer(tregisterinfo.Create(13));
    end;

    if registers.r14=false then
    begin
      li:=lvregisters.Items.Add;
      li.caption:='R14';
      li.data:=pointer(tregisterinfo.Create(14));
    end;

    if registers.r15=false then
    begin
      li:=lvregisters.Items.Add;
      li.caption:='R15';
      li.data:=pointer(tregisterinfo.Create(15));
    end;
  end;

  for i:=0 to lvRegisters.items.count-1 do
    lvRegisters.Items[i].SubItems.add(rsDblClickLaunchComp);

end;

end.

