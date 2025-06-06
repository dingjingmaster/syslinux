; -*- fundamental -*- (asm-mode sucks)
; $Id: mbr.asm,v 1.4 2000/07/06 07:33:29 hpa Exp $
; -----------------------------------------------------------------------
;   
;   NOT Copyright 2000 H. Peter Anvin
;
;   This file is in the public domain.  Enjoy.  However, I would
;   appreciate it if modified versions were marked as such, and
;   please don't bug me about any version not released by me.
;
; -----------------------------------------------------------------------

;
; mbr.asm
;
; Simple Master Boot Record, including support for EBIOS extensions.
; 
; The MBR lives in front of the boot sector, and is responsible for
; loading the boot sector of the active partition.  The EBIOS support
; is needed if the active partition starts beyond cylinder 1024.
; 
; This MBR determines all geometry info at runtime.  It uses only the
; linear block field in the partition table.  It does, however, pass
; the partition table information unchanged to the target OS.
;
; This MBR should be "8086-clean", i.e. not require a 386.
;

;
; Note: The MBR is actually loaded at 0:7C00h, but we quickly move it down to
; 0600h.
;

		org 0600h
_start:		cli
		xor ax,ax
		mov ds,ax
		mov es,ax
		mov ss,ax
		mov sp,7C00h
		sti
		cld
		mov si,sp		; Start address
		mov di,0600h		; Destination address
		mov cx,512/2
		rep movsw

;
; Now, jump to the copy at 0600h so we can load the boot sector at 7C00h.
; Since some BIOSes seem to think 0000:7C00h and 07C0:0000h are the same
; thing, use a far jump to canonicalize the address.
;

		jmp 0:next		; Jump to copy at 0600h
				
next:
		mov [DriveNo], dl		; Drive number stored in DL
;
; Check for CHS parameters.  This doesn't work on floppy disks,
; but for an MBR we don't care.
;
		mov ah,08h			; Get drive parameters
		int 13h
		mov [Heads],dh
		mov dh,cl
		and dh,3Fh			; Max sector number
		dec dh				; Sector count
		mov [Sectors],dh
		mov dx,cx
		xchg dh,dl
		mov cl,6
		shr dh,cl
		mov [Cylinders],dx

;
; Now look for one (and only one) active partition.
;
		mov si,PartitionTable
		xor ax,ax
		mov cx,4
checkpartloop:
		test byte [si],80h
		jz .notactive
		inc ax
		mov di,si
.notactive:	add si,byte 16
		loop checkpartloop

		cmp ax,byte 1			; Better be only one
		jnz not_one_partition

;
; Now we have the active partition partition information in DS:DI.
; Check to see if we support EBIOS.
;
		mov dl,[DriveNo]
		mov ax,4100h
		mov bx,055AAh
		xor cx,cx
		xor dh,dh
		stc
		int 13h
		jc no_ebios
		cmp bx,0AA55h
		jne no_ebios
		test cl,1			; LBA device access
		jz no_ebios
;
; We have EBIOS.  Load the boot sector using LBA.
;
		push di
		mov si,dapa
		mov bx,[di+8]			; Copy the block address
		mov [si+8],bx
		mov bx,[di+10]
		mov [si+10],bx
		mov dl,[DriveNo]
		mov ah,42h			; Extended Read
		jmp short common_tail
;
; No EBIOS.  Load the boot sector using CHS.
;
no_ebios:
		push di
		mov ax,[di+8]
		mov dx,[di+10]
		div word [Sectors]
		inc dx
		mov cx,dx			; Sector #
		xor dx,dx
		div word [Heads]
		; DX = head #, AX = cylinder #
		mov ch,al
		shr ax,1
		shr ax,1
		and al,0C0h
		or cl,al
		mov dh,dl			; Head #
		mov dl,[DriveNo]
		mov bx,7C00h
		mov ah,02h			; Read
common_tail:
		int 13h
		jc disk_error
		pop di
;
; Verify that we have a boot sector, jump
;
		test word [7C00h+510],0AA55h
		jne missing_os
		cli
		jmp 7C00h			; Jump to boot sector

not_one_partition:
		ja too_many_os
missing_os:
		mov si,missing_os_msg
		jmp short die
too_many_os:
disk_error:
		mov si,bad_disk_msg
die:
.msgloop:
		lodsb
		xor al,al
		jz .now
		mov ah,0Eh			; TTY output
		mov bx,0007h
		int 10h
		jmp short .msgloop
.now:
		jmp short .now

		align 4, db 0			; Begin data area

;
; EBIOS disk address packet
;
dapa:
		dw 16				; Packet size
.count:		dw 1				; Block count
.off:		dw 7C00h			; Offset of buffer
.seg:		dw 0				; Segment of buffer
.lba:		dd 0				; LBA (LSW)
		dd 0				; LBA (MSW)

; CHS information
Heads:		dw 0
Sectors:	dw 0
Cylinders:	dw 0

; Error messages
missing_os_msg	db 'Missing operating system', 13, 10, 0
bad_disk_msg	db 'Operating system loading error', 13, 10, 0

;
; Maximum MBR size: 446 bytes; end-of-boot-sector signature also needed.
; Note that some operating systems (NT, DR-DOS) put additional stuff at
; the end of the MBR, so shorter is better.
;

PartitionTable	equ $$+446			; Start of partition table

;
; BSS data; put at 800h
;
DriveNo		equ 0800h
